using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Ledger;
using Banking.Api.Features.Transfers;
using Banking.Api.Observability;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class InternalTransferEndpointTests
{
    [Fact]
    public async Task TransferIsBalancedConservesValueAndReplaysItsPersistedReceipt()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateTwoAccountsAsync(host, fundSource: true);
        using var client = host.CreateClient();
        var key = Guid.NewGuid();

        using var created = await SendAsync(client, setup.SourceToken, key, setup.DestinationId, "125050");
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var receipt = (await created.Content.ReadFromJsonAsync<InternalTransferReceipt>())!;
        Assert.Equal(setup.SourceId, receipt.SourceAccountReference);
        Assert.Equal(setup.DestinationId, receipt.DestinationAccountReference);
        Assert.Equal("125050", receipt.AmountMinor);
        Assert.Equal("4874950", receipt.SourceBalanceAfterMinor);
        Assert.Equal("COMPLETED", receipt.Status);
        Assert.False(receipt.Replayed);
        AssertCorrelation(created, problem: false);

        using var replay = await SendAsync(client, setup.SourceToken, key, setup.DestinationId, "125050");
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var replayReceipt = (await replay.Content.ReadFromJsonAsync<InternalTransferReceipt>())!;
        Assert.Equal(receipt with { Replayed = true }, replayReceipt);

        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var accounts = await db.CustomerAccounts.OrderBy(account => account.Id).ToListAsync();
        Assert.Equal(5_000_000, accounts.Sum(account => account.BalanceMinor));
        Assert.Equal(4_874_950, accounts.Single(account => account.Id == setup.SourceId).BalanceMinor);
        Assert.Equal(125_050, accounts.Single(account => account.Id == setup.DestinationId).BalanceMinor);
        var transfer = await db.LedgerTransactions.Include(item => item.Postings)
            .SingleAsync(item => item.Operation == LedgerTransaction.InternalTransferOperation);
        Assert.Equal([(-125_050L, setup.SourceId), (125_050L, setup.DestinationId)],
            transfer.Postings.OrderBy(item => item.Position)
                .Select(item => (item.AmountMinor, item.CustomerAccountId!.Value)).ToArray());
    }

    [Fact]
    public async Task OwnershipRecipientFundsLimitsAndIdempotencyFailWithoutPartialWrites()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateTwoAccountsAsync(host, fundSource: false);
        using var client = host.CreateClient();

        using var insufficient = await SendAsync(client, setup.SourceToken, Guid.NewGuid(),
            setup.DestinationId, "1");
        await AssertProblemAsync(insufficient, HttpStatusCode.Conflict, "insufficient_funds");
        using var missing = await SendAsync(client, setup.SourceToken, Guid.NewGuid(), Guid.NewGuid(), "1");
        await AssertProblemAsync(missing, HttpStatusCode.NotFound, "recipient_not_found");
        using var self = await SendAsync(client, setup.SourceToken, Guid.NewGuid(), setup.SourceId, "1");
        await AssertProblemAsync(self, HttpStatusCode.Conflict, "self_transfer_not_allowed");
        var accountlessUser = await CustomerSessionTests.SeedAsync(host.Services);
        var accountlessToken = (await CustomerSessionTests.LoginAsync(client, accountlessUser.Email!)).AccessToken;
        using var unopened = await SendAsync(client, accountlessToken, Guid.NewGuid(), setup.DestinationId, "1");
        await AssertProblemAsync(unopened, HttpStatusCode.Conflict, "account_not_opened");

        var fundingKey = Guid.NewGuid();
        await FundAsync(client, setup.SourceToken, fundingKey);
        using var operationConflict = await SendAsync(client, setup.SourceToken, fundingKey,
            setup.DestinationId, "1");
        await AssertProblemAsync(operationConflict, HttpStatusCode.Conflict, "idempotency_conflict");
        await FundAsync(client, setup.SourceToken, Guid.NewGuid());
        var key = Guid.NewGuid();
        using var first = await SendAsync(client, setup.SourceToken, key, setup.DestinationId, "5000000");
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        using var conflict = await SendAsync(client, setup.SourceToken, key, setup.DestinationId, "4999999");
        await AssertProblemAsync(conflict, HttpStatusCode.Conflict, "idempotency_conflict");
        using var second = await SendAsync(client, setup.SourceToken, Guid.NewGuid(), setup.DestinationId, "5000000");
        Assert.Equal(HttpStatusCode.Created, second.StatusCode);
        using var limited = await SendAsync(client, setup.SourceToken, Guid.NewGuid(), setup.DestinationId, "1");
        await AssertProblemAsync(limited, HttpStatusCode.Conflict, "outgoing_daily_limit_reached");

        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(2, await db.LedgerTransactions.CountAsync(item =>
            item.Operation == LedgerTransaction.InternalTransferOperation));
        Assert.Equal(0, (await db.CustomerAccounts.SingleAsync(account => account.Id == setup.SourceId)).BalanceMinor);
        Assert.Equal(10_000_000,
            (await db.CustomerAccounts.SingleAsync(account => account.Id == setup.DestinationId)).BalanceMinor);
    }

    [Theory]
    [InlineData("0")]
    [InlineData("01")]
    [InlineData("-1")]
    [InlineData("+1")]
    [InlineData("1.0")]
    [InlineData("1e2")]
    [InlineData(" 1")]
    [InlineData("5000001")]
    [InlineData("9223372036854775808")]
    public async Task AmountMustBeCanonicalBoundedIntegerString(string amount)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var response = await SendAsync(client, null, Guid.NewGuid(), Guid.NewGuid(), amount);
        await AssertProblemAsync(response, HttpStatusCode.BadRequest);
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("[]")]
    [InlineData("{\"destinationAccountReference\":1,\"amountMinor\":\"1\"}")]
    [InlineData("{\"destinationAccountReference\":\"00000000-0000-0000-0000-000000000000\",\"amountMinor\":\"1\"}")]
    [InlineData("{\"destinationAccountReference\":\"11111111-1111-1111-1111-111111111111\",\"amountMinor\":1}")]
    [InlineData("{\"destinationAccountReference\":\"11111111-1111-1111-1111-111111111111\",\"amountMinor\":\"1\",\"sourceAccountReference\":\"11111111-1111-1111-1111-111111111111\"}")]
    public async Task ExactShapeRejectsMalformedOrClientSelectedSource(string body)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var response = await SendRawAsync(client, null, Guid.NewGuid().ToString("D"),
            InternalTransferEndpoints.Route, body);
        await AssertProblemAsync(response, HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task TransportMediaSizeAuthThrottleAndCorrelationFailClosed()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        var destination = Guid.NewGuid();
        var body = Body(destination, "1");
        using var insecure = await SendRawAsync(client, null, Guid.NewGuid().ToString("D"),
            "http://localhost" + InternalTransferEndpoints.Route, body);
        await AssertProblemAsync(insecure, HttpStatusCode.BadRequest);
        using var query = await SendRawAsync(client, null, Guid.NewGuid().ToString("D"),
            InternalTransferEndpoints.Route + "?source=other", body);
        await AssertProblemAsync(query, HttpStatusCode.BadRequest);
        using var media = await SendRawAsync(client, null, Guid.NewGuid().ToString("D"),
            InternalTransferEndpoints.Route, body, "text/plain");
        await AssertProblemAsync(media, HttpStatusCode.UnsupportedMediaType);
        using var large = await SendRawAsync(client, null, Guid.NewGuid().ToString("D"),
            InternalTransferEndpoints.Route, new string(' ', 16 * 1024 + 1));
        await AssertProblemAsync(large, HttpStatusCode.RequestEntityTooLarge);
        using var missingKey = await SendRawAsync(client, null, null, InternalTransferEndpoints.Route, body);
        await AssertProblemAsync(missingKey, HttpStatusCode.BadRequest);
        using var uppercaseKey = await SendRawAsync(client, null, Guid.NewGuid().ToString("D").ToUpperInvariant(),
            InternalTransferEndpoints.Route, body);
        await AssertProblemAsync(uppercaseKey, HttpStatusCode.BadRequest);
        using var unauthenticated = await SendAsync(client, null, Guid.NewGuid(), destination, "1");
        await AssertProblemAsync(unauthenticated, HttpStatusCode.Unauthorized);
        using var forged = await SendAsync(client, "forged", Guid.NewGuid(), destination, "1");
        await AssertProblemAsync(forged, HttpStatusCode.Unauthorized);

        HttpStatusCode last = 0;
        for (var attempt = 0; attempt < 11; attempt++)
        {
            using var response = await SendAsync(client, null, Guid.NewGuid(), destination, "1");
            last = response.StatusCode;
            if (last == HttpStatusCode.TooManyRequests)
            {
                Assert.NotNull(response.Headers.RetryAfter);
                await AssertProblemAsync(response, HttpStatusCode.TooManyRequests);
            }
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, last);
    }

    [Fact]
    public async Task StreamedBodyIsBoundedAndOperationalLogsExcludeSensitiveRequestValues()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateTwoAccountsAsync(host, fundSource: true);
        using var client = host.CreateClient();
        using (var request = new HttpRequestMessage(HttpMethod.Post, InternalTransferEndpoints.Route))
        {
            request.Headers.Authorization = new("Bearer", setup.SourceToken);
            request.Headers.TryAddWithoutValidation(InternalTransferRequestGuards.IdempotencyHeader,
                Guid.NewGuid().ToString("D"));
            request.Content = new StreamedBody(new string(' ', 16 * 1024 + 1));
            request.Content.Headers.ContentType = new("application/json");
            using var response = await client.SendAsync(request);
            await AssertProblemAsync(response, HttpStatusCode.RequestEntityTooLarge);
        }

        var key = Guid.NewGuid();
        using var transferred = await SendAsync(client, setup.SourceToken, key, setup.DestinationId, "1234567");
        Assert.Equal(HttpStatusCode.Created, transferred.StatusCode);
        Assert.Contains(host.TransferLog.Messages, message => message.Contains("Created", StringComparison.Ordinal));
        var combined = string.Join('\n', host.TransferLog.Messages);
        Assert.DoesNotContain(setup.SourceToken, combined, StringComparison.Ordinal);
        Assert.DoesNotContain(key.ToString("D"), combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(setup.SourceId.ToString("D"), combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(setup.DestinationId.ToString("D"), combined, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("1234567", combined, StringComparison.Ordinal);
    }

    [Fact]
    public async Task RevokedSessionAndStorageFailureNeverMoveMoney()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateTwoAccountsAsync(host, fundSource: true);
        using var client = host.CreateClient();
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions
                .SingleAsync(item => item.UserId == setup.SourceUserId && item.RevokedAtUtc == null);
            session.RevokedAtUtc = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        using var revoked = await SendAsync(client, setup.SourceToken, Guid.NewGuid(), setup.DestinationId, "1");
        await AssertProblemAsync(revoked, HttpStatusCode.Unauthorized);

        var freshLogin = (await CustomerSessionTests.LoginAsync(client, setup.SourceEmail)).AccessToken;
        host.FailDatabaseWrites = true;
        using var unavailable = await SendAsync(client, freshLogin, Guid.NewGuid(), setup.DestinationId, "1");
        await AssertProblemAsync(unavailable, HttpStatusCode.ServiceUnavailable);
        host.FailDatabaseWrites = false;
        using var verification = host.Services.CreateScope();
        var database = verification.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(5_000_000,
            (await database.CustomerAccounts.SingleAsync(item => item.Id == setup.SourceId)).BalanceMinor);
        Assert.Equal(0,
            (await database.CustomerAccounts.SingleAsync(item => item.Id == setup.DestinationId)).BalanceMinor);
        Assert.False(await database.LedgerTransactions.AnyAsync(item =>
            item.Operation == LedgerTransaction.InternalTransferOperation));
    }

    [Fact]
    public void FingerprintAndManilaDayAreCanonicalAndBoundarySafe()
    {
        var source = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var destination = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var first = InternalTransferPolicy.Fingerprint(source, destination, 1);
        Assert.Equal(64, first.Length);
        Assert.Equal(first, InternalTransferPolicy.Fingerprint(source, destination, 1));
        Assert.NotEqual(first, InternalTransferPolicy.Fingerprint(destination, source, 1));
        Assert.NotEqual(first, InternalTransferPolicy.Fingerprint(source, destination, 2));

        var before = PhilippineBusinessDay.For(new DateTimeOffset(2026, 9, 8, 15, 59, 59, TimeSpan.Zero));
        var after = PhilippineBusinessDay.For(new DateTimeOffset(2026, 9, 8, 16, 0, 0, TimeSpan.Zero));
        Assert.Equal(before.EndUtc, after.StartUtc);
    }

    private static async Task<(string SourceUserId, string SourceEmail, string SourceToken,
        Guid SourceId, Guid DestinationId)>
        CreateTwoAccountsAsync(RegistrationTestHost host, bool fundSource)
    {
        var sourceUser = await CustomerSessionTests.SeedAsync(host.Services);
        var destinationUser = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var sourceToken = (await CustomerSessionTests.LoginAsync(client, sourceUser.Email!)).AccessToken;
        var destinationToken = (await CustomerSessionTests.LoginAsync(client, destinationUser.Email!)).AccessToken;
        using var sourceResponse = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, sourceToken);
        using var destinationResponse = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put,
            destinationToken);
        var source = (await sourceResponse.Content.ReadFromJsonAsync<AccountSummary>())!;
        var destination = (await destinationResponse.Content.ReadFromJsonAsync<AccountSummary>())!;
        if (fundSource) await FundAsync(client, sourceToken, Guid.NewGuid());
        return (sourceUser.Id, sourceUser.Email!, sourceToken, source.Id, destination.Id);
    }

    private static async Task FundAsync(HttpClient client, string token, Guid key)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, DevelopmentFundingEndpoints.Route);
        request.Headers.Authorization = new("Bearer", token);
        request.Headers.TryAddWithoutValidation(DevelopmentFundingRequestGuards.IdempotencyHeader, key.ToString("D"));
        request.Content = JsonContent.Create(new { });
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    internal static Task<HttpResponseMessage> SendAsync(HttpClient client, string? token, Guid key,
        Guid destination, string amount) => SendRawAsync(client, token, key.ToString("D"),
        InternalTransferEndpoints.Route, Body(destination, amount));

    private static async Task<HttpResponseMessage> SendRawAsync(HttpClient client, string? token,
        string? key, string route, string body, string media = "application/json")
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, route);
        if (token is not null) request.Headers.Authorization = new("Bearer", token);
        if (key is not null)
            request.Headers.TryAddWithoutValidation(InternalTransferRequestGuards.IdempotencyHeader, key);
        request.Content = new StringContent(body, Encoding.UTF8, media);
        return await client.SendAsync(request);
    }

    private static string Body(Guid destination, string amount) =>
        JsonSerializer.Serialize(new { destinationAccountReference = destination.ToString("D"), amountMinor = amount });

    private static async Task AssertProblemAsync(HttpResponseMessage response, HttpStatusCode expected,
        string? code = null)
    {
        Assert.Equal(expected, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        if (code is not null) Assert.Equal(code, problem.GetProperty("code").GetString());
        AssertCorrelation(response, problem: true, problem);
    }

    private static void AssertCorrelation(HttpResponseMessage response, bool problem,
        JsonElement payload = default)
    {
        Assert.True(response.Headers.TryGetValues(RequestCorrelationMiddleware.HeaderName, out var values));
        var requestId = Assert.Single(values);
        Assert.Equal(32, requestId.Length);
        if (problem) Assert.Equal(requestId, payload.GetProperty("traceId").GetString());
    }

    private sealed class StreamedBody(string body) : HttpContent
    {
        protected override bool TryComputeLength(out long length)
        {
            length = 0;
            return false;
        }

        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context) =>
            stream.WriteAsync(Encoding.UTF8.GetBytes(body)).AsTask();
    }
}

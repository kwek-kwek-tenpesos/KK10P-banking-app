using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Activity;
using Banking.Api.Features.Ledger;
using Banking.Api.Observability;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class ActivityEndpointTests
{
    [Fact]
    public async Task ListAndDetailAreDerivedFromTheAuthenticatedAccountPosting()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateThreeAccountsAsync(host);
        var fundingId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        var abId = Guid.Parse("20000000-0000-0000-0000-000000000002");
        var bcId = Guid.Parse("30000000-0000-0000-0000-000000000003");
        await SeedFundingAsync(host, setup.AUserId, setup.AAccountId, fundingId,
            new DateTime(2026, 9, 9, 1, 0, 0, DateTimeKind.Utc), 5_000_000);
        await SeedTransferAsync(host, setup.AUserId, setup.AAccountId, setup.BAccountId, abId,
            new DateTime(2026, 9, 9, 2, 0, 0, DateTimeKind.Utc), 1_200_000);
        await SeedTransferAsync(host, setup.BUserId, setup.BAccountId, setup.CAccountId, bcId,
            new DateTime(2026, 9, 9, 3, 0, 0, DateTimeKind.Utc), 100);

        using var client = host.CreateClient();
        using var list = await SendAsync(client, setup.AToken, ActivityEndpoints.RoutePrefix);
        Assert.True(list.StatusCode == HttpStatusCode.OK,
            await list.Content.ReadAsStringAsync() + string.Join(";", host.ActivityLog.Messages));
        var listJson = await list.Content.ReadFromJsonAsync<JsonElement>();
        var items = listJson.GetProperty("items").EnumerateArray().ToArray();
        Assert.Equal(2, items.Length);
        Assert.Equal(abId, items[0].GetProperty("transactionId").GetGuid());
        Assert.Equal("INTERNAL_TRANSFER", items[0].GetProperty("type").GetString());
        Assert.Equal("OUTGOING", items[0].GetProperty("direction").GetString());
        Assert.Equal("1200000", items[0].GetProperty("amountMinor").GetString());
        Assert.Equal("KK10P_ACCOUNT", items[0].GetProperty("counterpartyType").GetString());
        Assert.Equal(setup.BAccountId.ToString("N")[^8..],
            items[0].GetProperty("counterpartyReferenceSuffix").GetString());
        Assert.Equal(fundingId, items[1].GetProperty("transactionId").GetGuid());
        Assert.Equal("INCOMING", items[1].GetProperty("direction").GetString());
        Assert.Equal("SIMULATOR_ISSUER", items[1].GetProperty("counterpartyType").GetString());
        Assert.Equal(JsonValueKind.Null, items[1].GetProperty("counterpartyReferenceSuffix").ValueKind);
        Assert.Equal(JsonValueKind.Null, listJson.GetProperty("nextCursor").ValueKind);

        using var detail = await SendAsync(client, setup.AToken, $"{ActivityEndpoints.RoutePrefix}/{abId:D}");
        Assert.Equal(HttpStatusCode.OK, detail.StatusCode);
        var detailJson = await detail.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(setup.AAccountId, detailJson.GetProperty("accountReference").GetGuid());
        Assert.Equal(setup.BAccountId, detailJson.GetProperty("counterpartyAccountReference").GetGuid());
        Assert.False(detailJson.TryGetProperty("balanceAfterMinor", out _));
        Assert.False(detailJson.TryGetProperty("initiatedByUserId", out _));
        Assert.False(detailJson.TryGetProperty("idempotencyKey", out _));

        using var forbidden = await SendAsync(client, setup.CToken, $"{ActivityEndpoints.RoutePrefix}/{abId:D}");
        using var missing = await SendAsync(client, setup.CToken,
            $"{ActivityEndpoints.RoutePrefix}/{Guid.Parse("40000000-0000-0000-0000-000000000004"):D}");
        Assert.Equal(HttpStatusCode.NotFound, forbidden.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal("transaction_not_found",
            (await forbidden.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        Assert.Equal("transaction_not_found",
            (await missing.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }

    [Fact]
    public async Task CursorPaginationAndFiltersAreStableForSameTimestampRows()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateThreeAccountsAsync(host);
        var occurred = new DateTime(2026, 9, 9, 4, 0, 0, DateTimeKind.Utc);
        var ids = new[]
        {
            Guid.Parse("50000000-0000-0000-0000-000000000001"),
            Guid.Parse("50000000-0000-0000-0000-000000000002"),
            Guid.Parse("50000000-0000-0000-0000-000000000003")
        };
        foreach (var id in ids)
            await SeedFundingAsync(host, setup.AUserId, setup.AAccountId, id, occurred, 100);
        var outgoing = Guid.Parse("60000000-0000-0000-0000-000000000004");
        await SeedTransferAsync(host, setup.AUserId, setup.AAccountId, setup.BAccountId,
            outgoing, occurred.AddMinutes(1), 50);

        using var client = host.CreateClient();
        using var first = await SendAsync(client, setup.AToken,
            ActivityEndpoints.RoutePrefix + "?limit=2&type=DEVELOPMENT_FUNDING");
        Assert.True(first.StatusCode == HttpStatusCode.OK,
            await first.Content.ReadAsStringAsync() + string.Join(";", host.ActivityLog.Messages));
        var firstJson = await first.Content.ReadFromJsonAsync<JsonElement>();
        var firstIds = firstJson.GetProperty("items").EnumerateArray()
            .Select(item => item.GetProperty("transactionId").GetGuid()).ToArray();
        var cursor = firstJson.GetProperty("nextCursor").GetString();
        Assert.Equal([ids[2], ids[1]], firstIds);
        Assert.False(string.IsNullOrWhiteSpace(cursor));

        var inserted = Guid.Parse("70000000-0000-0000-0000-000000000005");
        await SeedFundingAsync(host, setup.AUserId, setup.AAccountId, inserted,
            occurred.AddMinutes(2), 100);

        using var second = await SendAsync(client, setup.AToken,
            ActivityEndpoints.RoutePrefix + $"?limit=2&type=DEVELOPMENT_FUNDING&cursor={cursor}");
        var secondJson = await second.Content.ReadFromJsonAsync<JsonElement>();
        var secondIds = secondJson.GetProperty("items").EnumerateArray()
            .Select(item => item.GetProperty("transactionId").GetGuid()).ToArray();
        Assert.Equal([ids[0]], secondIds);
        Assert.Equal(JsonValueKind.Null, secondJson.GetProperty("nextCursor").ValueKind);
        Assert.Empty(firstIds.Intersect(secondIds));

        using var refreshed = await SendAsync(client, setup.AToken,
            ActivityEndpoints.RoutePrefix + "?limit=1&type=DEVELOPMENT_FUNDING");
        var refreshedItem = (await refreshed.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("items")[0];
        Assert.Equal(inserted, refreshedItem.GetProperty("transactionId").GetGuid());

        using var outgoingOnly = await SendAsync(client, setup.AToken,
            ActivityEndpoints.RoutePrefix + "?direction=OUTGOING");
        var outgoingItems = (await outgoingOnly.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("items").EnumerateArray().ToArray();
        var only = Assert.Single(outgoingItems);
        Assert.Equal(outgoing, only.GetProperty("transactionId").GetGuid());
        Assert.Equal("OUTGOING", only.GetProperty("direction").GetString());
    }

    [Theory]
    [InlineData("?limit=0")]
    [InlineData("?limit=01")]
    [InlineData("?limit=51")]
    [InlineData("?direction=incoming")]
    [InlineData("?direction=")]
    [InlineData("?type=PAYMENT")]
    [InlineData("?unknown=value")]
    [InlineData("?limit=1&limit=2")]
    [InlineData("?cursor=not-a-cursor")]
    public async Task InvalidListQueriesFailBeforeReadingData(string query)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var response = await SendAsync(client, null, ActivityEndpoints.RoutePrefix + query);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("invalid_activity_query",
            (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }

    [Fact]
    public async Task TransportBodyAuthenticationAccountAndDetailInputsFailClosed()
    {
        using var host = new RegistrationTestHost();
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;

        using var insecure = await SendAsync(client, null,
            "http://localhost" + ActivityEndpoints.RoutePrefix);
        Assert.Equal(HttpStatusCode.BadRequest, insecure.StatusCode);
        using var body = await SendAsync(client, null, ActivityEndpoints.RoutePrefix, "{}");
        Assert.Equal(HttpStatusCode.BadRequest, body.StatusCode);
        using var unauthenticated = await SendAsync(client, null, ActivityEndpoints.RoutePrefix);
        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        using var unopened = await SendAsync(client, token, ActivityEndpoints.RoutePrefix);
        Assert.Equal(HttpStatusCode.NotFound, unopened.StatusCode);
        Assert.Equal("account_not_opened",
            (await unopened.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        using var uppercase = await SendAsync(client, token,
            $"{ActivityEndpoints.RoutePrefix}/{Guid.NewGuid():D}".ToUpperInvariant());
        Assert.Equal(HttpStatusCode.BadRequest, uppercase.StatusCode);
    }

    [Fact]
    public async Task DedicatedReadBudgetRejectsExcessRequestsWithoutQueuing()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        HttpStatusCode last = 0;
        for (var attempt = 0; attempt < 61; attempt++)
        {
            using var response = await SendAsync(client, null, ActivityEndpoints.RoutePrefix);
            last = response.StatusCode;
            if (last == HttpStatusCode.TooManyRequests)
                Assert.NotNull(response.Headers.RetryAfter);
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, last);
    }

    [Fact]
    public async Task MalformedCommittedShapeFailsClosedAndOperationalLogsStayPrivate()
    {
        using var host = new RegistrationTestHost();
        var setup = await CreateThreeAccountsAsync(host);
        var malformedId = Guid.Parse("80000000-0000-0000-0000-000000000008");
        await SeedMalformedFundingAsync(host, setup.AUserId, setup.AAccountId,
            setup.BAccountId, malformedId, 987654);

        using var client = host.CreateClient();
        using var response = await SendAsync(client, setup.AToken, ActivityEndpoints.RoutePrefix);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("activity_unavailable", problem.GetProperty("code").GetString());
        Assert.False(problem.TryGetProperty("transactionId", out _));

        var logs = string.Join('\n', host.ActivityLog.Messages);
        Assert.DoesNotContain(setup.AToken, logs, StringComparison.Ordinal);
        Assert.DoesNotContain(malformedId.ToString("D"), logs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(setup.AAccountId.ToString("D"), logs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(setup.BAccountId.ToString("D"), logs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("987654", logs, StringComparison.Ordinal);
    }

    [Fact]
    public void CursorCodecRejectsTamperingAndRoundTripsTheStableKey()
    {
        var expected = new ActivityCursor(
            new DateTime(2026, 9, 9, 5, 0, 0, DateTimeKind.Utc),
            Guid.Parse("70000000-0000-0000-0000-000000000007"));
        var encoded = ActivityCursorCodec.Encode(expected);
        Assert.True(ActivityCursorCodec.TryDecode(encoded, out var decoded));
        Assert.Equal(expected, decoded);
        Assert.False(ActivityCursorCodec.TryDecode(encoded + "x", out _));
        Assert.False(ActivityCursorCodec.TryDecode(string.Empty, out _));
        Assert.False(ActivityCursorCodec.TryDecode(new string('a', 65), out _));
    }

    private static async Task<AccountSetup> CreateThreeAccountsAsync(RegistrationTestHost host)
    {
        var a = await CustomerSessionTests.SeedAsync(host.Services);
        var b = await CustomerSessionTests.SeedAsync(host.Services);
        var c = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var aToken = (await CustomerSessionTests.LoginAsync(client, a.Email!)).AccessToken;
        var bToken = (await CustomerSessionTests.LoginAsync(client, b.Email!)).AccessToken;
        var cToken = (await CustomerSessionTests.LoginAsync(client, c.Email!)).AccessToken;
        var aAccount = await OpenAsync(client, aToken);
        var bAccount = await OpenAsync(client, bToken);
        var cAccount = await OpenAsync(client, cToken);
        return new(a.Id, b.Id, aToken, bToken, cToken, aAccount.Id, bAccount.Id, cAccount.Id);
    }

    private static async Task<AccountSummary> OpenAsync(HttpClient client, string token)
    {
        using var response = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);
        return (await response.Content.ReadFromJsonAsync<AccountSummary>())!;
    }

    private static async Task SeedFundingAsync(RegistrationTestHost host, string userId, Guid accountId,
        Guid transactionId, DateTime occurredAtUtc, long amount)
    {
        await using var scope = host.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.LedgerTransactions.Add(new LedgerTransaction
        {
            Id = transactionId,
            Operation = LedgerTransaction.DevelopmentFundingOperation,
            InitiatedByUserId = userId,
            IdempotencyKey = Guid.NewGuid(),
            RequestFingerprint = new string('a', 64),
            Currency = "PHP",
            BalanceAfterMinor = amount,
            CreatedAtUtc = occurredAtUtc,
            Postings =
            [
                new LedgerPosting
                {
                    Position = 1, BookAccount = LedgerPosting.SimulatorIssuer,
                    AmountMinor = -amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                },
                new LedgerPosting
                {
                    Position = 2, CustomerAccountId = accountId,
                    AmountMinor = amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                }
            ]
        });
        await db.SaveChangesAsync();
    }

    private static async Task SeedTransferAsync(RegistrationTestHost host, string userId,
        Guid sourceId, Guid destinationId, Guid transactionId, DateTime occurredAtUtc, long amount)
    {
        await using var scope = host.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.LedgerTransactions.Add(new LedgerTransaction
        {
            Id = transactionId,
            Operation = LedgerTransaction.InternalTransferOperation,
            InitiatedByUserId = userId,
            IdempotencyKey = Guid.NewGuid(),
            RequestFingerprint = new string('b', 64),
            Currency = "PHP",
            BalanceAfterMinor = 0,
            CreatedAtUtc = occurredAtUtc,
            Postings =
            [
                new LedgerPosting
                {
                    Position = 1, CustomerAccountId = sourceId,
                    AmountMinor = -amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                },
                new LedgerPosting
                {
                    Position = 2, CustomerAccountId = destinationId,
                    AmountMinor = amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                }
            ]
        });
        await db.SaveChangesAsync();
    }

    private static async Task SeedMalformedFundingAsync(RegistrationTestHost host, string userId,
        Guid sourceId, Guid destinationId, Guid transactionId, long amount)
    {
        await using var scope = host.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var occurredAtUtc = new DateTime(2026, 9, 9, 6, 0, 0, DateTimeKind.Utc);
        db.LedgerTransactions.Add(new LedgerTransaction
        {
            Id = transactionId,
            Operation = LedgerTransaction.DevelopmentFundingOperation,
            InitiatedByUserId = userId,
            IdempotencyKey = Guid.NewGuid(),
            RequestFingerprint = new string('c', 64),
            Currency = "PHP",
            BalanceAfterMinor = 0,
            CreatedAtUtc = occurredAtUtc,
            Postings =
            [
                new LedgerPosting
                {
                    Position = 1, CustomerAccountId = sourceId,
                    AmountMinor = -amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                },
                new LedgerPosting
                {
                    Position = 2, CustomerAccountId = destinationId,
                    AmountMinor = amount, Currency = "PHP", CreatedAtUtc = occurredAtUtc
                }
            ]
        });
        await db.SaveChangesAsync();
    }

    private static async Task<HttpResponseMessage> SendAsync(
        HttpClient client,
        string? token,
        string route,
        string? body = null)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, route);
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body is not null) request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        var response = await client.SendAsync(request);
        Assert.True(response.Headers.CacheControl?.NoStore);
        Assert.True(response.Headers.Contains(RequestCorrelationMiddleware.HeaderName));
        return response;
    }

    private sealed record AccountSetup(
        string AUserId,
        string BUserId,
        string AToken,
        string BToken,
        string CToken,
        Guid AAccountId,
        Guid BAccountId,
        Guid CAccountId);
}

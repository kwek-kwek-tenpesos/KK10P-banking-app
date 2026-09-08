using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Ledger;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class DevelopmentFundingEndpointTests
{
    [Fact]
    public async Task FundingIsBalancedIdempotentAndCappedPerOwner()
    {
        using var host = new RegistrationTestHost();
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        using var opened = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);

        var firstKey = Guid.NewGuid();
        using var first = await SendAsync(client, token, firstKey);
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var receipt = (await first.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>())!;
        Assert.Equal("5000000", receipt.CreditedAmountMinor);
        Assert.Equal("5000000", receipt.BalanceAfterMinor);
        Assert.False(receipt.Replayed);

        using var replay = await SendAsync(client, token, firstKey);
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var replayed = (await replay.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>())!;
        Assert.Equal(receipt.TransactionId, replayed.TransactionId);
        Assert.Equal("5000000", replayed.BalanceAfterMinor);
        Assert.True(replayed.Replayed);

        using var second = await SendAsync(client, token, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Created, second.StatusCode);
        Assert.Equal("10000000", (await second.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>())!.BalanceAfterMinor);
        using var limited = await SendAsync(client, token, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Conflict, limited.StatusCode);
        Assert.Equal("development_funding_daily_limit_reached", await ErrorCodeAsync(limited));

        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(10_000_000, (await db.CustomerAccounts.SingleAsync()).BalanceMinor);
        Assert.Equal(2, await db.LedgerTransactions.CountAsync());
        Assert.Equal(4, await db.LedgerPostings.CountAsync());
        foreach (var transactionId in await db.LedgerTransactions.Select(item => item.Id).ToListAsync())
            Assert.Equal(0, await db.LedgerPostings.Where(item => item.LedgerTransactionId == transactionId)
                .SumAsync(item => item.AmountMinor));
    }

    [Fact]
    public async Task FundingRequiresAnOpenedAccountAndNeverAcceptsAnotherOwner()
    {
        using var host = new RegistrationTestHost();
        var firstUser = await CustomerSessionTests.SeedAsync(host.Services);
        var secondUser = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var firstToken = (await CustomerSessionTests.LoginAsync(client, firstUser.Email!)).AccessToken;
        var secondToken = (await CustomerSessionTests.LoginAsync(client, secondUser.Email!)).AccessToken;
        using var opened = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, firstToken);

        using var absent = await SendAsync(client, secondToken, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Conflict, absent.StatusCode);
        Assert.Equal("account_not_opened", await ErrorCodeAsync(absent));
        using var credited = await SendAsync(client, firstToken, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Created, credited.StatusCode);
        using var scope = host.Services.CreateScope();
        var account = await scope.ServiceProvider.GetRequiredService<AppDbContext>().CustomerAccounts.SingleAsync();
        Assert.Equal(firstUser.Id, account.UserId);
    }

    [Theory]
    [InlineData(null, "{}")]
    [InlineData("not-a-uuid", "{}")]
    [InlineData("00000000-0000-0000-0000-000000000000", "{\"amount\":1}")]
    [InlineData("00000000-0000-0000-0000-000000000000", "[]")]
    [InlineData("00000000-0000-0000-0000-000000000000", "")]
    public async Task FundingRejectsMissingKeysAndNonemptyBodies(string? key, string body)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var response = await SendRawAsync(client, null, key,
            DevelopmentFundingEndpoints.Route, body);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    [Fact]
    public async Task TransportMediaQuerySizeAndAuthenticationGuardsFailClosed()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var insecure = await SendRawAsync(client, null, Guid.NewGuid().ToString(),
            "http://localhost" + DevelopmentFundingEndpoints.Route, "{}");
        Assert.Equal(HttpStatusCode.BadRequest, insecure.StatusCode);
        using var query = await SendRawAsync(client, null, Guid.NewGuid().ToString(),
            DevelopmentFundingEndpoints.Route + "?accountId=other", "{}");
        Assert.Equal(HttpStatusCode.BadRequest, query.StatusCode);
        using var media = await SendRawAsync(client, null, Guid.NewGuid().ToString(),
            DevelopmentFundingEndpoints.Route, "{}", "text/plain");
        Assert.Equal(HttpStatusCode.UnsupportedMediaType, media.StatusCode);
        using var large = await SendRawAsync(client, null, Guid.NewGuid().ToString(),
            DevelopmentFundingEndpoints.Route, new string(' ', 16385));
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, large.StatusCode);
        using var unauthenticated = await SendAsync(client, null, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticated.StatusCode);
        using var forged = await SendAsync(client, "forged", Guid.NewGuid());
        Assert.Equal(HttpStatusCode.Unauthorized, forged.StatusCode);
    }

    [Fact]
    public async Task StreamedBodiesAndRateLimitCannotBypassTheGuards()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using (var request = new HttpRequestMessage(HttpMethod.Post, DevelopmentFundingEndpoints.Route))
        {
            request.Headers.TryAddWithoutValidation(
                DevelopmentFundingRequestGuards.IdempotencyHeader,
                Guid.NewGuid().ToString());
            request.Content = new StreamedBody(new string(' ', 16385));
            request.Content.Headers.ContentType = new("application/json");
            using var oversized = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.RequestEntityTooLarge, oversized.StatusCode);
            Assert.True(oversized.Headers.CacheControl?.NoStore);
        }

        HttpStatusCode last = 0;
        for (var attempt = 0; attempt < 11; attempt++)
        {
            using var response = await SendAsync(client, null, Guid.NewGuid());
            last = response.StatusCode;
            if (last == HttpStatusCode.TooManyRequests)
                Assert.NotNull(response.Headers.RetryAfter);
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, last);
    }

    [Fact]
    public async Task ProductionDoesNotExposeDevelopmentFunding()
    {
        using var host = new RegistrationTestHost("Production");
        using var client = host.CreateClient();
        using var response = await SendAsync(client, null, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public void PhilippineCalendarDayUsesManilaMidnight()
    {
        var beforeMidnight = PhilippineBusinessDay.For(new DateTimeOffset(2026, 9, 8, 15, 59, 59, TimeSpan.Zero));
        var afterMidnight = PhilippineBusinessDay.For(new DateTimeOffset(2026, 9, 8, 16, 0, 0, TimeSpan.Zero));
        Assert.Equal(new DateTime(2026, 9, 7, 16, 0, 0, DateTimeKind.Utc), beforeMidnight.StartUtc);
        Assert.Equal(new DateTime(2026, 9, 8, 16, 0, 0, DateTimeKind.Utc), beforeMidnight.EndUtc);
        Assert.Equal(beforeMidnight.EndUtc, afterMidnight.StartUtc);
    }

    private static Task<HttpResponseMessage> SendAsync(HttpClient client, string? token, Guid key) =>
        SendRawAsync(client, token, key.ToString(), DevelopmentFundingEndpoints.Route, "{}");

    private static async Task<HttpResponseMessage> SendRawAsync(HttpClient client, string? token,
        string? key, string route, string body, string media = "application/json")
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, route);
        if (token is not null) request.Headers.Authorization = new("Bearer", token);
        if (key is not null) request.Headers.TryAddWithoutValidation(DevelopmentFundingRequestGuards.IdempotencyHeader, key);
        request.Content = new StringContent(body, Encoding.UTF8, media);
        return await client.SendAsync(request);
    }

    private static async Task<string?> ErrorCodeAsync(HttpResponseMessage response) =>
        (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString();

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

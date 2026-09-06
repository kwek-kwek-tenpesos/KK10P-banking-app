using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class CustomerAccountEndpointTests
{
    [Fact]
    public async Task OpeningIsExplicitIdempotentAndOwnerScoped()
    {
        using var host = new RegistrationTestHost();
        var a = await CustomerSessionTests.SeedAsync(host.Services);
        var b = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var tokenA = (await CustomerSessionTests.LoginAsync(client, a.Email!)).AccessToken;
        var tokenB = (await CustomerSessionTests.LoginAsync(client, b.Email!)).AccessToken;
        using var absent = await SendAsync(client, HttpMethod.Get, tokenA);
        Assert.Equal(HttpStatusCode.NotFound, absent.StatusCode);
        Assert.Equal("account_not_opened", (await absent.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Empty(await db.CustomerAccounts.ToListAsync());
        using var created = await SendAsync(client, HttpMethod.Put, tokenA);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        Assert.Equal(CustomerAccountEndpoints.Route, created.Headers.Location?.OriginalString);
        var summary = (await created.Content.ReadFromJsonAsync<AccountSummary>())!;
        Assert.Equal("PHP", summary.Currency);
        Assert.Equal("0", summary.BalanceMinor);
        using var repeated = await SendAsync(client, HttpMethod.Put, tokenA);
        Assert.Equal(HttpStatusCode.OK, repeated.StatusCode);
        Assert.Equal(summary, await repeated.Content.ReadFromJsonAsync<AccountSummary>());
        using var read = await SendAsync(client, HttpMethod.Get, tokenA);
        var json = await read.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(["balanceMinor", "currency", "id", "openedAtUtc"], json.EnumerateObject().Select(p => p.Name).Order().ToArray());
        using var other = await SendAsync(client, HttpMethod.Get, tokenB);
        Assert.Equal(HttpStatusCode.NotFound, other.StatusCode);
        using var createdB = await SendAsync(client, HttpMethod.Put, tokenB);
        Assert.NotEqual(summary.Id, (await createdB.Content.ReadFromJsonAsync<AccountSummary>())!.Id);
        Assert.Equal(2, await db.CustomerAccounts.CountAsync());
        Assert.Equal(a.Id, (await db.CustomerAccounts.SingleAsync(c => c.Id == summary.Id)).UserId);
    }

    [Theory]
    [InlineData("{\"userId\":\"other\"}")]
    [InlineData("{\"balanceMinor\":100}")]
    [InlineData("{\"currency\":\"USD\"}")]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("{")]
    [InlineData("")]
    public async Task OpeningRejectsAnythingExceptAnEmptyObject(string body)
    {
        using var host = new RegistrationTestHost();
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        using var response = await SendAsync(client, HttpMethod.Put, token, body: body);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        using var scope = host.Services.CreateScope();
        Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().CustomerAccounts.ToListAsync());
    }

    [Theory]
    [InlineData(null)]
    [InlineData("invalid-jwt")]
    public async Task MissingOrForgedCredentialsCannotReadOrOpen(string? token)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        foreach (var method in new[] { HttpMethod.Get, HttpMethod.Put })
        {
            using var response = await SendAsync(client, method, token);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
    }

    [Theory]
    [InlineData("disabled")]
    [InlineData("unconfirmed")]
    [InlineData("locked")]
    [InlineData("revoked")]
    [InlineData("expired")]
    public async Task ExistingBearerMustStillHaveAnEligibleUserAndSession(string condition)
    {
        using var host = new RegistrationTestHost();
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        user.IsEnabled = condition != "disabled";
        user.EmailConfirmed = condition != "unconfirmed";
        if (condition == "locked") user.LockoutEnd = DateTimeOffset.UtcNow.AddHours(1);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var session = await db.CustomerSessions.SingleAsync();
        if (condition == "revoked") session.RevokedAtUtc = DateTime.UtcNow;
        if (condition == "expired") session.IdleExpiresAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await db.SaveChangesAsync();
        foreach (var method in new[] { HttpMethod.Get, HttpMethod.Put })
        {
            using var response = await SendAsync(client, method, token);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
        Assert.Empty(await db.CustomerAccounts.ToListAsync());
    }

    [Fact]
    public async Task TransportInputAndRateGuardsCoverFailuresAndTrailingSlash()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var http = await SendAsync(client, HttpMethod.Put, null, "http://localhost/api/v1/accounts/me");
        Assert.Equal(HttpStatusCode.BadRequest, http.StatusCode);
        Assert.Null(http.Headers.Location);
        using var query = await SendAsync(client, HttpMethod.Get, null, CustomerAccountEndpoints.Route + "?userId=other");
        Assert.Equal(HttpStatusCode.BadRequest, query.StatusCode);
        using var getBody = await SendAsync(client, HttpMethod.Get, null, body: "{}");
        Assert.Equal(HttpStatusCode.BadRequest, getBody.StatusCode);
        using var slash = await SendAsync(client, HttpMethod.Put, null, CustomerAccountEndpoints.Route + "/", "{\"userId\":\"other\"}");
        Assert.Equal(HttpStatusCode.BadRequest, slash.StatusCode);
        using var large = await SendAsync(client, HttpMethod.Put, null, body: new string(' ', 16385));
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, large.StatusCode);
        using var media = await SendAsync(client, HttpMethod.Put, null, media: "text/plain");
        Assert.Equal(HttpStatusCode.UnsupportedMediaType, media.StatusCode);
        HttpStatusCode status = 0;
        for (var i = 0; i < 31; i++)
        {
            using var response = await SendAsync(client, HttpMethod.Get, null);
            status = response.StatusCode;
            if (status == HttpStatusCode.TooManyRequests) Assert.NotNull(response.Headers.RetryAfter);
        }
        Assert.Equal(HttpStatusCode.TooManyRequests, status);
    }

    [Fact]
    public async Task StreamedOversizeBodiesCannotBypassTheLimit()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Put, CustomerAccountEndpoints.Route);
        request.Content = new StreamedBody(new string(' ', 16385));
        request.Content.Headers.ContentType = new("application/json");
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    private sealed class StreamedBody(string body) : HttpContent
    {
        protected override bool TryComputeLength(out long length) { length = 0; return false; }
        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context) =>
            stream.WriteAsync(Encoding.UTF8.GetBytes(body)).AsTask();
    }

    [Fact]
    public async Task FailedWriteIsUnavailableAndRetryCanCreateOnlyOneAccount()
    {
        using var host = new RegistrationTestHost();
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        host.FailDatabaseWrites = true;
        using var failed = await SendAsync(client, HttpMethod.Put, token);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, failed.StatusCode);
        host.FailDatabaseWrites = false;
        using var retry = await SendAsync(client, HttpMethod.Put, token);
        Assert.Equal(HttpStatusCode.Created, retry.StatusCode);
    }

    internal static async Task<HttpResponseMessage> SendAsync(HttpClient client, HttpMethod method, string? token,
        string route = CustomerAccountEndpoints.Route, string? body = null, string media = "application/json")
    {
        using var request = new HttpRequestMessage(method, route);
        if (token is not null) request.Headers.Authorization = new("Bearer", token);
        if (method == HttpMethod.Put || body is not null) request.Content = new StringContent(body ?? "{}", Encoding.UTF8, media);
        var response = await client.SendAsync(request);
        Assert.True(response.Headers.CacheControl?.NoStore);
        return response;
    }
}

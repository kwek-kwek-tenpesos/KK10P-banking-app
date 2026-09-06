using System.Net;
using System.Net.Http.Json;
using System.Text;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Identity;

namespace Banking.IntegrationTests;

public sealed class AuthenticationRepairTests
{
    private const string Email = "repair@example.test";
    private const string Password = "Correct Horse Battery Staple!";

    [Theory]
    [InlineData("Testing")]
    [InlineData("Development")]
    [InlineData("Production")]
    public void MissingSigningKey_PreventsStartup_InEveryEnvironment(string environment)
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment(environment);
            builder.UseTestAuthentication();
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(
                new Dictionary<string, string?> { ["Jwt:SigningKey"] = string.Empty }));
        });
        Assert.Throws<OptionsValidationException>(() => factory.CreateClient());
    }

    [Theory]
    [InlineData("")]
    [InlineData("short")]
    [InlineData("development-fallback-signing-key-banking-lab-min-32-chars!")]
    [InlineData("your-at-least-32-character-secret-key")]
    [InlineData("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")]
    public void InvalidSigningKey_IsRejectedWithoutEchoingIt(string key)
    {
        var result = new JwtOptionsValidator().Validate(null, new JwtOptions { SigningKey = key });
        Assert.True(result.Failed);
        if (key.Length > 0) Assert.DoesNotContain(key, result.FailureMessage);
    }

    [Theory]
    [InlineData(0, 15, 90)]
    [InlineData(11, 15, 90)]
    [InlineData(10, 16, 90)]
    [InlineData(10, 15, 91)]
    [InlineData(10, 15, 10)]
    public void OutOfPolicyLifetimes_AreRejected(int access, int inactivity, int absolute)
    {
        Assert.True(new JwtOptionsValidator().Validate(null, new JwtOptions
        {
            SigningKey = "test-only-random-looking-secret-config-for-validator-1234567890",
            AccessTokenLifetimeMinutes = access,
            SessionInactivityDays = inactivity,
            SessionAbsoluteLifetimeDays = absolute
        }).Failed);
    }

    [Theory]
    [InlineData("unconfirmed")]
    [InlineData("disabled")]
    [InlineData("locked")]
    public async Task IneligibleUsers_CannotLoginOrRefresh(string reason)
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host);
        using var client = host.CreateClient();
        var credentials = await LoginAsync(client);
        if (reason == "unconfirmed") user.EmailConfirmed = false;
        if (reason == "disabled") user.IsEnabled = false;
        if (reason == "locked") user.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(5);

        using var login = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = Email, password = Password });
        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
        var failure = await login.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Equal("Invalid email or password.", failure.GetProperty("detail").GetString());
        using var refresh = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = credentials.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
        Assert.Equal(0, user.AccessFailedCount);
        using var scope = host.Services.CreateScope();
        Assert.Equal(1, await scope.ServiceProvider.GetRequiredService<AppDbContext>().RefreshTokens.CountAsync());
    }

    [Fact]
    public async Task Login_UsesTenMinuteTokenAndFifteenDayRefreshDeadline()
    {
        using var host = new RegistrationTestHost();
        await SeedAsync(host);
        using var client = host.CreateClient();
        var before = DateTime.UtcNow;
        var credentials = await LoginAsync(client);
        Assert.InRange(credentials.ExpiresInSeconds, 598, 600);
        using var scope = host.Services.CreateScope();
        var token = await scope.ServiceProvider.GetRequiredService<AppDbContext>().RefreshTokens.SingleAsync();
        Assert.InRange(token.ExpiresAtUtc, before.AddDays(15), DateTime.UtcNow.AddDays(15));
    }

    [Fact]
    public async Task Login_IdentityWriteFailure_DoesNotIssueTokens()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host);
        user.AccessFailedCount = 1;
        host.Store.UpdateResult = IdentityResult.Failed(new IdentityError { Code = "ConcurrencyFailure" });
        using var client = host.CreateClient();
        using var result = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = Email, password = Password });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, result.StatusCode);
        using var scope = host.Services.CreateScope();
        Assert.Empty(await scope.ServiceProvider.GetRequiredService<AppDbContext>().RefreshTokens.ToListAsync());
    }

    [Fact]
    public async Task Logout_PersistenceFailure_Returns503_AndTokenRemainsActive()
    {
        using var host = new RegistrationTestHost();
        await SeedAsync(host);
        using var client = host.CreateClient();
        var credentials = await LoginAsync(client);
        host.FailDatabaseWrites = true;
        using var response = await client.PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = credentials.RefreshToken });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        using var scope = host.Services.CreateScope();
        var token = await scope.ServiceProvider.GetRequiredService<AppDbContext>().RefreshTokens.SingleAsync();
        Assert.False(token.IsRevoked);
    }

    [Fact]
    public async Task Reuse_PersistenceFailure_DoesNotClaimRevocationSucceeded()
    {
        using var host = new RegistrationTestHost();
        await SeedAsync(host);
        using var client = host.CreateClient();
        var credentials = await LoginAsync(client);
        using var rotated = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = credentials.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
        host.FailDatabaseWrites = true;
        using var replay = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = credentials.RefreshToken });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, replay.StatusCode);
    }

    [Theory]
    [InlineData("register")]
    [InlineData("verify-email")]
    [InlineData("resend-verification")]
    [InlineData("login")]
    [InlineData("refresh")]
    [InlineData("logout")]
    public async Task AuthOverHttp_IsRejected_WithoutRedirect_WhileDiagnosticsStillWork(string endpoint)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("http://localhost"),
            AllowAutoRedirect = false
        });
        using var response = await client.PostAsJsonAsync($"/api/v1/auth/{endpoint}", new { });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(response.Headers.Location);
        Assert.True(response.Headers.CacheControl?.NoStore);
        using var info = await client.GetAsync("/api/v1/system/info");
        Assert.Equal(HttpStatusCode.OK, info.StatusCode);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task OversizedAuthBody_Is413_ForKnownLengthAndStreaming(bool streamed)
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        using HttpContent content = streamed
            ? new StreamingBody()
            : new StringContent(new string('x', AuthenticationRequestGuards.MaximumBodyBytes + 1), Encoding.UTF8, "application/json");
        using var response = await client.PostAsync("/api/v1/auth/login", content);
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    [Fact]
    public async Task LoginRateLimit_RejectsUnknownEmailsWithRetryAfter()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();
        for (var i = 0; i < 10; i++)
        {
            using var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = $"missing{i}@example.test", password = Password });
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
        using var limited = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "another@example.test", password = Password });
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.NotNull(limited.Headers.RetryAfter);
        Assert.True(limited.Headers.CacheControl?.NoStore);
    }

    private static async Task<ApplicationUser> SeedAsync(RegistrationTestHost host)
    {
        using var scope = host.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser { Email = Email, UserName = manager.NormalizeEmail(Email), EmailConfirmed = true, IsEnabled = true, LockoutEnabled = true };
        Assert.True((await manager.CreateAsync(user, Password)).Succeeded);
        return user;
    }

    private static async Task<CustomerLoginResponse> LoginAsync(HttpClient client)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = Email, password = Password });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
    }

    private sealed class StreamingBody : HttpContent
    {
        public StreamingBody() => Headers.ContentType = new("application/json");
        protected override bool TryComputeLength(out long length) { length = 0; return false; }
        protected override async Task SerializeToStreamAsync(Stream stream, TransportContext? context) =>
            await stream.WriteAsync(new byte[AuthenticationRequestGuards.MaximumBodyBytes + 1]);
    }
}

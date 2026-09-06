using System.Net;
using System.Net.Http.Json;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Banking.IntegrationTests;

public sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("BANKING_AUTH_TEST_DATABASE")))
            Skip = "Requires explicitly configured disposable PostgreSQL database.";
    }
}

[CollectionDefinition("Postgres sessions", DisableParallelization = true)]
public sealed class PostgresSessionCollection : ICollectionFixture<PostgresSessionHost> { }

[Collection("Postgres sessions")]
public sealed class PostgresSessionTests(PostgresSessionHost host)
{
    [PostgresFact]
    public async Task ThirtyRotationsShareOnePersistedBudget_AndThirtyFirstIsLimited()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        var current = login.RefreshToken;
        for (var i = 0; i < 30; i++)
        {
            using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = current });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            current = (await response.Content.ReadFromJsonAsync<CustomerLoginResponse>())!.RefreshToken;
        }
        using var limited = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = current });
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.NotNull(limited.Headers.RetryAfter);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var session = await db.CustomerSessions.SingleAsync(s => s.UserId == user.Id);
        Assert.Equal(30, session.RefreshWindowCount);
        Assert.Equal(31, await db.RefreshTokens.CountAsync(t => t.SessionId == session.Id));
    }

    [PostgresFact]
    public async Task Migration_PreservesLegacyRows_ButLegacyRefreshCannotAuthenticate()
    {
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(db.Database.HasPendingModelChanges());
        var legacy = await db.RefreshTokens.SingleAsync(t => t.TokenHash == PostgresSessionHost.LegacyHash);
        Assert.Null(legacy.SessionId);
        Assert.NotNull(await db.Users.FindAsync(legacy.UserId));
        using var client = host.CreateClient();
        using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = PostgresSessionHost.LegacyToken });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [PostgresFact]
    public async Task SimultaneousRefresh_OnlyOneRotationCommits_ThenFamilyIsRevoked()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        var other = await CustomerSessionTests.LoginAsync(client, user.Email!);
        host.Writes.Arm();
        var requests = new[] { client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken }),
            client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken }) };
        var results = await Task.WhenAll(requests);
        try
        {
            Assert.Single(results, r => r.StatusCode == HttpStatusCode.OK);
            Assert.Single(results, r => r.StatusCode == HttpStatusCode.Unauthorized);
            var winner = (await results.Single(r => r.StatusCode == HttpStatusCode.OK).Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
            Assert.Equal(HttpStatusCode.Unauthorized, await CustomerSessionTests.MeAsync(client, winner.AccessToken));
            Assert.Equal(HttpStatusCode.OK, await CustomerSessionTests.MeAsync(client, other.AccessToken));
            using var scope = host.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var hash = scope.ServiceProvider.GetRequiredService<ITokenService>().ComputeHash(login.RefreshToken);
            var ancestor = await db.RefreshTokens.SingleAsync(t => t.TokenHash == hash);
            Assert.Equal(2, await db.RefreshTokens.CountAsync(t => t.SessionId == ancestor.SessionId));
            Assert.False(await db.RefreshTokens.AnyAsync(t => t.SessionId == ancestor.SessionId && t.RevokedAtUtc == null));
        }
        finally { foreach (var response in results) response.Dispose(); }
    }

    [PostgresFact]
    public async Task LogoutRacingRefresh_CannotResurrectTheSession()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        host.Writes.Arm();
        var refreshTask = client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        var logoutTask = client.PostAsJsonAsync("/api/v1/auth/logout", new { login.RefreshToken });
        using var refresh = await refreshTask;
        using var logout = await logoutTask;
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Contains(refresh.StatusCode, new[] { HttpStatusCode.OK, HttpStatusCode.Unauthorized });
        Assert.Equal(HttpStatusCode.Unauthorized, await CustomerSessionTests.MeAsync(client, login.AccessToken));
        if (refresh.StatusCode == HttpStatusCode.OK)
        {
            var child = (await refresh.Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
            Assert.Equal(HttpStatusCode.Unauthorized, await CustomerSessionTests.MeAsync(client, child.AccessToken));
            using var retry = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { child.RefreshToken });
            Assert.Equal(HttpStatusCode.Unauthorized, retry.StatusCode);
        }
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.RefreshTokens.AnyAsync(t => t.UserId == user.Id && t.RevokedAtUtc == null));
    }

    [PostgresFact]
    public async Task FailedRotation_RollsBackConsumptionAndSessionUpdate()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        Guid version;
        using (var scope = host.Services.CreateScope())
            version = (await scope.ServiceProvider.GetRequiredService<AppDbContext>().CustomerSessions.SingleAsync(s => s.UserId == user.Id)).Version;
        // Deliberate unique-index violation inside the real PostgreSQL transaction.
        host.RepeatedRefreshToken = login.RefreshToken;
        try
        {
            using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        }
        finally { host.RepeatedRefreshToken = null; }
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync(s => s.UserId == user.Id);
            Assert.Equal(version, session.Version);
            Assert.Equal(0, session.RefreshWindowCount);
            var token = await db.RefreshTokens.SingleAsync(t => t.UserId == user.Id);
            Assert.Null(token.RevokedAtUtc);
        }
        using var retry = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, retry.StatusCode);
    }

    [PostgresFact]
    public async Task SessionLookupFailure_FailsClosedWith503_ThenRecovers()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        host.Reads.Fail = true;
        try { Assert.Equal(HttpStatusCode.ServiceUnavailable, await CustomerSessionTests.MeAsync(client, login.AccessToken)); }
        finally { host.Reads.Fail = false; }
        Assert.Equal(HttpStatusCode.OK, await CustomerSessionTests.MeAsync(client, login.AccessToken));
    }
}

public sealed class PostgresSessionHost : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string LegacyToken = "legacy-disposable-database-token-only";
    public static readonly string LegacyHash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
        System.Text.Encoding.UTF8.GetBytes(LegacyToken))).ToLowerInvariant();
    public SessionWriteBarrier Writes { get; } = new();
    public SessionReadFailure Reads { get; } = new();
    public string? RepeatedRefreshToken { get; set; }
    private readonly string connectionString;

    public PostgresSessionHost()
    {
        var configured = Environment.GetEnvironmentVariable("BANKING_AUTH_TEST_DATABASE");
        if (string.IsNullOrWhiteSpace(configured)) { connectionString = string.Empty; return; }
        var settings = new NpgsqlConnectionStringBuilder(configured);
        if (settings.Database != "banking_lab_auth_repair_test" || settings.Host is not ("localhost" or "127.0.0.1"))
            throw new InvalidOperationException("Only the explicitly named local disposable database is allowed.");
        settings.IncludeErrorDetail = false;
        connectionString = settings.ConnectionString;
        ClientOptions.BaseAddress = new Uri("https://localhost");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseTestAuthentication();
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<AppDbContext>();
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(o => o.UseNpgsql(connectionString).AddInterceptors(Writes, Reads));
            services.RemoveAll<ITokenService>();
            services.AddSingleton<ITokenService>(sp => new TestTokenService(
                new TokenService(sp.GetRequiredService<IOptions<JwtOptions>>()), () => RepeatedRefreshToken));
        });
    }

    public async Task InitializeAsync()
    {
        if (connectionString.Length == 0) return;
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var applied = (await db.Database.GetAppliedMigrationsAsync()).ToArray();
        if (applied.Length == 0)
        {
            // Verify an actual upgrade containing a pre-session user/token, not only a fresh schema.
            await db.GetService<IMigrator>().MigrateAsync("20260904130627_AddCustomerRefreshTokens");
            var user = await CustomerSessionTests.SeedAsync(Services);
            var now = DateTime.UtcNow;
            await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"CustomerRefreshTokens\" (\"UserId\", \"TokenHash\", \"ExpiresAtUtc\", \"CreatedAtUtc\") VALUES ({user.Id}, {LegacyHash}, {now.AddDays(1)}, {now})");
        }
        await db.Database.MigrateAsync();
    }

    Task IAsyncLifetime.DisposeAsync() { Dispose(); return Task.CompletedTask; }

    private sealed class TestTokenService(TokenService inner, Func<string?> repeated) : ITokenService
    {
        public IssuedAccessToken GenerateAccessToken(ApplicationUser user, CustomerSession session) => inner.GenerateAccessToken(user, session);
        public string GenerateRefreshToken() => repeated() ?? inner.GenerateRefreshToken();
        public string ComputeHash(string token) => inner.ComputeHash(token);
    }
}

public sealed class SessionWriteBarrier : SaveChangesInterceptor
{
    private TaskCompletionSource? ready;
    private int arrivals;
    public void Arm() { arrivals = 0; ready = new(TaskCreationOptions.RunContinuationsAsynchronously); }
    public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData data,
        InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        var gate = ready;
        if (gate is not null && data.Context!.ChangeTracker.Entries<CustomerSession>().Any(e => e.State == EntityState.Modified))
        {
            var arrival = Interlocked.Increment(ref arrivals);
            if (arrival == 2) { ready = null; gate.TrySetResult(); }
            if (arrival <= 2) await gate.Task.WaitAsync(TimeSpan.FromSeconds(15), cancellationToken);
        }
        return result;
    }
}

public sealed class SessionReadFailure : DbCommandInterceptor
{
    public bool Fail { get; set; }
    public override ValueTask<InterceptionResult<System.Data.Common.DbDataReader>> ReaderExecutingAsync(
        System.Data.Common.DbCommand command, CommandEventData eventData,
        InterceptionResult<System.Data.Common.DbDataReader> result, CancellationToken cancellationToken = default)
    {
        if (Fail && command.CommandText.Contains("CustomerSessions")) throw new TimeoutException("Injected session read failure.");
        return ValueTask.FromResult(result);
    }
}

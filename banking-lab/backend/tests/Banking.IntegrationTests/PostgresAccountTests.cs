using System.Net;
using System.Net.Http.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace Banking.IntegrationTests;

public sealed class AccountsPostgresFactAttribute : FactAttribute
{
    public AccountsPostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("BANKING_ACCOUNTS_TEST_DATABASE")))
            Skip = "Requires approval for an explicitly configured fresh disposable accounts PostgreSQL database.";
    }
}

[CollectionDefinition("Postgres accounts", DisableParallelization = true)]
public sealed class PostgresAccountsCollection : ICollectionFixture<PostgresAccountsHost> { }

[Collection("Postgres accounts")]
public sealed class PostgresAccountTests(PostgresAccountsHost host)
{
    [AccountsPostgresFact]
    public async Task UpgradePreservesCustomerAndSessionWithoutOpeningAnAccount()
    {
        Assert.True(host.Upgraded);
        using var client = host.CreateClient();
        using var read = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Get, host.ExistingAccessToken);
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.NotNull(await db.Users.FindAsync(host.ExistingUserId));
        Assert.True(await db.CustomerSessions.AnyAsync(s => s.UserId == host.ExistingUserId));
        Assert.False(await db.CustomerAccounts.AnyAsync(a => a.UserId == host.ExistingUserId));
        Assert.False(db.Database.HasPendingModelChanges());
    }

    [AccountsPostgresFact]
    public async Task SimultaneousOpeningReturnsTheSameCommittedAccount()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        host.Writes.Arm();
        var responses = await Task.WhenAll(
            CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token),
            CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token));
        try
        {
            Assert.Single(responses, r => r.StatusCode == HttpStatusCode.Created);
            Assert.Single(responses, r => r.StatusCode == HttpStatusCode.OK);
            var summaries = await Task.WhenAll(responses.Select(r => r.Content.ReadFromJsonAsync<AccountSummary>()));
            Assert.Equal(summaries[0], summaries[1]);
            using var scope = host.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(1, await db.CustomerAccounts.CountAsync(a => a.UserId == user.Id));
            using var retry = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);
            Assert.Equal(summaries[0], await retry.Content.ReadFromJsonAsync<AccountSummary>());
        }
        finally { foreach (var response in responses) response.Dispose(); }
    }

    [AccountsPostgresFact]
    public async Task DatabaseRejectsInvalidCurrencyNonzeroAndOrphanAccounts()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        foreach (var invalid in new[]
        {
            new CustomerAccount { UserId = user.Id, Currency = "USD" },
            new CustomerAccount { UserId = user.Id, BalanceMinor = 1 },
            new CustomerAccount { UserId = user.Id, BalanceMinor = -1 },
            new CustomerAccount { UserId = Guid.NewGuid().ToString() }
        })
        {
            using var scope = host.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.CustomerAccounts.Add(invalid);
            var exception = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
            var postgres = Assert.IsType<PostgresException>(exception.InnerException);
            Assert.Equal(invalid.UserId == user.Id ? PostgresErrorCodes.CheckViolation : PostgresErrorCodes.ForeignKeyViolation,
                postgres.SqlState);
        }
    }

    [AccountsPostgresFact]
    public async Task OwnerUniquenessAndRestrictedDeletionAreEnforced()
    {
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.CustomerAccounts.Add(new CustomerAccount { UserId = user.Id });
            await db.SaveChangesAsync();
        }
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.CustomerAccounts.Add(new CustomerAccount { UserId = user.Id });
            var exception = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
            Assert.Equal(CustomerAccount.OwnerIndex, Assert.IsType<PostgresException>(exception.InnerException).ConstraintName);
        }
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Remove((await db.Users.FindAsync(user.Id))!);
            var exception = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
            var postgres = Assert.IsType<PostgresException>(exception.InnerException);
            Assert.Equal("FK_CustomerAccounts_AspNetUsers_UserId", postgres.ConstraintName);
        }
    }
}

public sealed class PostgresAccountsHost : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string connectionString = string.Empty;
    public AccountWriteBarrier Writes { get; } = new();
    public bool Upgraded { get; private set; }
    public string? ExistingUserId { get; private set; }
    public string? ExistingAccessToken { get; private set; }

    public PostgresAccountsHost()
    {
        var configured = Environment.GetEnvironmentVariable("BANKING_ACCOUNTS_TEST_DATABASE");
        if (string.IsNullOrWhiteSpace(configured)) return;
        var settings = new NpgsqlConnectionStringBuilder(configured);
        if (settings.Database != "banking_lab_accounts_test" || settings.Host is not ("localhost" or "127.0.0.1")
            || !string.IsNullOrWhiteSpace(settings.SearchPath))
            throw new InvalidOperationException("Only the explicitly approved local banking_lab_accounts_test database with the default search path is allowed.");
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
            services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString).AddInterceptors(Writes));
        });
    }

    public async Task InitializeAsync()
    {
        if (connectionString.Length == 0) return;
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if ((await db.Database.GetAppliedMigrationsAsync()).Any())
            throw new InvalidOperationException("Account upgrade verification requires a fresh approved disposable database. No reset or downgrade is performed.");
        await db.GetService<IMigrator>().MigrateAsync("20260904152654_AddCustomerSessions");
        var user = await CustomerSessionTests.SeedAsync(Services);
        using var client = CreateClient();
        ExistingUserId = user.Id;
        ExistingAccessToken = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        await db.Database.MigrateAsync();
        Upgraded = true;
    }

    Task IAsyncLifetime.DisposeAsync() { Dispose(); return Task.CompletedTask; }
}

public sealed class AccountWriteBarrier : SaveChangesInterceptor
{
    private TaskCompletionSource? ready;
    private int arrivals;
    public void Arm() { arrivals = 0; ready = new(TaskCreationOptions.RunContinuationsAsynchronously); }
    public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData data,
        InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        var gate = ready;
        if (gate is not null && data.Context!.ChangeTracker.Entries<CustomerAccount>().Any(e => e.State == EntityState.Added))
        {
            var arrival = Interlocked.Increment(ref arrivals);
            if (arrival == 2) { ready = null; gate.TrySetResult(); }
            if (arrival <= 2) await gate.Task.WaitAsync(TimeSpan.FromSeconds(15), cancellationToken);
        }
        return result;
    }
}

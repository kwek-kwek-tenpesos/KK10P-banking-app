using System.Net;
using System.Net.Http.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Ledger;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace Banking.IntegrationTests;

public sealed class LedgerPostgresFactAttribute : FactAttribute
{
    public LedgerPostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("BANKING_LEDGER_TEST_DATABASE")))
            Skip = "Requires the explicitly configured fresh local banking_lab_ledger_test database.";
    }
}

[CollectionDefinition("Postgres ledger", DisableParallelization = true)]
public sealed class PostgresLedgerCollection : ICollectionFixture<PostgresLedgerHost> { }

[Collection("Postgres ledger")]
public sealed class PostgresLedgerTests(PostgresLedgerHost host)
{
    [LedgerPostgresFact]
    public async Task UpgradePreservesExistingAccountAndAddsLedgerWithoutFundingIt()
    {
        Assert.True(host.Upgraded);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(0, (await db.CustomerAccounts.SingleAsync(account => account.Id == host.ExistingAccountId)).BalanceMinor);
        Assert.False(await db.LedgerTransactions.AnyAsync(item => item.InitiatedByUserId == host.ExistingUserId));
        Assert.False(await db.LedgerPostings.AnyAsync(item => item.CustomerAccountId == host.ExistingAccountId));
        Assert.False(db.Database.HasPendingModelChanges());
    }

    [LedgerPostgresFact]
    public async Task ConcurrentReplayCommitsOneBalancedGrant()
    {
        var fixture = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        var key = Guid.NewGuid();
        var responses = await Task.WhenAll(
            host.SendFundingAsync(client, fixture.Token, key),
            host.SendFundingAsync(client, fixture.Token, key));
        try
        {
            Assert.Single(responses, response => response.StatusCode == HttpStatusCode.Created);
            Assert.Single(responses, response => response.StatusCode == HttpStatusCode.OK);
            var receipts = await Task.WhenAll(responses.Select(response =>
                response.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>()));
            Assert.Equal(receipts[0]!.TransactionId, receipts[1]!.TransactionId);
            Assert.Contains(receipts, receipt => receipt!.Replayed);
            Assert.Contains(receipts, receipt => !receipt!.Replayed);
            await AssertAccountLedgerAsync(fixture.AccountId, 5_000_000, 1);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [LedgerPostgresFact]
    public async Task ConcurrentDistinctGrantsRespectTheDailyCap()
    {
        var fixture = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        var responses = await Task.WhenAll(
            host.SendFundingAsync(client, fixture.Token, Guid.NewGuid()),
            host.SendFundingAsync(client, fixture.Token, Guid.NewGuid()));
        try
        {
            Assert.All(responses, response => Assert.Equal(HttpStatusCode.Created, response.StatusCode));
            await AssertAccountLedgerAsync(fixture.AccountId, 10_000_000, 2);
            using var third = await host.SendFundingAsync(client, fixture.Token, Guid.NewGuid());
            Assert.Equal(HttpStatusCode.Conflict, third.StatusCode);
            await AssertAccountLedgerAsync(fixture.AccountId, 10_000_000, 2);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [LedgerPostgresFact]
    public async Task DatabaseConstraintsRejectNegativeBalanceAndMalformedPostings()
    {
        var fixture = await host.CreateCustomerWithAccountAsync();
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var account = await db.CustomerAccounts.SingleAsync(item => item.Id == fixture.AccountId);
            account.BalanceMinor = -1;
            var exception = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
            Assert.Equal("CK_CustomerAccounts_NonnegativeBalance",
                Assert.IsType<PostgresException>(exception.InnerException).ConstraintName);
        }

        using (var client = host.CreateClient())
        using (var funded = await host.SendFundingAsync(client, fixture.Token, Guid.NewGuid()))
            Assert.Equal(HttpStatusCode.Created, funded.StatusCode);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var transactionId = await db.LedgerTransactions
                .Where(item => item.InitiatedByUserId == fixture.UserId).Select(item => item.Id).SingleAsync();
            var exception = await Assert.ThrowsAsync<PostgresException>(() =>
                db.Database.ExecuteSqlInterpolatedAsync($"""
                    INSERT INTO "LedgerPostings"
                        ("Id", "LedgerTransactionId", "Position", "CustomerAccountId", "BookAccount",
                         "AmountMinor", "Currency", "CreatedAtUtc")
                    VALUES
                        ({Guid.NewGuid()}, {transactionId}, {(short)1}, NULL, NULL,
                         {1L}, {"PHP"}, {DateTime.UtcNow})
                    """));
            Assert.Equal(PostgresErrorCodes.CheckViolation,
                exception.SqlState);
        }
    }

    private async Task AssertAccountLedgerAsync(Guid accountId, long balance, int transactions)
    {
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(balance, (await db.CustomerAccounts.SingleAsync(item => item.Id == accountId)).BalanceMinor);
        var transactionIds = await db.LedgerTransactions
            .Where(item => item.Postings.Any(posting => posting.CustomerAccountId == accountId))
            .Select(item => item.Id).ToListAsync();
        Assert.Equal(transactions, transactionIds.Count);
        foreach (var transactionId in transactionIds)
        {
            var postings = await db.LedgerPostings.Where(item => item.LedgerTransactionId == transactionId).ToListAsync();
            Assert.Equal(2, postings.Count);
            Assert.Equal(0, postings.Sum(item => item.AmountMinor));
        }
    }
}

public sealed class PostgresLedgerHost : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string connectionString = string.Empty;
    public bool Upgraded { get; private set; }
    public Guid ExistingAccountId { get; private set; }
    public string ExistingUserId { get; private set; } = string.Empty;

    public PostgresLedgerHost()
    {
        var configured = Environment.GetEnvironmentVariable("BANKING_LEDGER_TEST_DATABASE");
        if (string.IsNullOrWhiteSpace(configured)) return;
        var settings = new NpgsqlConnectionStringBuilder(configured);
        if (settings.Database != "banking_lab_ledger_test" || settings.Host is not ("localhost" or "127.0.0.1") ||
            !string.IsNullOrWhiteSpace(settings.SearchPath))
            throw new InvalidOperationException("Only local banking_lab_ledger_test with the default search path is allowed.");
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
            services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));
        });
    }

    public async Task InitializeAsync()
    {
        if (connectionString.Length == 0) return;
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if ((await db.Database.GetAppliedMigrationsAsync()).Any())
            throw new InvalidOperationException("Ledger verification requires a fresh disposable database; it never resets one.");
        await db.GetService<IMigrator>().MigrateAsync("20260906042449_AddCustomerAccounts");
        var fixture = await CreateCustomerWithAccountAsync();
        ExistingAccountId = fixture.AccountId;
        ExistingUserId = fixture.UserId;
        await db.Database.MigrateAsync();
        Upgraded = true;
    }

    public async Task<(string UserId, Guid AccountId, string Token)> CreateCustomerWithAccountAsync()
    {
        var user = await CustomerSessionTests.SeedAsync(Services);
        using var client = CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        using var opened = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);
        var account = (await opened.Content.ReadFromJsonAsync<Banking.Api.Features.Accounts.AccountSummary>())!;
        return (user.Id, account.Id, token);
    }

    public Task<HttpResponseMessage> SendFundingAsync(HttpClient client, string token, Guid key)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, DevelopmentFundingEndpoints.Route);
        request.Headers.Authorization = new("Bearer", token);
        request.Headers.TryAddWithoutValidation(DevelopmentFundingRequestGuards.IdempotencyHeader, key.ToString());
        request.Content = JsonContent.Create(new { });
        return client.SendAsync(request);
    }

    Task IAsyncLifetime.DisposeAsync()
    {
        Dispose();
        return Task.CompletedTask;
    }
}

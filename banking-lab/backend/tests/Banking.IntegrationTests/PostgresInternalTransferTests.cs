using System.Net;
using System.Net.Http.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Ledger;
using Banking.Api.Features.Transfers;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;

namespace Banking.IntegrationTests;

public sealed class TransferPostgresFactAttribute : FactAttribute
{
    public TransferPostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("BANKING_TRANSFER_TEST_DATABASE")))
            Skip = "Requires the explicitly configured fresh local banking_lab_transfer_test database.";
    }
}

[CollectionDefinition("Postgres internal transfers", DisableParallelization = true)]
public sealed class PostgresInternalTransferCollection : ICollectionFixture<PostgresInternalTransferHost> { }

[Collection("Postgres internal transfers")]
public sealed class PostgresInternalTransferTests(PostgresInternalTransferHost host)
{
    [TransferPostgresFact]
    public async Task UpgradePreservesExistingFundingAndHasNoModelDrift()
    {
        Assert.True(host.Upgraded);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(5_000_000,
            (await db.CustomerAccounts.SingleAsync(account => account.Id == host.ExistingSourceId)).BalanceMinor);
        var funding = await db.LedgerTransactions.Include(item => item.Postings)
            .SingleAsync(item => item.Id == host.ExistingFundingId);
        Assert.Equal(LedgerTransaction.DevelopmentFundingOperation, funding.Operation);
        Assert.Equal(0, funding.Postings.Sum(item => item.AmountMinor));
        Assert.False(db.Database.HasPendingModelChanges());
    }

    [TransferPostgresFact]
    public async Task TransferCommitsBothBalancesAndOneBalancedCustomerPair()
    {
        var source = await host.CreateCustomerWithAccountAsync();
        var destination = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        await host.FundAsync(client, source.Token, Guid.NewGuid());
        using var response = await host.TransferAsync(client, source.Token, Guid.NewGuid(),
            destination.AccountId, 1_250_050);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var receipt = (await response.Content.ReadFromJsonAsync<InternalTransferReceipt>())!;
        Assert.Equal("3749950", receipt.SourceBalanceAfterMinor);

        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(3_749_950,
            (await db.CustomerAccounts.SingleAsync(item => item.Id == source.AccountId)).BalanceMinor);
        Assert.Equal(1_250_050,
            (await db.CustomerAccounts.SingleAsync(item => item.Id == destination.AccountId)).BalanceMinor);
        var transfer = await db.LedgerTransactions.Include(item => item.Postings)
            .SingleAsync(item => item.Id == receipt.TransactionId);
        Assert.Equal(LedgerTransaction.InternalTransferOperation, transfer.Operation);
        Assert.Equal(0, transfer.Postings.Sum(item => item.AmountMinor));
        Assert.All(transfer.Postings, item => Assert.NotNull(item.CustomerAccountId));
    }

    [TransferPostgresFact]
    public async Task ConcurrentSameKeyCommitsExactlyOnceAndReturnsOneReplay()
    {
        var source = await host.CreateCustomerWithAccountAsync();
        var destination = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        await host.FundAsync(client, source.Token, Guid.NewGuid());
        var key = Guid.NewGuid();
        var responses = await Task.WhenAll(
            host.TransferAsync(client, source.Token, key, destination.AccountId, 1_000_000),
            host.TransferAsync(client, source.Token, key, destination.AccountId, 1_000_000));
        try
        {
            Assert.Single(responses, item => item.StatusCode == HttpStatusCode.Created);
            Assert.Single(responses, item => item.StatusCode == HttpStatusCode.OK);
            var receipts = await Task.WhenAll(responses.Select(item =>
                item.Content.ReadFromJsonAsync<InternalTransferReceipt>()));
            Assert.Equal(receipts[0]!.TransactionId, receipts[1]!.TransactionId);
            Assert.Contains(receipts, item => item!.Replayed);
            Assert.Contains(receipts, item => !item!.Replayed);
            await AssertBalancesAsync(source.AccountId, 4_000_000, destination.AccountId, 1_000_000);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [TransferPostgresFact]
    public async Task ConcurrentDistinctTransfersCannotOverspendOrExceedDailyCap()
    {
        var source = await host.CreateCustomerWithAccountAsync();
        var destination = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        await host.FundAsync(client, source.Token, Guid.NewGuid());
        await host.FundAsync(client, source.Token, Guid.NewGuid());
        var responses = await Task.WhenAll(
            host.TransferAsync(client, source.Token, Guid.NewGuid(), destination.AccountId, 5_000_000),
            host.TransferAsync(client, source.Token, Guid.NewGuid(), destination.AccountId, 5_000_000),
            host.TransferAsync(client, source.Token, Guid.NewGuid(), destination.AccountId, 5_000_000));
        try
        {
            Assert.Equal(2, responses.Count(item => item.StatusCode == HttpStatusCode.Created));
            Assert.Single(responses, item => item.StatusCode == HttpStatusCode.Conflict);
            await AssertBalancesAsync(source.AccountId, 0, destination.AccountId, 10_000_000);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [TransferPostgresFact]
    public async Task OppositeDirectionTransfersUseOneLockOrderAndPreserveValue()
    {
        var first = await host.CreateCustomerWithAccountAsync();
        var second = await host.CreateCustomerWithAccountAsync();
        using var client = host.CreateClient();
        await host.FundAsync(client, first.Token, Guid.NewGuid());
        await host.FundAsync(client, second.Token, Guid.NewGuid());
        var responses = await Task.WhenAll(
            host.TransferAsync(client, first.Token, Guid.NewGuid(), second.AccountId, 1_000_000),
            host.TransferAsync(client, second.Token, Guid.NewGuid(), first.AccountId, 1_000_000));
        try
        {
            Assert.All(responses, item => Assert.Equal(HttpStatusCode.Created, item.StatusCode));
            await AssertBalancesAsync(first.AccountId, 5_000_000, second.AccountId, 5_000_000);
        }
        finally
        {
            foreach (var response in responses) response.Dispose();
        }
    }

    [TransferPostgresFact]
    public async Task DatabaseRejectsUnsupportedOperationAndLedgerMutation()
    {
        var source = await host.CreateCustomerWithAccountAsync();
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var exception = await Assert.ThrowsAsync<PostgresException>(() =>
                db.Database.ExecuteSqlInterpolatedAsync($"""
                    INSERT INTO "LedgerTransactions"
                        ("Id", "Operation", "InitiatedByUserId", "IdempotencyKey", "RequestFingerprint",
                         "Currency", "BalanceAfterMinor", "CreatedAtUtc")
                    VALUES ({Guid.NewGuid()}, {"UNSUPPORTED"}, {source.UserId}, {Guid.NewGuid()},
                        {new string('A', 64)}, {"PHP"}, {0L}, {DateTime.UtcNow})
                    """));
            Assert.Equal("CK_LedgerTransactions_Operation", exception.ConstraintName);
        }

        using var client = host.CreateClient();
        await host.FundAsync(client, source.Token, Guid.NewGuid());
        var destination = await host.CreateCustomerWithAccountAsync();
        using var response = await host.TransferAsync(client, source.Token, Guid.NewGuid(),
            destination.AccountId, 1);
        var receipt = (await response.Content.ReadFromJsonAsync<InternalTransferReceipt>())!;
        using var verification = host.Services.CreateScope();
        var database = verification.ServiceProvider.GetRequiredService<AppDbContext>();
        var transaction = await database.LedgerTransactions.SingleAsync(item => item.Id == receipt.TransactionId);
        transaction.BalanceAfterMinor--;
        await Assert.ThrowsAsync<InvalidOperationException>(() => database.SaveChangesAsync());
    }

    private async Task AssertBalancesAsync(Guid firstId, long firstBalance, Guid secondId, long secondBalance)
    {
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(firstBalance,
            (await db.CustomerAccounts.SingleAsync(item => item.Id == firstId)).BalanceMinor);
        Assert.Equal(secondBalance,
            (await db.CustomerAccounts.SingleAsync(item => item.Id == secondId)).BalanceMinor);
        var transactions = await db.LedgerTransactions
            .Where(item => item.Operation == LedgerTransaction.InternalTransferOperation &&
                item.Postings.Any(posting => posting.CustomerAccountId == firstId ||
                    posting.CustomerAccountId == secondId))
            .Include(item => item.Postings).ToListAsync();
        Assert.All(transactions, transaction => Assert.Equal(0, transaction.Postings.Sum(item => item.AmountMinor)));
    }
}

public sealed class PostgresInternalTransferHost : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string connectionString = string.Empty;
    public bool Upgraded { get; private set; }
    public Guid ExistingSourceId { get; private set; }
    public Guid ExistingFundingId { get; private set; }

    public PostgresInternalTransferHost()
    {
        var configured = Environment.GetEnvironmentVariable("BANKING_TRANSFER_TEST_DATABASE");
        if (string.IsNullOrWhiteSpace(configured)) return;
        var settings = new NpgsqlConnectionStringBuilder(configured);
        if (settings.Database != "banking_lab_transfer_test" ||
            settings.Host is not ("localhost" or "127.0.0.1") ||
            !string.IsNullOrWhiteSpace(settings.SearchPath))
            throw new InvalidOperationException(
                "Only local banking_lab_transfer_test with the default search path is allowed.");
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
            services.AddSingleton<IStartupFilter, UniqueRemoteAddressStartupFilter>();
        });
    }

    public async Task InitializeAsync()
    {
        if (connectionString.Length == 0) return;
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if ((await db.Database.GetAppliedMigrationsAsync()).Any())
            throw new InvalidOperationException(
                "Transfer verification requires a fresh disposable database; it never resets one.");
        await db.GetService<IMigrator>().MigrateAsync("20260908124011_AddLedgerAndDevelopmentFunding");
        var source = await CreateCustomerWithAccountAsync();
        using var client = CreateClient();
        var receipt = await FundAsync(client, source.Token, Guid.NewGuid());
        ExistingSourceId = source.AccountId;
        ExistingFundingId = receipt.TransactionId;
        await db.Database.MigrateAsync();
        Upgraded = true;
    }

    public async Task<(string UserId, Guid AccountId, string Token)> CreateCustomerWithAccountAsync()
    {
        var user = await CustomerSessionTests.SeedAsync(Services);
        using var client = CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        using var opened = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);
        var account = (await opened.Content.ReadFromJsonAsync<AccountSummary>())!;
        return (user.Id, account.Id, token);
    }

    public async Task<DevelopmentFundingReceipt> FundAsync(HttpClient client, string token, Guid key)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, DevelopmentFundingEndpoints.Route);
        request.Headers.Authorization = new("Bearer", token);
        request.Headers.TryAddWithoutValidation(DevelopmentFundingRequestGuards.IdempotencyHeader, key.ToString("D"));
        request.Content = JsonContent.Create(new { });
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>())!;
    }

    public Task<HttpResponseMessage> TransferAsync(HttpClient client, string token, Guid key,
        Guid destination, long amount) => InternalTransferEndpointTests.SendAsync(client, token, key,
        destination, amount.ToString(System.Globalization.CultureInfo.InvariantCulture));

    Task IAsyncLifetime.DisposeAsync()
    {
        Dispose();
        return Task.CompletedTask;
    }
}

internal sealed class UniqueRemoteAddressStartupFilter : IStartupFilter
{
    public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
    {
        app.Use(async (context, continuation) =>
        {
            context.Connection.RemoteIpAddress = new IPAddress(Guid.NewGuid().ToByteArray());
            await continuation();
        });
        next(app);
    };
}

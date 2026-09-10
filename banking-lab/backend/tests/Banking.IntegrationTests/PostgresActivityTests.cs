using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Activity;
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

public sealed class ActivityPostgresFactAttribute : FactAttribute
{
    public ActivityPostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("BANKING_ACTIVITY_TEST_DATABASE")))
            Skip = "Requires the explicitly configured fresh local banking_lab_activity_test database.";
    }
}

[CollectionDefinition("Postgres Activity", DisableParallelization = true)]
public sealed class PostgresActivityCollection : ICollectionFixture<PostgresActivityHost> { }

[Collection("Postgres Activity")]
public sealed class PostgresActivityTests(PostgresActivityHost host)
{
    [ActivityPostgresFact]
    public async Task UpgradePreservesHistoryAddsExpectedIndexAndReadsWithoutWriting()
    {
        Assert.True(host.Upgraded);
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(db.Database.HasPendingModelChanges());
        var beforeTransactions = await db.LedgerTransactions.CountAsync();
        var beforePostings = await db.LedgerPostings.CountAsync();
        var beforeBalance = await db.CustomerAccounts.SumAsync(item => item.BalanceMinor);
        var indexDefinition = await db.Database.SqlQuery<string>($"""
            SELECT indexdef AS "Value"
            FROM pg_indexes
            WHERE schemaname = current_schema()
              AND indexname = {LedgerPosting.ActivityHistoryIndex}
            """).SingleAsync();
        Assert.Contains("\"CustomerAccountId\", \"CreatedAtUtc\" DESC, \"LedgerTransactionId\" DESC",
            indexDefinition);

        using var client = host.CreateClient();
        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{ActivityEndpoints.RoutePrefix}?limit=1");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", host.SourceToken);
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, json.GetProperty("items").GetArrayLength());
        Assert.Equal(host.TransferId,
            json.GetProperty("items")[0].GetProperty("transactionId").GetGuid());
        var cursor = json.GetProperty("nextCursor").GetString();
        Assert.False(string.IsNullOrWhiteSpace(cursor));
        using var continuationRequest = new HttpRequestMessage(
            HttpMethod.Get,
            $"{ActivityEndpoints.RoutePrefix}?limit=1&cursor={Uri.EscapeDataString(cursor!)}");
        continuationRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", host.SourceToken);
        using var continuation = await client.SendAsync(continuationRequest);
        Assert.Equal(HttpStatusCode.OK, continuation.StatusCode);
        var continuationJson = await continuation.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(host.FundingId,
            continuationJson.GetProperty("items")[0].GetProperty("transactionId").GetGuid());
        Assert.Equal(JsonValueKind.Null, continuationJson.GetProperty("nextCursor").ValueKind);
        Assert.Equal(beforeTransactions, await db.LedgerTransactions.CountAsync());
        Assert.Equal(beforePostings, await db.LedgerPostings.CountAsync());
        Assert.Equal(beforeBalance, await db.CustomerAccounts.SumAsync(item => item.BalanceMinor));
    }
}

public sealed class PostgresActivityHost : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string connectionString = string.Empty;
    public bool Upgraded { get; private set; }
    public string SourceToken { get; private set; } = string.Empty;
    public Guid FundingId { get; private set; }
    public Guid TransferId { get; private set; }

    public PostgresActivityHost()
    {
        var configured = Environment.GetEnvironmentVariable("BANKING_ACTIVITY_TEST_DATABASE");
        if (string.IsNullOrWhiteSpace(configured)) return;
        var settings = new NpgsqlConnectionStringBuilder(configured);
        if (settings.Database != "banking_lab_activity_test" ||
            settings.Host is not ("localhost" or "127.0.0.1") ||
            !string.IsNullOrWhiteSpace(settings.SearchPath))
            throw new InvalidOperationException(
                "Only local banking_lab_activity_test with the default search path is allowed.");
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
                "Activity verification requires a fresh disposable database; it never resets one.");

        await db.GetService<IMigrator>().MigrateAsync("20260909065721_AddInternalTransfers");
        var source = await CreateCustomerWithAccountAsync();
        var destination = await CreateCustomerWithAccountAsync();
        using var client = CreateClient();
        var funding = await FundAsync(client, source.Token);
        using var transfer = await InternalTransferEndpointTests.SendAsync(client, source.Token, Guid.NewGuid(),
            destination.AccountId, "125");
        Assert.Equal(HttpStatusCode.Created, transfer.StatusCode);
        FundingId = funding.TransactionId;
        TransferId = (await transfer.Content.ReadFromJsonAsync<InternalTransferReceipt>())!.TransactionId;
        SourceToken = source.Token;

        await db.Database.MigrateAsync();
        Upgraded = true;
    }

    private async Task<(Guid AccountId, string Token)> CreateCustomerWithAccountAsync()
    {
        var user = await CustomerSessionTests.SeedAsync(Services);
        using var client = CreateClient();
        var token = (await CustomerSessionTests.LoginAsync(client, user.Email!)).AccessToken;
        using var opened = await CustomerAccountEndpointTests.SendAsync(client, HttpMethod.Put, token);
        var account = (await opened.Content.ReadFromJsonAsync<AccountSummary>())!;
        return (account.Id, token);
    }

    private static async Task<DevelopmentFundingReceipt> FundAsync(HttpClient client, string token)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, DevelopmentFundingEndpoints.Route);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        request.Headers.TryAddWithoutValidation(
            DevelopmentFundingRequestGuards.IdempotencyHeader, Guid.NewGuid().ToString("D"));
        request.Content = JsonContent.Create(new { });
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<DevelopmentFundingReceipt>())!;
    }

    Task IAsyncLifetime.DisposeAsync()
    {
        Dispose();
        return Task.CompletedTask;
    }
}

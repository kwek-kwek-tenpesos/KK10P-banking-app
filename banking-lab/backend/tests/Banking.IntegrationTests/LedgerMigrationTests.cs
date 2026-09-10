using Banking.api.Migrations;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Ledger;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace Banking.IntegrationTests;

public sealed class LedgerMigrationTests
{
    [Fact]
    public void ActivityMigrationAddsAndRemovesOnlyTheHistoryIndex()
    {
        var migration = new AddActivityHistoryIndex();
        var create = Assert.Single(migration.UpOperations.OfType<CreateIndexOperation>());
        Assert.Equal(LedgerPosting.ActivityHistoryIndex, create.Name);
        Assert.True(create.Name!.Length <= 63);
        Assert.Equal("LedgerPostings", create.Table);
        Assert.Equal(["CustomerAccountId", "CreatedAtUtc", "LedgerTransactionId"], create.Columns);
        Assert.NotNull(create.IsDescending);
        Assert.Equal([false, true, true], create.IsDescending!);
        Assert.Empty(migration.UpOperations.OfType<CreateTableOperation>());
        Assert.Empty(migration.UpOperations.OfType<DropTableOperation>());
        Assert.Empty(migration.UpOperations.OfType<AddColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<DropColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<AlterColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<DeleteDataOperation>());
        Assert.Empty(migration.UpOperations.OfType<UpdateDataOperation>());
        var drop = Assert.Single(migration.DownOperations.OfType<DropIndexOperation>());
        Assert.Equal(create.Name, drop.Name);
        Assert.Equal(create.Table, drop.Table);
    }

    [Fact]
    public void InternalTransferMigrationOnlyWidensTheOperationConstraint()
    {
        var migration = new AddInternalTransfers();
        Assert.Empty(migration.UpOperations.OfType<CreateTableOperation>());
        Assert.Empty(migration.UpOperations.OfType<DropTableOperation>());
        Assert.Empty(migration.UpOperations.OfType<DeleteDataOperation>());
        Assert.Empty(migration.UpOperations.OfType<UpdateDataOperation>());
        Assert.Empty(migration.UpOperations.OfType<AddColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<DropColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<AlterColumnOperation>());
        Assert.Single(migration.UpOperations.OfType<DropCheckConstraintOperation>(), operation =>
            operation.Name == "CK_LedgerTransactions_Operation");
        Assert.Single(migration.UpOperations.OfType<AddCheckConstraintOperation>(), operation =>
            operation.Name == "CK_LedgerTransactions_Operation" &&
            operation.Sql == "\"Operation\" IN ('DEVELOPMENT_FUNDING', 'INTERNAL_TRANSFER')");
    }

    [Fact]
    public void ForwardMigrationIsAdditiveApartFromReplacingTheZeroBalanceCheck()
    {
        var migration = new AddLedgerAndDevelopmentFunding();
        Assert.Equal(2, migration.UpOperations.OfType<CreateTableOperation>().Count());
        Assert.Empty(migration.UpOperations.OfType<DropTableOperation>());
        Assert.Empty(migration.UpOperations.OfType<DeleteDataOperation>());
        Assert.Empty(migration.UpOperations.OfType<UpdateDataOperation>());
        Assert.Empty(migration.UpOperations.OfType<DropColumnOperation>());
        Assert.Empty(migration.UpOperations.OfType<AlterColumnOperation>());
        Assert.Contains(migration.UpOperations.OfType<DropCheckConstraintOperation>(),
            operation => operation.Name == "CK_CustomerAccounts_ZeroBalance");
        Assert.Contains(migration.UpOperations.OfType<AddCheckConstraintOperation>(),
            operation => operation.Name == "CK_CustomerAccounts_NonnegativeBalance" &&
                operation.Sql == "\"BalanceMinor\" >= 0");

        var transactions = migration.UpOperations.OfType<CreateTableOperation>()
            .Single(operation => operation.Name == "LedgerTransactions");
        var postings = migration.UpOperations.OfType<CreateTableOperation>()
            .Single(operation => operation.Name == "LedgerPostings");
        Assert.Contains(transactions.CheckConstraints, constraint => constraint.Name == "CK_LedgerTransactions_Operation");
        Assert.Contains(postings.CheckConstraints, constraint => constraint.Name == "CK_LedgerPostings_ExactlyOneAccount");
    }

    [Fact]
    public void GeneratedPostgresSqlHasNoDataRewriteAndModelHasNoDrift()
    {
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseNpgsql().Options);
        var sql = context.GetService<IMigrator>().GenerateScript(
            "20260906042449_AddCustomerAccounts", "20260908124011_AddLedgerAndDevelopmentFunding");
        Assert.Contains("CREATE TABLE \"LedgerTransactions\"", sql);
        Assert.Contains("CREATE TABLE \"LedgerPostings\"", sql);
        Assert.Contains("CK_CustomerAccounts_NonnegativeBalance", sql);
        Assert.DoesNotContain("UPDATE \"", sql);
        Assert.DoesNotContain("DELETE FROM", sql);
        Assert.False(context.Database.HasPendingModelChanges());
    }

    [Fact]
    public void InternalTransferSqlOnlyReplacesTheOperationConstraintAndHasNoModelDrift()
    {
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseNpgsql().Options);
        var sql = context.GetService<IMigrator>().GenerateScript(
            "20260908124011_AddLedgerAndDevelopmentFunding", "20260909065721_AddInternalTransfers");
        Assert.Contains("DROP CONSTRAINT \"CK_LedgerTransactions_Operation\"", sql);
        Assert.Contains("CHECK (\"Operation\" IN ('DEVELOPMENT_FUNDING', 'INTERNAL_TRANSFER'))", sql);
        Assert.DoesNotContain("CREATE TABLE", sql);
        Assert.DoesNotContain("DROP TABLE", sql);
        Assert.DoesNotContain("UPDATE \"", sql);
        Assert.DoesNotContain("DELETE FROM", sql);
        Assert.False(context.Database.HasPendingModelChanges());
    }

    [Fact]
    public void ActivitySqlIsAdditiveIndexOnlyAndHasNoModelDrift()
    {
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseNpgsql().Options);
        var sql = context.GetService<IMigrator>().GenerateScript(
            "20260909065721_AddInternalTransfers", "20260910054031_AddActivityHistoryIndex");
        Assert.Contains($"CREATE INDEX \"{LedgerPosting.ActivityHistoryIndex}\"", sql);
        Assert.Contains("\"CustomerAccountId\", \"CreatedAtUtc\" DESC, \"LedgerTransactionId\" DESC", sql);
        Assert.DoesNotContain("CREATE TABLE", sql);
        Assert.DoesNotContain("DROP TABLE", sql);
        Assert.DoesNotContain("UPDATE \"", sql);
        Assert.DoesNotContain("DELETE FROM", sql);
        Assert.False(context.Database.HasPendingModelChanges());
    }
}

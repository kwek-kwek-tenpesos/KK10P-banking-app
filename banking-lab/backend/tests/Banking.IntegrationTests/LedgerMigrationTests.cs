using Banking.api.Migrations;
using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace Banking.IntegrationTests;

public sealed class LedgerMigrationTests
{
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
}

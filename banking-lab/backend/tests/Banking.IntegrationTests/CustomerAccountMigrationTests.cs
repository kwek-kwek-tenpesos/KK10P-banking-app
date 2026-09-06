using Banking.api.Migrations;
using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace Banking.IntegrationTests;

public sealed class CustomerAccountMigrationTests
{
    [Fact]
    public void ForwardMigrationAddsOnlyAccountTableAndOwnerIndex()
    {
        var migration = new AddCustomerAccounts();
        Assert.Equal(2, migration.UpOperations.Count);
        var table = Assert.IsType<CreateTableOperation>(migration.UpOperations[0]);
        Assert.Equal("CustomerAccounts", table.Name);
        Assert.All(table.Columns, column => Assert.False(column.IsNullable));
        var owner = Assert.Single(table.ForeignKeys);
        Assert.Equal("AspNetUsers", owner.PrincipalTable);
        Assert.Equal(ReferentialAction.Restrict, owner.OnDelete);
        var index = Assert.IsType<CreateIndexOperation>(migration.UpOperations[1]);
        Assert.True(index.IsUnique);
        Assert.Equal(["UserId"], index.Columns);
        Assert.Contains(table.CheckConstraints, c => c.Sql == "\"Currency\" = 'PHP'");
        Assert.Contains(table.CheckConstraints, c => c.Sql == "\"BalanceMinor\" = 0");
        var down = Assert.IsType<DropTableOperation>(Assert.Single(migration.DownOperations));
        Assert.Equal("CustomerAccounts", down.Name); // destructive after use: never auto-rollback
    }

    [Fact]
    public void GeneratedPostgresSqlHasConstraintsWithoutExistingTableChanges()
    {
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>().UseNpgsql().Options);
        var sql = context.GetService<IMigrator>().GenerateScript(
            "20260904152654_AddCustomerSessions", "20260906042449_AddCustomerAccounts");
        Assert.Contains("CREATE TABLE \"CustomerAccounts\"", sql);
        Assert.Contains("CREATE UNIQUE INDEX \"IX_CustomerAccounts_UserId\"", sql);
        Assert.Contains("ON DELETE RESTRICT", sql);
        Assert.DoesNotContain("ALTER TABLE", sql);
        Assert.DoesNotContain("DROP TABLE", sql);
        Assert.DoesNotContain("UPDATE \"", sql);
        Assert.False(context.Database.HasPendingModelChanges());
    }
}

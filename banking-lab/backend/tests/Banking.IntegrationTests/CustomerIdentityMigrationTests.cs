using Banking.api.Migrations;
using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations.Operations;

namespace Banking.IntegrationTests;

// Metadata/SQL-shape checks only. Actual PostgreSQL constraints need isolated DB tests.
public sealed class CustomerIdentityMigrationTests
{
    private static readonly string[] IdentityTables =
    [
        "AspNetRoles", "AspNetUsers", "AspNetRoleClaims", "AspNetUserClaims",
        "AspNetUserLogins", "AspNetUserRoles", "AspNetUserTokens"
    ];

    [Fact]
    public void Up_OnlyCreatesIdentityTablesAndTheirIndexes()
    {
        var migration = new AddCustomerIdentity();
        var tables = migration.UpOperations.OfType<CreateTableOperation>().ToArray();

        Assert.Equal(IdentityTables.Order(), tables.Select(table => table.Name).Order());
        Assert.All(migration.UpOperations, operation =>
        {
            if (operation is CreateTableOperation table)
            {
                Assert.Contains(table.Name, IdentityTables);
                Assert.All(table.ForeignKeys, key =>
                    Assert.Contains(key.PrincipalTable, IdentityTables));
            }
            else
            {
                var index = Assert.IsType<CreateIndexOperation>(operation);
                Assert.Contains(index.Table, IdentityTables);
            }
        });

        var users = Assert.Single(tables, table => table.Name == "AspNetUsers");
        Assert.Contains(users.CheckConstraints, constraint =>
            constraint.Name == "CK_AspNetUsers_NormalizedLogin"
            && constraint.Sql == "\"NormalizedUserName\" = \"NormalizedEmail\"");
        Assert.Contains(migration.UpOperations.OfType<CreateIndexOperation>(), index =>
            index.Table == "AspNetUsers" && index.IsUnique
            && index.Columns.SequenceEqual(new[] { "NormalizedEmail" }));
    }

    [Fact]
    public void Down_DropsOnlyNewIdentityTablesNotSetupProbes()
    {
        var migration = new AddCustomerIdentity();
        var drops = migration.DownOperations.Select(operation =>
            Assert.IsType<DropTableOperation>(operation));

        Assert.Equal(IdentityTables.Order(), drops.Select(table => table.Name).Order());
        // This is destructive to auth data after use; it is NOT a safe data rollback.
    }

    [Fact]
    public void Snapshot_MatchesCurrentModelWithoutConnectingToDatabase()
    {
        using var context = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql().Options);

        Assert.False(context.Database.HasPendingModelChanges());
    }
}

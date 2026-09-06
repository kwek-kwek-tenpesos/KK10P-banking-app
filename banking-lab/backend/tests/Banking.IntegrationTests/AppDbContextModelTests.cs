using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class AppDbContextModelTests
{
    [Fact]
    public void Model_MapsApplicationUserToIdentityUsersTable()
    {
        using var context = CreateContext();

        var userEntity = context.Model.FindEntityType(
            typeof(ApplicationUser));

        Assert.NotNull(userEntity);
        Assert.Equal("AspNetUsers", userEntity.GetTableName());

        var primaryKey = userEntity.FindPrimaryKey();

        Assert.NotNull(primaryKey);

        var keyProperty = Assert.Single(primaryKey.Properties);

        Assert.Equal(nameof(ApplicationUser.Id), keyProperty.Name);
        Assert.Equal(typeof(string), keyProperty.ClrType);
    }

    [Fact]
    public void Model_PreservesSetupProbeTableAndPrimaryKey()
    {
        using var context = CreateContext();

        var probeEntity = context.Model.FindEntityType(
            typeof(SetupProbe));

        Assert.NotNull(probeEntity);
        Assert.Equal("SetupProbes", probeEntity.GetTableName());

        var primaryKey = probeEntity.FindPrimaryKey();

        Assert.NotNull(primaryKey);

        var keyProperty = Assert.Single(primaryKey.Properties);

        Assert.Equal(nameof(SetupProbe.Id), keyProperty.Name);
        Assert.Equal(typeof(int), keyProperty.ClrType);
    }

    [Fact]
    public void Model_RequiresBoundedEmailAndUniqueNormalizedEmail()
    {
        using var context = CreateContext();
        var user = context.Model.FindEntityType(typeof(ApplicationUser))!;

        foreach (var propertyName in new[]
        {
            nameof(ApplicationUser.Email), nameof(ApplicationUser.NormalizedEmail),
            nameof(ApplicationUser.UserName), nameof(ApplicationUser.NormalizedUserName)
        })
        {
            var property = user.FindProperty(propertyName)!;
            Assert.False(property.IsNullable);
            Assert.Equal(ApplicationUser.MaximumEmailLength, property.GetMaxLength());
        }

        var emailIndex = Assert.Single(user.GetIndexes(), index =>
            index.Properties.Select(property => property.Name)
                .SequenceEqual(new[] { nameof(ApplicationUser.NormalizedEmail) }));
        Assert.True(emailIndex.IsUnique);
    }

    [Fact]
    public void Model_KeepsDisplayNameOptionalBoundedAndNonunique()
    {
        using var context = CreateContext();
        var user = context.Model.FindEntityType(typeof(ApplicationUser))!;
        var displayName = user.FindProperty(nameof(ApplicationUser.DisplayName))!;

        Assert.True(displayName.IsNullable);
        Assert.Equal(ApplicationUser.MaximumDisplayNameLength, displayName.GetMaxLength());
        Assert.DoesNotContain(user.GetIndexes(), index =>
            index.IsUnique && index.Properties.Contains(displayName));
        Assert.False(user.FindProperty(nameof(ApplicationUser.IsEnabled))!.IsNullable);
    }

    [Fact]
    public void Model_MapsCustomerRefreshTokenWithUniqueTokenHashAndForeignKey()
    {
        using var context = CreateContext();
        var tokenEntity = context.Model.FindEntityType(typeof(CustomerRefreshToken));

        Assert.NotNull(tokenEntity);
        Assert.Equal("CustomerRefreshTokens", tokenEntity.GetTableName());

        var primaryKey = tokenEntity.FindPrimaryKey();
        Assert.NotNull(primaryKey);
        var keyProp = Assert.Single(primaryKey.Properties);
        Assert.Equal(nameof(CustomerRefreshToken.Id), keyProp.Name);
        Assert.Equal(typeof(long), keyProp.ClrType);

        var tokenHashProp = tokenEntity.FindProperty(nameof(CustomerRefreshToken.TokenHash))!;
        Assert.False(tokenHashProp.IsNullable);
        Assert.Equal(128, tokenHashProp.GetMaxLength());

        var tokenHashIndex = Assert.Single(tokenEntity.GetIndexes(), index =>
            index.Properties.Select(p => p.Name).SequenceEqual(new[] { nameof(CustomerRefreshToken.TokenHash) }));
        Assert.True(tokenHashIndex.IsUnique);

        var userIdProp = tokenEntity.FindProperty(nameof(CustomerRefreshToken.UserId))!;
        Assert.False(userIdProp.IsNullable);

        var foreignKey = Assert.Single(tokenEntity.GetForeignKeys(), key => key.PrincipalEntityType.ClrType == typeof(ApplicationUser));
        Assert.Equal(typeof(ApplicationUser), foreignKey.PrincipalEntityType.ClrType);
        Assert.Equal(DeleteBehavior.Cascade, foreignKey.DeleteBehavior);
        var sessionKey = Assert.Single(tokenEntity.GetForeignKeys(), key => key.PrincipalEntityType.ClrType == typeof(CustomerSession));
        Assert.Equal(DeleteBehavior.Restrict, sessionKey.DeleteBehavior);
        Assert.True(tokenEntity.FindProperty(nameof(CustomerRefreshToken.SessionId))!.IsNullable);
        Assert.True(context.Model.FindEntityType(typeof(CustomerSession))!.FindProperty(nameof(CustomerSession.Version))!.IsConcurrencyToken);
    }

    [Fact]
    public void CustomerRefreshToken_StateProperties_ReflectExpirationAndRevocation()
    {
        var activeToken = new CustomerRefreshToken
        {
            UserId = "user-1",
            TokenHash = "hash-1",
            ExpiresAtUtc = DateTime.UtcNow.AddDays(1)
        };
        Assert.True(activeToken.IsActive);
        Assert.False(activeToken.IsExpired);
        Assert.False(activeToken.IsRevoked);

        var expiredToken = new CustomerRefreshToken
        {
            UserId = "user-1",
            TokenHash = "hash-2",
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(-5)
        };
        Assert.False(expiredToken.IsActive);
        Assert.True(expiredToken.IsExpired);
        Assert.False(expiredToken.IsRevoked);

        activeToken.Revoke("replacement-hash");
        Assert.False(activeToken.IsActive);
        Assert.True(activeToken.IsRevoked);
        Assert.Equal("replacement-hash", activeToken.ReplacedByTokenHash);
        Assert.NotNull(activeToken.RevokedAtUtc);
    }

    private static AppDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql()
            .Options;

        return new AppDbContext(options);
    }
}

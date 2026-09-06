using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class IdentityFoundationTests
{
    // Nonfunctional test fixture only; never saved to a database or used to log in.
    private const string TestPassword = "Fixture-Only!4826";

    [Fact]
    public void Startup_ResolvesScopedUserManagerAndEfContextWithoutDatabaseAccess()
    {
        using var factory = CreateFactory();
        using var firstScope = factory.Services.CreateScope();
        using var secondScope = factory.Services.CreateScope();

        var manager = firstScope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>();
        var context = firstScope.ServiceProvider.GetRequiredService<AppDbContext>();

        Assert.Same(manager, firstScope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>());
        Assert.NotSame(manager, secondScope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>());
        Assert.NotSame(context, secondScope.ServiceProvider
            .GetRequiredService<AppDbContext>());
        Assert.True(manager.SupportsUserPassword);
        Assert.True(manager.SupportsUserEmail);
        Assert.True(manager.SupportsUserLockout);
        Assert.Null(context.Database.GetConnectionString());
    }

    [Fact]
    public async Task ConfiguredUserManager_VerifiesHashedPasswordThroughRegisteredStore()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>();
        var store = Assert.IsAssignableFrom<IUserPasswordStore<ApplicationUser>>(
            scope.ServiceProvider.GetRequiredService<IUserStore<ApplicationUser>>());
        var user = new ApplicationUser { UserName = "fixture-only" };

        var hash = manager.PasswordHasher.HashPassword(user, TestPassword);
        // SetPasswordHashAsync changes this transient entity; it does not save it.
        await store.SetPasswordHashAsync(user, hash, CancellationToken.None);

        // Boolean checks keep hash material out of assertion failure output.
        Assert.False(string.IsNullOrEmpty(user.PasswordHash));
        Assert.False(user.PasswordHash == TestPassword);
        Assert.True(await manager.CheckPasswordAsync(user, TestPassword));
        Assert.False(await manager.CheckPasswordAsync(user, "Different-Fixture!4826"));
    }

    [Theory]
    [InlineData("", false)]
    [InlineData("abc", false)]
    [InlineData(TestPassword, true)]
    public async Task ConfiguredPasswordValidators_CheckTestInput(
        string password, bool expectedSuccess)
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser { UserName = "fixture-only" };

        Assert.NotEmpty(manager.PasswordValidators);
        var results = new List<IdentityResult>();
        foreach (var validator in manager.PasswordValidators)
        {
            results.Add(await validator.ValidateAsync(manager, user, password));
        }

        Assert.Equal(expectedSuccess, results.All(result => result.Succeeded));
    }

    private static WebApplicationFactory<Program> CreateFactory()
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Testing");
                builder.UseTestAuthentication();
                builder.ConfigureAppConfiguration((_, configuration) =>
                    configuration.AddInMemoryCollection(
                        new Dictionary<string, string?>
                        {
                            // No usable connection, even if local config contains one.
                            ["ConnectionStrings:DefaultConnection"] = null
                        }));
            });
    }
}

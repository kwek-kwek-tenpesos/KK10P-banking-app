using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class CustomerIdentityTests
{
    [Theory]
    [InlineData(null, true)]
    [InlineData("Demo Chris", true)]
    [InlineData("Demo Gio", true)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    [InlineData(" Demo ", false)]
    [InlineData("Demo\nName", false)]
    public async Task DisplayName_IsOptionalButMustBeCanonicalWhenSupplied(
        string? displayName, bool expectedSuccess)
    {
        var result = await ValidateAsync("customer@example.test", displayName);

        Assert.Equal(expectedSuccess, result.Succeeded);
        if (!expectedSuccess)
        {
            Assert.Contains(result.Errors, error => error.Code == "InvalidCustomerDisplayName");
        }
    }

    [Theory]
    [InlineData(1, true)]
    [InlineData(60, true)]
    [InlineData(61, false)]
    public async Task DisplayName_LimitCountsUnicodeCodePoints(int count, bool expectedSuccess)
    {
        var name = string.Concat(Enumerable.Repeat("\U0001F986", count));

        var result = await ValidateAsync("customer@example.test", name);

        Assert.Equal(expectedSuccess, result.Succeeded);
    }

    [Fact]
    public async Task DisplayName_RejectsMalformedUnicode()
    {
        var result = await ValidateAsync("customer@example.test", "Demo\uD800");

        Assert.Contains(result.Errors, error => error.Code == "InvalidCustomerDisplayName");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-an-email")]
    [InlineData(" customer@example.test ")]
    [InlineData("Name <customer@example.test>")]
    [InlineData("customer@example.test\r\n")]
    [InlineData("one@example.test,two@example.test")]
    public async Task Email_RejectsMissingMalformedOrNoncanonicalInput(string? email)
    {
        var result = await ValidateAsync(email, null);

        Assert.Contains(result.Errors, error => error.Code == "InvalidCustomerEmail");
        Assert.DoesNotContain(result.Errors, error =>
            !string.IsNullOrEmpty(email) && error.Description.Contains(email, StringComparison.Ordinal));
    }

    [Fact]
    public async Task Email_RejectsOverlongAndMalformedUnicodeInput()
    {
        var longEmail = new string('a', 255) + "@example.test";
        var tooLong = await ValidateAsync(longEmail, null);
        var malformed = await ValidateAsync("a\uD800@example.test", null);

        Assert.Contains(tooLong.Errors, error => error.Code == "InvalidCustomerEmail");
        Assert.Contains(malformed.Errors, error => error.Code == "InvalidCustomerEmail");
    }

    [Fact]
    public async Task Email_UsesIdentityNormalizationWithoutRemovingPlusOrDots()
    {
        var result = await ValidateAsync("Demo.Customer+two@Example.Test", "Demo");

        Assert.True(result.Succeeded);
    }

    [Fact]
    public async Task LoginName_CannotBeAnUnrelatedDisplayName()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var validator = Assert.Single(manager.UserValidators.OfType<CustomerUserValidator>());
        var user = new ApplicationUser
        {
            Email = "customer@example.test",
            UserName = "Demo Chris",
            DisplayName = "Demo Chris"
        };

        var result = await validator.ValidateAsync(manager, user);

        Assert.Contains(result.Errors, error => error.Code == "InvalidCustomerLoginName");
    }

    [Fact]
    public void Startup_RequiresUniqueEmailAndKeepsFrameworkUniquenessValidator()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

        Assert.True(manager.Options.User.RequireUniqueEmail);
        Assert.Contains(manager.UserValidators, validator => validator is UserValidator<ApplicationUser>);
        Assert.Single(manager.UserValidators.OfType<CustomerUserValidator>());
        Assert.Null(scope.ServiceProvider.GetService<RoleManager<IdentityRole>>());
    }

    [Fact]
    public void NewTestUser_IsEnabledButNotEmailConfirmed()
    {
        var user = new ApplicationUser();

        Assert.True(user.IsEnabled);
        Assert.False(user.EmailConfirmed);
        Assert.Null(user.DisplayName);
    }

    private static async Task<IdentityResult> ValidateAsync(string? email, string? displayName)
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var validator = Assert.Single(manager.UserValidators.OfType<CustomerUserValidator>());
        // Deliberately malformed inputs must reach the validator, not the normalizer.
        string? loginName;
        try
        {
            loginName = manager.NormalizeEmail(email);
        }
        catch (ArgumentException)
        {
            loginName = null;
        }

        return await validator.ValidateAsync(manager, new ApplicationUser
        {
            Email = email,
            UserName = loginName,
            DisplayName = displayName
        });
    }

    private static WebApplicationFactory<Program> CreateFactory() =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.UseTestAuthentication();
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["ConnectionStrings:DefaultConnection"] = null
                }));
        });
}

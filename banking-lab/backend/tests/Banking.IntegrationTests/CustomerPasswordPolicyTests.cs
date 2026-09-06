using System.Text;
using System.Text.Json;
using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class CustomerPasswordPolicyTests
{
    [Fact]
    public void Startup_UsesCustomPolicyWithoutCompositionRequirements()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

        Assert.Contains(manager.PasswordValidators,
            validator => validator is PasswordValidator<ApplicationUser>);
        Assert.Single(manager.PasswordValidators.OfType<CustomerPasswordValidator>());
        Assert.NotNull(scope.ServiceProvider.GetRequiredService<CustomerPasswordPolicy>());
        Assert.False(manager.Options.Password.RequireDigit);
        Assert.False(manager.Options.Password.RequireLowercase);
        Assert.False(manager.Options.Password.RequireNonAlphanumeric);
        Assert.False(manager.Options.Password.RequireUppercase);
    }

    [Theory]
    [InlineData(14, "PasswordTooShort")]
    [InlineData(15, null)]
    [InlineData(128, null)]
    [InlineData(129, "PasswordTooLong")]
    public void Prepare_CountsUnicodeCodePoints(int count, string? expectedError)
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();
        var password = string.Concat(Enumerable.Repeat("\U0001F986", count));

        var result = policy.PrepareForCreation(password);

        Assert.Equal(expectedError is null, result.Succeeded);
        Assert.Equal(expectedError, result.Error?.Code);
    }

    [Fact]
    public void Prepare_BoundsInputBeforeUnicodeNormalization()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();

        var result = policy.PrepareForCreation(new string('a', 513));

        Assert.False(result.Succeeded);
        Assert.Equal("PasswordTooLong", result.Error?.Code);
    }

    [Theory]
    [InlineData(14, false)]
    [InlineData(15, true)]
    public void CreationLength_IsEvaluatedAfterCanonicalComposition(
        int count, bool expectedSuccess)
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();
        var decomposed = string.Concat(Enumerable.Repeat("e\u0301", count));

        var result = policy.PrepareForCreation(decomposed);

        Assert.Equal(expectedSuccess, result.Succeeded);
    }

    [Fact]
    public void Preparation_RejectsNullWithoutReturningCredentialMaterial()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();

        var result = policy.PrepareForVerification(null);

        Assert.False(result.Succeeded);
        Assert.Equal("InvalidPassword", result.Error?.Code);
        Assert.Null(result.NormalizedPassword);
    }

    [Fact]
    public void Prepare_NormalizesToNfcWithoutTrimmingOrChangingCase()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();
        // Nonfunctional test fixture: each accented character starts decomposed.
        const string rawPassword = "  Cafe\u0301 Mixed CASE  ";

        var result = policy.PrepareForCreation(rawPassword);

        Assert.True(result.Succeeded);
        Assert.Equal("  Caf\u00e9 Mixed CASE  ", result.NormalizedPassword);
        Assert.True(result.NormalizedPassword!
            .IsNormalized(NormalizationForm.FormC));
    }

    [Fact]
    public void Prepare_RejectsMalformedUnicodeWithSafeError()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();
        const string malformedFixture = "Fixture-value-\uD800";

        var result = policy.PrepareForCreation(malformedFixture);

        Assert.False(result.Succeeded);
        Assert.Equal("InvalidPassword", result.Error?.Code);
        Assert.DoesNotContain(malformedFixture, result.Error?.Description);
        Assert.Null(result.NormalizedPassword);
    }

    [Theory]
    [InlineData("KK10PBANKPASSWORD")]
    [InlineData("PasswordPassword")]
    [InlineData("123456789012345")]
    public void Prepare_BlocksExactInitialValuesIgnoringAsciiCase(string password)
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();

        var result = policy.PrepareForCreation(password);

        Assert.False(result.Succeeded);
        Assert.Equal("PasswordBlocked", result.Error?.Code);
        Assert.DoesNotContain(password, result.Error?.Description);
    }

    [Fact]
    public void Prepare_DoesNotApplyBlocklistAsSubstringRule()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();

        var result = policy.PrepareForCreation("my-kk10pbankpassword-is-different");

        Assert.True(result.Succeeded);
    }

    [Fact]
    public async Task IdentityValidator_RequiresPreparedNfcValue()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var policy = scope.ServiceProvider.GetRequiredService<CustomerPasswordPolicy>();
        var validator = Assert.Single(
            manager.PasswordValidators.OfType<CustomerPasswordValidator>());
        const string rawPassword = "Cafe\u0301 password phrase";
        var prepared = policy.PrepareForCreation(rawPassword);

        Assert.True(prepared.Succeeded);
        var rawResult = await validator.ValidateAsync(
            manager, new ApplicationUser(), rawPassword);
        var preparedResult = await validator.ValidateAsync(
            manager, new ApplicationUser(), prepared.NormalizedPassword);

        Assert.Contains(rawResult.Errors,
            error => error.Code == "PasswordRequiresPreparation");
        Assert.True(preparedResult.Succeeded);
    }

    [Fact]
    public void IdentityHasher_StoresAndVerifiesOnlyThePreparedValue()
    {
        using var factory = CreateFactory();
        using var scope = factory.Services.CreateScope();
        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var policy = scope.ServiceProvider.GetRequiredService<CustomerPasswordPolicy>();
        var user = new ApplicationUser();
        const string rawPassword = "Cafe\u0301 password phrase";
        var prepared = policy.PrepareForCreation(rawPassword);
        var verification = policy.PrepareForVerification(rawPassword);

        Assert.True(prepared.Succeeded);
        Assert.True(verification.Succeeded);
        var hash = manager.PasswordHasher.HashPassword(
            user, prepared.NormalizedPassword!);

        Assert.False(string.Equals(prepared.NormalizedPassword, hash, StringComparison.Ordinal));
        Assert.NotEqual(PasswordVerificationResult.Failed,
            manager.PasswordHasher.VerifyHashedPassword(
                user, hash, verification.NormalizedPassword!));
        Assert.Equal(PasswordVerificationResult.Failed,
            manager.PasswordHasher.VerifyHashedPassword(
                user, hash, rawPassword));
    }

    [Fact]
    public void VerificationPreparation_DoesNotReapplyCreationBlocklistOrMinimumLength()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();

        Assert.True(policy.PrepareForVerification("passwordpassword").Succeeded);
        Assert.True(policy.PrepareForVerification("short-fixture").Succeeded);
        Assert.False(policy.PrepareForCreation("passwordpassword").Succeeded);
        Assert.False(policy.PrepareForCreation("short-fixture").Succeeded);
    }

    [Fact]
    public void PreparationResult_RedactsCredentialFromTextAndDefaultJson()
    {
        using var factory = CreateFactory();
        var policy = factory.Services.GetRequiredService<CustomerPasswordPolicy>();
        const string fixture = "only-a-test-passphrase";
        var result = policy.PrepareForCreation(fixture);

        Assert.True(result.Succeeded);
        Assert.DoesNotContain(fixture, result.ToString());
        Assert.DoesNotContain(fixture, JsonSerializer.Serialize(result));
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

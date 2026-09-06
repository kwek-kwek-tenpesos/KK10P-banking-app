using System.Net;
using System.Text.Json;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.IntegrationTests;

public sealed class CustomerRegistrationTests
{
    // Nonfunctional fixtures only, confined to the test host's transient store.
    private const string PasswordFixture = "  Cafe\u0301 learning phrase  ";
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task Registration_CreatesCanonicalUnconfirmedCustomerWithPreparedHash()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>();
        var result = await service.RegisterAsync(Request(" Demo.Customer+one@Example.Test ", " Demo Chris "));

        Assert.Equal(CustomerRegistrationOutcome.Accepted, result.Outcome);
        var user = Assert.Single(host.Store.Users);
        Assert.Equal("Demo.Customer+one@Example.Test", user.Email);
        Assert.Equal("DEMO.CUSTOMER+ONE@EXAMPLE.TEST", user.UserName);
        Assert.Equal(user.UserName, user.NormalizedUserName);
        Assert.Equal(user.UserName, user.NormalizedEmail);
        Assert.Equal("Demo Chris", user.DisplayName);
        Assert.False(user.EmailConfirmed);
        Assert.True(user.IsEnabled);
        Assert.True(user.LockoutEnabled);
        Assert.False(string.IsNullOrEmpty(user.SecurityStamp));
        Assert.Equal(user.Id, Assert.Single(host.Delivery.RequestedUserIds));

        var manager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var prepared = scope.ServiceProvider.GetRequiredService<CustomerPasswordPolicy>()
            .PrepareForVerification(PasswordFixture);
        Assert.False(user.PasswordHash == PasswordFixture);
        Assert.NotEqual(PasswordVerificationResult.Failed,
            manager.PasswordHasher.VerifyHashedPassword(user, user.PasswordHash!, prepared.NormalizedPassword!));
        Assert.Equal(PasswordVerificationResult.Failed,
            manager.PasswordHasher.VerifyHashedPassword(user, user.PasswordHash!, PasswordFixture));

        var serialized = JsonSerializer.Serialize(result, WebJson);
        Assert.DoesNotContain(user.Email!, serialized);
        Assert.DoesNotContain(user.Id, serialized);
        Assert.DoesNotContain("password", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("token", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.Empty(host.Log.Messages);
    }

    [Fact]
    public async Task Registration_AllowsAnOmittedDisplayName()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(CustomerRegistrationOutcome.Accepted, result.Outcome);
        Assert.Null(Assert.Single(host.Store.Users).DisplayName);
    }

    [Theory]
    [InlineData(null, PasswordFixture, null, "email")]
    [InlineData("not-an-email", PasswordFixture, null, "email")]
    [InlineData("customer@example.test", null, null, "password")]
    [InlineData("customer@example.test", "short", null, "password")]
    [InlineData("customer@example.test", "passwordpassword", null, "password")]
    [InlineData("customer@example.test", PasswordFixture, "   ", "displayName")]
    [InlineData("customer@example.test", PasswordFixture, "Demo\nName", "displayName")]
    public async Task InvalidInput_FailsBeforeAnyStoreOrDeliveryCall(
        string? email, string? password, string? name, string field)
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(new CustomerRegistrationRequest { Email = email, Password = password, DisplayName = name });

        Assert.Equal(CustomerRegistrationOutcome.Invalid, result.Outcome);
        Assert.Contains(field, result.Errors.Keys);
        Assert.Equal(0, host.Store.Reads);
        Assert.Equal(0, host.Store.CreateCalls);
        Assert.Empty(host.Delivery.RequestedUserIds);
    }

    [Fact]
    public async Task InvalidUnicodeAndOversizedFields_AreSafeValidationFailures()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>();
        var malformed = await service.RegisterAsync(Request("a\uD800@example.test", "Demo"));
        var oversized = await service.RegisterAsync(Request(new string('a', 255) + "@example.test", new string('b', 61)));

        Assert.Equal(CustomerRegistrationOutcome.Invalid, malformed.Outcome);
        Assert.Contains("email", malformed.Errors.Keys);
        Assert.Contains("email", oversized.Errors.Keys);
        Assert.Contains("displayName", oversized.Errors.Keys);
        Assert.Equal(0, host.Store.Reads);
    }

    [Theory]
    [InlineData("roles")]
    [InlineData("userName")]
    [InlineData("emailConfirmed")]
    [InlineData("isEnabled")]
    [InlineData("address")]
    public void JsonContract_RejectsUnapprovedFields(string field)
    {
        var json = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["email"] = "customer@example.test",
            ["password"] = PasswordFixture,
            [field] = "untrusted-fixture"
        });

        Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CustomerRegistrationRequest>(json, WebJson));
    }

    [Fact]
    public void JsonContract_AcceptsApprovedShapeAndRedactsToString()
    {
        var request = JsonSerializer.Deserialize<CustomerRegistrationRequest>(
            JsonSerializer.Serialize(Request("customer@example.test", "Demo Gio"), WebJson), WebJson)!;

        Assert.Equal("customer@example.test", request.Email);
        Assert.Equal(PasswordFixture, request.Password);
        Assert.DoesNotContain(PasswordFixture, request.ToString());
        Assert.DoesNotContain(request.Email!, request.ToString());
    }

    [Theory]
    [InlineData("email")]
    [InlineData("password")]
    [InlineData("displayName")]
    public void JsonContract_RejectsNonStringFields(string field)
    {
        var json = JsonSerializer.Serialize(new Dictionary<string, object?> { [field] = 42 });

        Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CustomerRegistrationRequest>(json, WebJson));
    }

    [Fact]
    public async Task SeparateCustomers_CanShareADisplayName()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>();

        var first = await service.RegisterAsync(Request("one@example.test", "Demo Customer"));
        var second = await service.RegisterAsync(Request("two@example.test", "Demo Customer"));

        Assert.Equal(CustomerRegistrationOutcome.Accepted, first.Outcome);
        Assert.Equal(CustomerRegistrationOutcome.Accepted, second.Outcome);
        Assert.Equal(2, host.Store.Users.Count);
        Assert.Equal(2, host.Store.Users.Select(user => user.Id).Distinct().Count());
        Assert.Equal(2, host.Delivery.RequestedUserIds.Count);
    }

    [Fact]
    public async Task DuplicateCaseVariant_UsesSameResultWithoutOverwritingOrResending()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>();
        var first = await service.RegisterAsync(Request("customer@example.test", "Demo Chris"));
        var original = Assert.Single(host.Store.Users);
        var originalHash = original.PasswordHash;
        var duplicate = await service.RegisterAsync(new CustomerRegistrationRequest
        {
            Email = "CUSTOMER@EXAMPLE.TEST",
            Password = "different fixture phrase",
            DisplayName = "Replacement"
        });

        Assert.Equal(JsonSerializer.Serialize(first), JsonSerializer.Serialize(duplicate));
        Assert.Single(host.Store.Users);
        Assert.Equal(1, host.Store.CreateCalls);
        Assert.Single(host.Delivery.RequestedUserIds);
        Assert.Equal("Demo Chris", original.DisplayName);
        Assert.True(original.PasswordHash == originalHash);
        Assert.False(original.EmailConfirmed);
    }

    [Fact]
    public async Task UnconfiguredDelivery_DefaultRuntimePreventsDatabaseAccess()
    {
        using var host = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Testing");
            builder.UseTestAuthentication();
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(
                new Dictionary<string, string?> { ["ConnectionStrings:DefaultConnection"] = null }));
        });
        using var scope = host.Services.CreateScope();
        Assert.False(scope.ServiceProvider.GetRequiredService<ICustomerVerificationDelivery>().IsConfigured);
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(CustomerRegistrationOutcome.Unavailable, result.Outcome);
        Assert.Empty(scope.ServiceProvider.GetRequiredService<AppDbContext>().ChangeTracker.Entries());
    }

    [Fact]
    public async Task DeliveryFailure_LeavesCustomerUnconfirmedAndReturnsGenericAcceptance()
    {
        using var host = new RegistrationTestHost();
        host.Delivery.Succeeds = false;
        using var scope = host.Services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(CustomerRegistrationOutcome.Accepted, result.Outcome);
        Assert.False(Assert.Single(host.Store.Users).EmailConfirmed);
        Assert.Equal("Customer registration verification delivery failed.", Assert.Single(host.Log.Messages));
        Assert.Empty(host.Log.Exceptions);
    }

    [Theory]
    [InlineData("AspNetUsers", "EmailIndex", CustomerRegistrationOutcome.Accepted)]
    [InlineData("AspNetUsers", "UserNameIndex", CustomerRegistrationOutcome.Accepted)]
    [InlineData("AspNetUsers", "OtherIndex", CustomerRegistrationOutcome.Unavailable)]
    [InlineData("OtherTable", "EmailIndex", CustomerRegistrationOutcome.Unavailable)]
    public async Task SimulatedUniqueViolation_OnlyIdentityCollisionsBecomeGenericAcceptance(
        string table, string constraint, CustomerRegistrationOutcome expected)
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        var database = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        host.Store.BeforeCreate = user => database.Add(user);
        host.Store.CreateFailure = new DbUpdateException("Private fixture detail",
            new PostgresException("Private fixture detail", "ERROR", "ERROR", PostgresErrorCodes.UniqueViolation,
                tableName: table, constraintName: constraint));

        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(expected, result.Outcome);
        Assert.Empty(database.ChangeTracker.Entries());
        Assert.Empty(host.Delivery.RequestedUserIds);
        Assert.DoesNotContain("Private fixture detail", JsonSerializer.Serialize(result));
        Assert.DoesNotContain(host.Log.Messages, message => message.Contains("Private fixture detail"));
        Assert.Empty(host.Log.Exceptions);
    }

    [Fact]
    public async Task UnexpectedIdentityError_DoesNotExposeItsDescription()
    {
        using var host = new RegistrationTestHost();
        host.Store.CreateResult = IdentityResult.Failed(new IdentityError
        {
            Code = "UnexpectedStoreFailure",
            Description = "Private fixture identifier"
        });
        using var scope = host.Services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(CustomerRegistrationOutcome.Unavailable, result.Outcome);
        Assert.DoesNotContain("Private fixture identifier", JsonSerializer.Serialize(result));
        Assert.Empty(host.Delivery.RequestedUserIds);
    }

    [Fact]
    public async Task DatabaseReadFailure_ReturnsUnavailableWithoutExposingProviderDetails()
    {
        using var host = new RegistrationTestHost();
        host.Store.LookupFailure = new NpgsqlException("Private connection fixture detail");
        using var scope = host.Services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
            .RegisterAsync(Request("customer@example.test", null));

        Assert.Equal(CustomerRegistrationOutcome.Unavailable, result.Outcome);
        Assert.Equal(0, host.Store.CreateCalls);
        Assert.Empty(host.Delivery.RequestedUserIds);
        Assert.DoesNotContain("Private connection fixture detail", JsonSerializer.Serialize(result));
        Assert.Equal("Customer registration persistence failed.", Assert.Single(host.Log.Messages));
        Assert.Empty(host.Log.Exceptions);
    }

    [Fact]
    public async Task CancelledRequest_DoesNotCreateOrSend()
    {
        using var host = new RegistrationTestHost();
        using var scope = host.Services.CreateScope();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            scope.ServiceProvider.GetRequiredService<CustomerRegistrationService>()
                .RegisterAsync(Request("customer@example.test", null), new CancellationToken(true)));

        Assert.Equal(0, host.Store.CreateCalls);
        Assert.Empty(host.Delivery.RequestedUserIds);
    }

    [Fact]
    public async Task RegistrationEndpoint_WhenNullBodyProvided_ReturnsBadRequest()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        using var response = await client.PostAsync("/api/v1/auth/register", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(host.Store.Users);
    }

    private static CustomerRegistrationRequest Request(string? email, string? displayName) => new()
    {
        Email = email,
        Password = PasswordFixture,
        DisplayName = displayName
    };
}

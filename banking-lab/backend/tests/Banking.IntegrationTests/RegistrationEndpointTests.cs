using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Banking.Api.Features.Authentication;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class RegistrationEndpointTests
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task PostRegister_WithValidData_Returns202Accepted_AndCreatesCustomer()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "customer.one@example.test",
            password = "Correct Horse Battery Staple!",
            displayName = "Chris Test"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var body = document.RootElement;

        Assert.Equal("If registration can proceed, check your email for the next step.",
            body.GetProperty("message").GetString());

        var user = Assert.Single(host.Store.Users);
        Assert.Equal("customer.one@example.test", user.Email);
        Assert.Equal("Chris Test", user.DisplayName);
    }

    [Fact]
    public async Task PostRegister_WithInvalidEmail_Returns400BadRequest_WithValidationProblemDetails()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "not-a-valid-email",
            password = "Correct Horse Battery Staple!",
            displayName = "Invalid Email User"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var body = document.RootElement;

        Assert.True(body.TryGetProperty("errors", out var errors));
        Assert.True(errors.TryGetProperty("email", out _));
        Assert.Empty(host.Store.Users);
    }

    [Fact]
    public async Task PostRegister_WithWeakPassword_Returns400BadRequest_WithValidationProblemDetails()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "user@example.test",
            password = "password", // on initial blocklist
            displayName = "Weak Password User"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var body = document.RootElement;

        Assert.True(body.TryGetProperty("errors", out var errors));
        Assert.True(errors.TryGetProperty("password", out _));
        Assert.Empty(host.Store.Users);
    }

    [Fact]
    public async Task PostRegister_WithDuplicateEmail_Returns202Accepted_WithoutRevealingAccountExistence()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "existing.customer@example.test",
            password = "Correct Horse Battery Staple!",
            displayName = "Existing Customer"
        };

        // First registration succeeds
        using var firstResponse = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);
        Assert.Equal(HttpStatusCode.Accepted, firstResponse.StatusCode);
        Assert.Single(host.Store.Users);

        // Second registration with identical email returns 202 Accepted (anti-enumeration)
        using var secondResponse = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);
        Assert.Equal(HttpStatusCode.Accepted, secondResponse.StatusCode);

        var json = await secondResponse.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var body = document.RootElement;

        Assert.Equal("If registration can proceed, check your email for the next step.",
            body.GetProperty("message").GetString());
        // No duplicate user record added
        Assert.Single(host.Store.Users);
    }

    [Fact]
    public async Task PostRegister_WhenDeliveryUnconfigured_Returns503ServiceUnavailable()
    {
        using var host = new RegistrationTestHost();
        host.Delivery.IsConfigured = false;
        using var client = host.CreateClient();

        var payload = new
        {
            email = "valid.user@example.test",
            password = "Correct Horse Battery Staple!",
            displayName = "Delivery Test"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Empty(host.Store.Users);
    }

    [Fact]
    public async Task PostRegister_WithUnmappedExtraProperties_Returns400BadRequest()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        // Extra property not in CustomerRegistrationRequest schema
        var payload = new
        {
            email = "valid.user@example.test",
            password = "Correct Horse Battery Staple!",
            displayName = "Extra Property Test",
            isAdmin = true
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", payload, WebJson);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(host.Store.Users);
    }
}

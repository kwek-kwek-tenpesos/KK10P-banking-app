using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class SystemInfoEndpointTests
{
    [Fact]
    public async Task GetSystemInfo_WithoutLogin_ReturnsExpectedResponse()
    {
        // Arrange: start the real API inside a test host.
        using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Testing");
                builder.UseTestAuthentication();
            });

        using var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions
            {
                BaseAddress = new Uri("https://localhost"),
                AllowAutoRedirect = false
            });

        // Act: request the endpoint without authentication.
        using var response = await client.GetAsync("/api/v1/system/info");

        // Assert: check the status and JSON response.
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(
            "application/json",
            response.Content.Headers.ContentType?.MediaType);

        var json = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var body = document.RootElement;

        Assert.Equal("Banking API", body.GetProperty("name").GetString());
        Assert.Equal("v1.0.0", body.GetProperty("version").GetString());
        Assert.Equal("Testing", body.GetProperty("environment").GetString());
    }
}

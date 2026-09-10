using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class OpenApiEndpointTests
{
    [Fact]
    public async Task GetOpenApiDocument_Returns200Ok_AndDefinesCurrentCoreRoutes()
    {
        using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Testing");
                builder.UseTestAuthentication();
            });

        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/openapi/v1.json");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);

        var json = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;

        Assert.True(root.TryGetProperty("paths", out var paths));
        Assert.True(paths.TryGetProperty("/api/v1/system/info", out _));
        Assert.True(paths.TryGetProperty("/api/v1/client/compatibility", out _));
        Assert.True(paths.TryGetProperty("/api/v1/auth/register", out _));
        Assert.True(paths.TryGetProperty("/api/v1/auth/login", out _));
        Assert.True(paths.TryGetProperty("/api/v1/auth/refresh", out _));
        Assert.True(paths.TryGetProperty("/api/v1/auth/logout", out _));
        Assert.True(paths.TryGetProperty("/api/v1/development/funding/me", out _));
        Assert.True(paths.TryGetProperty("/api/v1/transfers/internal", out _));
    }

    [Fact]
    public async Task ResponseHeaders_IncludeRecommendedSecurityHeaders()
    {
        using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Testing");
                builder.UseTestAuthentication();
            });

        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/v1/system/info");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        Assert.True(response.Headers.TryGetValues("X-Content-Type-Options", out var nosniff));
        Assert.Equal("nosniff", Assert.Single(nosniff));

        Assert.True(response.Headers.TryGetValues("X-Frame-Options", out var frameOptions));
        Assert.Equal("DENY", Assert.Single(frameOptions));

        Assert.True(response.Headers.TryGetValues("Referrer-Policy", out var referrerPolicy));
        Assert.Equal("strict-origin-when-cross-origin", Assert.Single(referrerPolicy));

        Assert.True(response.Headers.TryGetValues("Cross-Origin-Resource-Policy", out var resourcePolicy));
        Assert.Equal("same-site", Assert.Single(resourcePolicy));
    }

    [Fact]
    public async Task HttpsProductionResponse_IncludesHsts()
    {
        using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Production");
                builder.UseTestAuthentication();
            });

        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://banking.test")
        });

        using var response = await client.GetAsync("/api/v1/system/info");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.TryGetValues("Strict-Transport-Security", out var hsts));
        Assert.Equal("max-age=31536000", Assert.Single(hsts));
    }
}

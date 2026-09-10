using System.Net;
using System.Text;
using System.Text.Json;
using Banking.Api.Features.ClientCompatibility;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

namespace Banking.IntegrationTests;

public sealed class ClientCompatibilityTests
{
    [Theory]
    [InlineData("ANDROID", "2", ClientMetadataParseOutcome.Valid)]
    [InlineData("ANDROID", "999999999", ClientMetadataParseOutcome.Valid)]
    [InlineData(null, null, ClientMetadataParseOutcome.Missing)]
    [InlineData("android", "2", ClientMetadataParseOutcome.Invalid)]
    [InlineData(" ANDROID", "2", ClientMetadataParseOutcome.Invalid)]
    [InlineData("ANDROID", "0", ClientMetadataParseOutcome.Invalid)]
    [InlineData("ANDROID", "+2", ClientMetadataParseOutcome.Invalid)]
    [InlineData("ANDROID", "02", ClientMetadataParseOutcome.Invalid)]
    [InlineData("ANDROID", "1000000000", ClientMetadataParseOutcome.Invalid)]
    public void Parser_AcceptsOnlyCanonicalSingletonMetadata(
        string? platform, string? build, ClientMetadataParseOutcome expected)
    {
        var headers = new HeaderDictionary();
        if (platform is not null) headers.Append(ClientMetadataParser.PlatformHeader, platform);
        if (build is not null) headers.Append(ClientMetadataParser.BuildHeader, build);

        Assert.Equal(expected, ClientMetadataParser.Parse(headers).Outcome);
    }

    [Fact]
    public void Parser_RejectsPartialAndDuplicateMetadata()
    {
        var partial = new HeaderDictionary
        {
            [ClientMetadataParser.PlatformHeader] = "ANDROID"
        };
        var duplicate = new HeaderDictionary
        {
            [ClientMetadataParser.PlatformHeader] = new[] { "ANDROID", "ANDROID" },
            [ClientMetadataParser.BuildHeader] = "2"
        };

        Assert.Equal(ClientMetadataParseOutcome.Invalid, ClientMetadataParser.Parse(partial).Outcome);
        Assert.Equal(ClientMetadataParseOutcome.Invalid, ClientMetadataParser.Parse(duplicate).Outcome);
    }

    [Fact]
    public void OptionsValidator_RequiresTrustedUpdateUriOnlyWhenEnforcementIsEnabled()
    {
        var validator = new ClientCompatibilityOptionsValidator();

        Assert.True(validator.Validate(null, new ClientCompatibilityOptions
        {
            EnforcementEnabled = false,
            MinimumAndroidBuild = 2,
            UpdateUri = ""
        }).Succeeded);
        Assert.False(validator.Validate(null, new ClientCompatibilityOptions
        {
            EnforcementEnabled = true,
            MinimumAndroidBuild = 2,
            UpdateUri = "http://downloads.example.test/app"
        }).Succeeded);
        Assert.True(validator.Validate(null, new ClientCompatibilityOptions
        {
            EnforcementEnabled = true,
            MinimumAndroidBuild = 2,
            UpdateUri = "https://downloads.example.test/app"
        }).Succeeded);
    }

    [Fact]
    public async Task CompatibilityEndpoint_WithSupportedBuild_ReturnsStrictNoStoreContract()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: false);
        using var client = host.CreateClient();
        using var request = CreateRequest(HttpMethod.Get, ClientCompatibilityEndpoints.Route, build: "2");

        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("ANDROID", json.RootElement.GetProperty("platform").GetString());
        Assert.Equal(2, json.RootElement.GetProperty("currentBuild").GetInt32());
        Assert.Equal(2, json.RootElement.GetProperty("minimumBuild").GetInt32());
        Assert.False(json.RootElement.GetProperty("updateRequired").GetBoolean());
        Assert.Equal(JsonValueKind.Null, json.RootElement.GetProperty("updateUri").ValueKind);
    }

    [Fact]
    public async Task DisabledEnforcement_AllowsLegacyRequestsButCompatibilityStillRequiresMetadata()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: false);
        using var client = host.CreateClient();

        using var governed = await client.GetAsync("/api/v1/auth/me");
        using var compatibility = await client.GetAsync(ClientCompatibilityEndpoints.Route);

        Assert.Equal(HttpStatusCode.Unauthorized, governed.StatusCode);
        await AssertProblem(compatibility, HttpStatusCode.BadRequest, "invalid_client_metadata");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("1")]
    public async Task EnabledEnforcement_BlocksMissingOrOldBuildBeforeAuthentication(string? build)
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: true);
        using var client = host.CreateClient();
        using var request = CreateRequest(HttpMethod.Get, "/api/v1/auth/me", build);

        using var response = await client.SendAsync(request);

        await AssertProblem(response, (HttpStatusCode)426, "client_upgrade_required");
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(2, json.RootElement.GetProperty("minimumBuild").GetInt32());
        Assert.Equal(
            "https://downloads.example.test/kk10p",
            json.RootElement.GetProperty("updateUri").GetString());
    }

    [Fact]
    public async Task EnabledEnforcement_AllowsMinimumAndFutureBuildsToReachAuthentication()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: true);
        using var client = host.CreateClient();

        using var minimum = await client.SendAsync(CreateRequest(HttpMethod.Get, "/api/v1/auth/me", "2"));
        using var future = await client.SendAsync(CreateRequest(HttpMethod.Get, "/api/v1/auth/me", "999999999"));

        Assert.Equal(HttpStatusCode.Unauthorized, minimum.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, future.StatusCode);
    }

    [Fact]
    public async Task InvalidMetadata_IsRejectedBeforeGovernedEndpointHandling()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: false);
        using var client = host.CreateClient();
        using var request = CreateRequest(HttpMethod.Get, "/api/v1/auth/me", "02");

        using var response = await client.SendAsync(request);

        await AssertProblem(response, HttpStatusCode.BadRequest, "invalid_client_metadata");
    }

    [Theory]
    [InlineData("POST", "/api/v1/auth/register")]
    [InlineData("POST", "/api/v1/auth/verify-email")]
    [InlineData("GET", "/api/v1/accounts/me")]
    [InlineData("POST", "/api/v1/development/funding/me")]
    [InlineData("POST", "/api/v1/transfers/internal")]
    [InlineData("GET", "/api/v1/accounts/me/transactions")]
    public async Task EnabledEnforcement_BlocksOldBuildAcrossMobileRouteFamiliesBeforeHandlers(
        string method, string path)
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: true);
        using var client = host.CreateClient();
        using var request = CreateRequest(new HttpMethod(method), path, "1");

        using var response = await client.SendAsync(request);

        await AssertProblem(response, (HttpStatusCode)426, "client_upgrade_required");
    }

    [Fact]
    public async Task CompatibilityEndpoint_RejectsQueryAndBody()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: false);
        using var client = host.CreateClient();
        using var query = CreateRequest(HttpMethod.Get, ClientCompatibilityEndpoints.Route + "?unused=1", "2");
        using var body = CreateRequest(HttpMethod.Get, ClientCompatibilityEndpoints.Route, "2");
        body.Content = new StringContent("{}", Encoding.UTF8, "application/json");

        using var queryResponse = await client.SendAsync(query);
        using var bodyResponse = await client.SendAsync(body);

        await AssertProblem(queryResponse, HttpStatusCode.BadRequest, "invalid_client_metadata");
        await AssertProblem(bodyResponse, HttpStatusCode.BadRequest, "invalid_client_metadata");
    }

    [Fact]
    public async Task Enforcement_ExemptsOnlyExactSystemInfoAndDevelopmentOpenApiPaths()
    {
        using var root = new RegistrationTestHost();
        using var host = Configure(root, enforcementEnabled: true);
        using var client = host.CreateClient();

        using var system = await client.GetAsync("/api/v1/system/info");
        using var lookalike = await client.GetAsync("/api/v1/system/info/private");
        using var openApi = await client.GetAsync("/openapi/v1.json");

        Assert.Equal(HttpStatusCode.OK, system.StatusCode);
        Assert.Equal((HttpStatusCode)426, lookalike.StatusCode);
        Assert.Equal(HttpStatusCode.OK, openApi.StatusCode);
    }

    private static WebApplicationFactory<Program> Configure(
        RegistrationTestHost root,
        bool enforcementEnabled) =>
        root.WithWebHostBuilder(builder => builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ClientCompatibility:EnforcementEnabled"] = enforcementEnabled.ToString(),
                ["ClientCompatibility:MinimumAndroidBuild"] = "2",
                ["ClientCompatibility:UpdateUri"] = enforcementEnabled
                    ? "https://downloads.example.test/kk10p"
                    : ""
            })));

    private static HttpRequestMessage CreateRequest(HttpMethod method, string path, string? build)
    {
        var request = new HttpRequestMessage(method, path);
        if (build is null) return request;
        request.Headers.TryAddWithoutValidation(ClientMetadataParser.PlatformHeader, "ANDROID");
        request.Headers.TryAddWithoutValidation(ClientMetadataParser.BuildHeader, build);
        return request;
    }

    private static async Task AssertProblem(
        HttpResponseMessage response,
        HttpStatusCode status,
        string code)
    {
        Assert.Equal(status, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(code, json.RootElement.GetProperty("code").GetString());
        Assert.True(json.RootElement.TryGetProperty("traceId", out var traceId));
        Assert.False(string.IsNullOrWhiteSpace(traceId.GetString()));
    }
}

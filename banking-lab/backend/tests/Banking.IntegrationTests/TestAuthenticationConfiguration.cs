using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Banking.IntegrationTests;

internal static class TestAuthenticationConfiguration
{
    // Test-only fixture, never read by the shipped API. HTTPS TestServer URLs
    // exercise the transport guard without changing machine certificates.
    public static void UseTestAuthentication(this IWebHostBuilder builder)
    {
        builder.ConfigureLogging(logging => logging.ClearProviders());
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = null,
                ["Jwt:SigningKey"] = "test-only-hmac-sha256-signing-key-banking-lab-at-least-32-chars-long!",
                ["Jwt:Issuer"] = "BankingLabTest",
                ["Jwt:Audience"] = "BankingTestAudience"
            }));
    }
}

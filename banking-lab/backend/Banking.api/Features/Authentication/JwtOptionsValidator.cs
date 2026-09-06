using System.Text;
using Microsoft.Extensions.Options;

namespace Banking.Api.Features.Authentication;

public sealed class JwtOptionsValidator : IValidateOptions<JwtOptions>
{
    public ValidateOptionsResult Validate(string? name, JwtOptions options)
    {
        // This checks configuration shape, not entropy. Operators must generate
        // a random secret outside source control; never include it in errors.
        var key = options.SigningKey;
        if (string.IsNullOrWhiteSpace(key) || key.Length > 4096
            || Encoding.UTF8.GetByteCount(key) < 32
            || key.StartsWith("development-fallback", StringComparison.OrdinalIgnoreCase)
            || key.StartsWith("your-", StringComparison.OrdinalIgnoreCase)
            || key.Distinct().Count() < 8)
        {
            return ValidateOptionsResult.Fail(
                "Configure Jwt:SigningKey with a private randomly generated secret of at least 32 bytes using user secrets or environment variables.");
        }

        if (string.IsNullOrWhiteSpace(options.Issuer)
            || string.IsNullOrWhiteSpace(options.Audience)
            || options.AccessTokenLifetimeMinutes is < 1 or > 10
            || options.SessionInactivityDays is < 1 or > 15
            || options.SessionAbsoluteLifetimeDays is < 1 or > 90
            || options.SessionInactivityDays > options.SessionAbsoluteLifetimeDays)
        {
            return ValidateOptionsResult.Fail("Invalid JWT issuer, audience or session lifetime policy.");
        }

        return ValidateOptionsResult.Success;
    }
}

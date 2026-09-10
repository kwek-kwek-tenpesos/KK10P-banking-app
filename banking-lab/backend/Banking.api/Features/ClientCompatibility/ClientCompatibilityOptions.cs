using Microsoft.Extensions.Options;

namespace Banking.Api.Features.ClientCompatibility;

public sealed class ClientCompatibilityOptions
{
    public const string SectionName = "ClientCompatibility";
    public const int MaximumBuild = 999_999_999;

    public bool EnforcementEnabled { get; set; }
    public int MinimumAndroidBuild { get; set; } = 2;
    public string? UpdateUri { get; set; }

    public bool TryGetUpdateUri(out Uri? uri)
    {
        uri = null;
        if (string.IsNullOrWhiteSpace(UpdateUri) || UpdateUri.Length > 2048)
            return false;

        if (!Uri.TryCreate(UpdateUri, UriKind.Absolute, out var parsed)
            || parsed.Scheme != Uri.UriSchemeHttps
            || string.IsNullOrEmpty(parsed.Host)
            || !string.IsNullOrEmpty(parsed.UserInfo))
            return false;

        uri = parsed;
        return true;
    }
}

public sealed class ClientCompatibilityOptionsValidator : IValidateOptions<ClientCompatibilityOptions>
{
    public ValidateOptionsResult Validate(string? name, ClientCompatibilityOptions options)
    {
        var errors = new List<string>();
        if (options.MinimumAndroidBuild is < 1 or > ClientCompatibilityOptions.MaximumBuild)
            errors.Add($"ClientCompatibility:MinimumAndroidBuild must be between 1 and {ClientCompatibilityOptions.MaximumBuild}.");

        if (options.UpdateUri is { Length: > 0 } && !options.TryGetUpdateUri(out _))
            errors.Add("ClientCompatibility:UpdateUri must be an absolute HTTPS URI without user information and at most 2048 characters.");

        if (options.EnforcementEnabled && !options.TryGetUpdateUri(out _))
            errors.Add("ClientCompatibility:UpdateUri is required when minimum-build enforcement is enabled.");

        return errors.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(errors);
    }
}

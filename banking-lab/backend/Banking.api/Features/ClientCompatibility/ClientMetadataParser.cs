using System.Globalization;

namespace Banking.Api.Features.ClientCompatibility;

public enum ClientMetadataParseOutcome
{
    Missing,
    Valid,
    Invalid
}

public readonly record struct ClientMetadata(string Platform, int Build);

public readonly record struct ClientMetadataParseResult(
    ClientMetadataParseOutcome Outcome,
    ClientMetadata? Metadata,
    string? Detail);

public static class ClientMetadataParser
{
    public const string PlatformHeader = "X-KK10P-Client-Platform";
    public const string BuildHeader = "X-KK10P-Client-Build";
    public const string AndroidPlatform = "ANDROID";

    public static ClientMetadataParseResult Parse(IHeaderDictionary headers)
    {
        var hasPlatform = headers.TryGetValue(PlatformHeader, out var platformValues);
        var hasBuild = headers.TryGetValue(BuildHeader, out var buildValues);
        if (!hasPlatform && !hasBuild)
            return new(ClientMetadataParseOutcome.Missing, null, null);

        if (!hasPlatform || !hasBuild || platformValues.Count != 1 || buildValues.Count != 1)
            return Invalid("Provide exactly one canonical client platform and build header.");

        var platform = platformValues[0];
        var buildText = buildValues[0];
        if (platform is null || buildText is null
            || !string.Equals(platform, AndroidPlatform, StringComparison.Ordinal))
            return Invalid("Client platform must use the canonical ANDROID value.");

        if (buildText.Length is < 1 or > 9 || buildText[0] is < '1' or > '9'
            || buildText.Any(character => character is < '0' or > '9')
            || !int.TryParse(buildText, NumberStyles.None, CultureInfo.InvariantCulture, out var build)
            || build > ClientCompatibilityOptions.MaximumBuild)
            return Invalid("Client build must be a positive canonical base-10 integer.");

        return new(ClientMetadataParseOutcome.Valid, new ClientMetadata(platform, build), null);
    }

    private static ClientMetadataParseResult Invalid(string detail) =>
        new(ClientMetadataParseOutcome.Invalid, null, detail);
}

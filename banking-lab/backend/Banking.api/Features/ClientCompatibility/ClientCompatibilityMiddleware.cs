using Microsoft.AspNetCore.Http.Features;
using Microsoft.Extensions.Options;

namespace Banking.Api.Features.ClientCompatibility;

public sealed class ClientCompatibilityLog;

public sealed class ClientCompatibilityMiddleware(
    RequestDelegate next,
    IOptions<ClientCompatibilityOptions> configured,
    ILogger<ClientCompatibilityLog> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var compatibilityRequest = ClientCompatibilityEndpoints.IsCompatibilityPath(context.Request.Path);
        if (!compatibilityRequest && !IsGovernedPath(context.Request.Path))
        {
            await next(context);
            return;
        }

        context.Response.Headers.CacheControl = "no-store";
        if (!context.Request.IsHttps)
        {
            await Problem(context, 400, "HTTPS required",
                "Client compatibility checks require a secure HTTPS connection.", "https_required");
            return;
        }

        if (compatibilityRequest &&
            (context.Request.QueryString.HasValue || context.Request.ContentLength is > 0
             || await HasBodyAsync(context.Request)))
        {
            await Problem(context, 400, "Invalid compatibility request",
                "Client compatibility checks do not accept query parameters or a request body.",
                "invalid_client_metadata");
            return;
        }

        var parsed = ClientMetadataParser.Parse(context.Request.Headers);
        if (parsed.Outcome == ClientMetadataParseOutcome.Invalid
            || compatibilityRequest && parsed.Outcome == ClientMetadataParseOutcome.Missing)
        {
            logger.LogInformation("Client compatibility request rejected because metadata was {MetadataOutcome}.",
                parsed.Outcome.ToString());
            await Problem(context, 400, "Invalid client metadata",
                parsed.Detail ?? "Provide one canonical client platform and build header.",
                "invalid_client_metadata");
            return;
        }

        var options = configured.Value;
        if (options.EnforcementEnabled &&
            (parsed.Metadata is null || parsed.Metadata.Value.Build < options.MinimumAndroidBuild))
        {
            var currentBuild = parsed.Metadata?.Build;
            logger.LogInformation(
                "Client build rejected for platform {Platform}; current build {CurrentBuild}, minimum build {MinimumBuild}.",
                parsed.Metadata?.Platform ?? "LEGACY", currentBuild, options.MinimumAndroidBuild);
            await UpgradeRequired(context, currentBuild, options);
            return;
        }

        await next(context);
    }

    private static bool IsGovernedPath(PathString path) =>
        path.StartsWithSegments("/api/v1")
        && !string.Equals(
            path.Value?.TrimEnd('/'),
            "/api/v1/system/info",
            StringComparison.OrdinalIgnoreCase);

    private static async Task<bool> HasBodyAsync(HttpRequest request)
    {
        if (!ClientCompatibilityEndpoints.IsCompatibilityPath(request.Path)) return false;
        var size = request.HttpContext.Features.Get<IHttpMaxRequestBodySizeFeature>();
        if (size is { IsReadOnly: false }) size.MaxRequestBodySize = 1;
        try
        {
            var buffer = new byte[1];
            return await request.Body.ReadAsync(buffer, request.HttpContext.RequestAborted) != 0;
        }
        catch (BadHttpRequestException exception) when (exception.StatusCode == 413)
        {
            return true;
        }
    }

    private static Task UpgradeRequired(
        HttpContext context,
        int? currentBuild,
        ClientCompatibilityOptions options)
    {
        options.TryGetUpdateUri(out var updateUri);
        return Results.Problem(
            statusCode: StatusCodes.Status426UpgradeRequired,
            title: "App update required",
            detail: "Install the current KK10P Bank app before continuing.",
            extensions: new Dictionary<string, object?>
            {
                ["code"] = "client_upgrade_required",
                ["platform"] = ClientMetadataParser.AndroidPlatform,
                ["currentBuild"] = currentBuild,
                ["minimumBuild"] = options.MinimumAndroidBuild,
                ["updateUri"] = updateUri?.AbsoluteUri
            }).ExecuteAsync(context);
    }

    private static Task Problem(HttpContext context, int status, string title, string detail, string code) =>
        Results.Problem(statusCode: status, title: title, detail: detail,
            extensions: new Dictionary<string, object?> { ["code"] = code })
            .ExecuteAsync(context);
}

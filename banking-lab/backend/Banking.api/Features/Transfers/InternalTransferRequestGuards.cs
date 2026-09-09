using System.Globalization;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;

namespace Banking.Api.Features.Transfers;

public static class InternalTransferRequestGuards
{
    public const int MaximumBodyBytes = 16 * 1024;
    public const string IdempotencyHeader = "Idempotency-Key";
    public static readonly object IdempotencyItem = new();
    public static readonly object RequestItem = new();

    public static IServiceCollection AddInternalTransferRequestGuards(this IServiceCollection services)
    {
        services.AddRateLimiter(options => options.AddPolicy("internal-transfer", context =>
            RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 10,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    AutoReplenishment = true
                })));
        return services;
    }

    public static async Task EnforceTransportAsync(HttpContext context, RequestDelegate next)
    {
        if (context.Request.Path.StartsWithSegments(InternalTransferEndpoints.RoutePrefix))
        {
            context.Response.Headers.CacheControl = "no-store";
            if (!context.Request.IsHttps)
            {
                await Results.Problem(statusCode: 400, title: "HTTPS required",
                    detail: "Internal transfers require a secure HTTPS connection.").ExecuteAsync(context);
                return;
            }
        }
        await next(context);
    }

    public static async Task EnforceInputAsync(HttpContext context, RequestDelegate next)
    {
        if (!string.Equals(context.Request.Path.Value?.TrimEnd('/'), InternalTransferEndpoints.Route,
                StringComparison.OrdinalIgnoreCase) || !HttpMethods.IsPost(context.Request.Method))
        {
            await next(context);
            return;
        }

        if (context.Request.QueryString.HasValue)
        {
            await Invalid("Internal transfers accept no query parameters.").ExecuteAsync(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue(IdempotencyHeader, out var values) || values.Count != 1 ||
            !TryCanonicalGuid(values[0], out var idempotencyKey))
        {
            await Invalid("Provide one canonical non-empty UUID Idempotency-Key header.").ExecuteAsync(context);
            return;
        }

        var size = context.Features.Get<IHttpMaxRequestBodySizeFeature>();
        if (size is { IsReadOnly: false }) size.MaxRequestBodySize = MaximumBodyBytes;
        if (context.Request.ContentLength > MaximumBodyBytes)
        {
            await TooLarge().ExecuteAsync(context);
            return;
        }
        if (!context.Request.HasJsonContentType())
        {
            await Results.Problem(statusCode: 415, detail: "Send an application/json transfer request.")
                .ExecuteAsync(context);
            return;
        }

        using var body = new MemoryStream();
        try
        {
            var buffer = new byte[4096];
            int read;
            while ((read = await context.Request.Body.ReadAsync(buffer, context.RequestAborted)) != 0)
            {
                if (body.Length + read > MaximumBodyBytes)
                {
                    await TooLarge().ExecuteAsync(context);
                    return;
                }
                await body.WriteAsync(buffer.AsMemory(0, read), context.RequestAborted);
            }
        }
        catch (BadHttpRequestException exception) when (exception.StatusCode == 413)
        {
            await TooLarge().ExecuteAsync(context);
            return;
        }

        body.Position = 0;
        try
        {
            using var json = await JsonDocument.ParseAsync(body, cancellationToken: context.RequestAborted);
            if (!TryParse(json.RootElement, out var request, out var detail))
            {
                await Invalid(detail).ExecuteAsync(context);
                return;
            }
            context.Items[IdempotencyItem] = idempotencyKey;
            context.Items[RequestItem] = request;
        }
        catch (JsonException)
        {
            await Invalid("Send one valid JSON object with exactly the required transfer fields.")
                .ExecuteAsync(context);
            return;
        }

        await next(context);
    }

    private static bool TryParse(JsonElement root, out ValidatedInternalTransfer request, out string detail)
    {
        request = default;
        detail = "Send exactly destinationAccountReference and amountMinor.";
        if (root.ValueKind != JsonValueKind.Object) return false;
        var properties = root.EnumerateObject().ToArray();
        if (properties.Length != 2 ||
            properties.Count(item => item.NameEquals("destinationAccountReference")) != 1 ||
            properties.Count(item => item.NameEquals("amountMinor")) != 1)
            return false;

        var destinationElement = properties.Single(item => item.NameEquals("destinationAccountReference")).Value;
        if (destinationElement.ValueKind != JsonValueKind.String ||
            !TryCanonicalGuid(destinationElement.GetString(), out var destination))
        {
            detail = "destinationAccountReference must be one canonical non-empty UUID.";
            return false;
        }

        var amountElement = properties.Single(item => item.NameEquals("amountMinor")).Value;
        var amountText = amountElement.ValueKind == JsonValueKind.String ? amountElement.GetString() : null;
        if (!TryCanonicalAmount(amountText, out var amount))
        {
            detail = "amountMinor must be a canonical integer string from 1 through 5000000.";
            return false;
        }

        request = new(destination, amount);
        return true;
    }

    private static bool TryCanonicalGuid(string? value, out Guid parsed) =>
        Guid.TryParseExact(value, "D", out parsed) && parsed != Guid.Empty &&
        string.Equals(value, parsed.ToString("D"), StringComparison.Ordinal);

    private static bool TryCanonicalAmount(string? value, out long parsed)
    {
        parsed = 0;
        if (string.IsNullOrEmpty(value) || value.Length > 19 || value[0] == '0' ||
            value.Any(character => character is < '0' or > '9')) return false;
        return long.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out parsed) &&
            parsed is >= InternalTransferPolicy.MinimumMinor and <= InternalTransferPolicy.MaximumPerTransferMinor;
    }

    private static IResult Invalid(string detail) => Results.Problem(statusCode: 400, detail: detail);
    private static IResult TooLarge() => Results.Problem(statusCode: 413,
        detail: "Internal transfer requests must not exceed 16 KiB.");
}

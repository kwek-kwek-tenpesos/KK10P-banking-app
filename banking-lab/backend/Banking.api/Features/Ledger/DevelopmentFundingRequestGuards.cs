using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;

namespace Banking.Api.Features.Ledger;

public static class DevelopmentFundingRequestGuards
{
    public const int MaximumBodyBytes = 16 * 1024;
    public const string IdempotencyHeader = "Idempotency-Key";
    public static readonly object IdempotencyItem = new();

    public static IServiceCollection AddDevelopmentFundingRequestGuards(this IServiceCollection services)
    {
        services.AddRateLimiter(options => options.AddPolicy("development-funding", context =>
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
        if (context.Request.Path.StartsWithSegments(DevelopmentFundingEndpoints.RoutePrefix))
        {
            context.Response.Headers.CacheControl = "no-store";
            if (!context.Request.IsHttps)
            {
                await Results.Problem(statusCode: 400, title: "HTTPS required",
                    detail: "Simulator funding requires a secure HTTPS connection.").ExecuteAsync(context);
                return;
            }
        }
        await next(context);
    }

    public static async Task EnforceInputAsync(HttpContext context, RequestDelegate next)
    {
        if (!string.Equals(context.Request.Path.Value?.TrimEnd('/'), DevelopmentFundingEndpoints.Route,
                StringComparison.OrdinalIgnoreCase) || !HttpMethods.IsPost(context.Request.Method))
        {
            await next(context);
            return;
        }

        if (context.Request.QueryString.HasValue)
        {
            await Invalid("Simulator funding accepts no query parameters.").ExecuteAsync(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue(IdempotencyHeader, out var values) || values.Count != 1 ||
            !Guid.TryParseExact(values[0], "D", out var idempotencyKey))
        {
            await Invalid("Provide one UUID Idempotency-Key header.").ExecuteAsync(context);
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
            await Results.Problem(statusCode: 415, detail: "Send an empty JSON object.").ExecuteAsync(context);
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
            if (json.RootElement.ValueKind != JsonValueKind.Object || json.RootElement.EnumerateObject().Any())
            {
                await Invalid("Send exactly one empty JSON object.").ExecuteAsync(context);
                return;
            }
        }
        catch (JsonException)
        {
            await Invalid("Send exactly one empty JSON object.").ExecuteAsync(context);
            return;
        }

        context.Items[IdempotencyItem] = idempotencyKey;
        await next(context);
    }

    private static IResult Invalid(string detail) => Results.Problem(statusCode: 400, detail: detail);
    private static IResult TooLarge() => Results.Problem(statusCode: 413,
        detail: "Simulator funding requests must not exceed 16 KiB.");
}

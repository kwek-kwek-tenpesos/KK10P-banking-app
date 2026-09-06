using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;

namespace Banking.Api.Features.Accounts;

public static class AccountRequestGuards
{
    public const int MaximumBodyBytes = 16 * 1024;

    public static IServiceCollection AddAccountRequestGuards(this IServiceCollection services)
    {
        services.AddRateLimiter(options => options.AddPolicy("accounts", context =>
            RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 30, Window = TimeSpan.FromMinutes(1), QueueLimit = 0,
                    AutoReplenishment = true
                })));
        return services;
    }

    // Run before rate limiting/authentication so every rejection remains no-store
    // and plain HTTP never reaches bearer processing. Body work runs after limiting.
    public static async Task EnforceTransportAsync(HttpContext context, RequestDelegate next)
    {
        if (context.Request.Path.StartsWithSegments("/api/v1/accounts"))
        {
            context.Response.Headers.CacheControl = "no-store";
            if (!context.Request.IsHttps)
            {
                await Results.Problem(statusCode: 400, title: "HTTPS required",
                    detail: "Account access requires a secure HTTPS connection.").ExecuteAsync(context);
                return;
            }
        }
        await next(context);
    }

    public static async Task EnforceInputAsync(HttpContext context, RequestDelegate next)
    {
        if (!string.Equals(context.Request.Path.Value?.TrimEnd('/'), CustomerAccountEndpoints.Route, StringComparison.OrdinalIgnoreCase)
            || !(HttpMethods.IsGet(context.Request.Method) || HttpMethods.IsPut(context.Request.Method)))
        {
            await next(context);
            return;
        }
        if (context.Request.QueryString.HasValue)
        {
            await Invalid().ExecuteAsync(context);
            return;
        }
        var size = context.Features.Get<IHttpMaxRequestBodySizeFeature>();
        if (size is { IsReadOnly: false }) size.MaxRequestBodySize = MaximumBodyBytes;
        if (context.Request.ContentLength > MaximumBodyBytes)
        {
            await TooLarge().ExecuteAsync(context);
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
        if (HttpMethods.IsGet(context.Request.Method))
        {
            if (body.Length != 0) { await Invalid().ExecuteAsync(context); return; }
        }
        else
        {
            if (!context.Request.HasJsonContentType())
            {
                await Results.Problem(statusCode: 415, detail: "Send an empty JSON object.").ExecuteAsync(context);
                return;
            }
            body.Position = 0;
            try
            {
                using var json = await JsonDocument.ParseAsync(body, cancellationToken: context.RequestAborted);
                if (json.RootElement.ValueKind != JsonValueKind.Object || json.RootElement.EnumerateObject().Any())
                { await Invalid().ExecuteAsync(context); return; }
            }
            catch (JsonException) { await Invalid().ExecuteAsync(context); return; }
        }
        // Endpoints receive no caller data: the current principal supplies ownership.
        await next(context);
    }

    private static IResult Invalid() => Results.Problem(statusCode: 400,
        detail: "Account reads accept no input; opening accepts only an empty JSON object and no query parameters.");
    private static IResult TooLarge() => Results.Problem(statusCode: 413,
        detail: "Account requests must not exceed 16 KiB.");
}

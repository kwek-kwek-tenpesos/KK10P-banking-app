using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;

namespace Banking.Api.Features.Activity;

public static class ActivityRequestGuards
{
    public const string RateLimitPolicy = "activity";
    public static readonly object QueryItem = new();

    public static IServiceCollection AddActivityRequestGuards(this IServiceCollection services)
    {
        services.AddRateLimiter(options => options.AddPolicy(RateLimitPolicy, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 60,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    AutoReplenishment = true
                })));
        return services;
    }

    public static async Task EnforceTransportAsync(HttpContext context, RequestDelegate next)
    {
        if (context.Request.Path.StartsWithSegments(ActivityEndpoints.RoutePrefix))
        {
            context.Response.Headers.CacheControl = "no-store";
            if (!context.Request.IsHttps)
            {
                await Results.Problem(
                    statusCode: 400,
                    title: "HTTPS required",
                    detail: "Activity access requires a secure HTTPS connection.")
                    .ExecuteAsync(context);
                return;
            }
        }
        await next(context);
    }

    public static async Task EnforceInputAsync(HttpContext context, RequestDelegate next)
    {
        if (!HttpMethods.IsGet(context.Request.Method) ||
            !context.Request.Path.StartsWithSegments(ActivityEndpoints.RoutePrefix))
        {
            await next(context);
            return;
        }

        if (context.Request.ContentLength is > 0 || await HasBodyAsync(context.Request))
        {
            await Invalid(context, "Activity reads do not accept a request body.");
            return;
        }

        var normalizedPath = context.Request.Path.Value?.TrimEnd('/');
        if (string.Equals(normalizedPath, ActivityEndpoints.RoutePrefix, StringComparison.OrdinalIgnoreCase))
        {
            if (!ActivityPolicy.TryParseQuery(context.Request.Query, out var query, out var detail))
            {
                await Invalid(context, detail);
                return;
            }
            context.Items[QueryItem] = query;
        }
        else if (context.Request.QueryString.HasValue)
        {
            await Invalid(context, "Transaction detail accepts no query parameters.");
            return;
        }

        await next(context);
    }

    private static async Task<bool> HasBodyAsync(HttpRequest request)
    {
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

    private static Task Invalid(HttpContext context, string detail) => Results.Problem(
        statusCode: 400,
        title: "Invalid Activity request",
        detail: detail,
        extensions: new Dictionary<string, object?> { ["code"] = "invalid_activity_query" })
        .ExecuteAsync(context);
}

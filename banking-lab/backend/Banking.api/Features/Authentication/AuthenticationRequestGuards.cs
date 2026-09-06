using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.RateLimiting;

namespace Banking.Api.Features.Authentication;

public static class AuthenticationRequestGuards
{
    public const int MaximumBodyBytes = 16 * 1024;

    public static IServiceCollection AddAuthenticationRequestGuards(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            AddPolicy(options, "login", 10, TimeSpan.FromMinutes(1));
            AddPolicy(options, "register", 5, TimeSpan.FromMinutes(15));
            AddPolicy(options, "verify-email", 10, TimeSpan.FromMinutes(15));
            AddPolicy(options, "resend-verification", 3, TimeSpan.FromMinutes(15));
            AddPolicy(options, "refresh", 60, TimeSpan.FromMinutes(1));
            AddPolicy(options, "logout", 60, TimeSpan.FromMinutes(1));
            options.OnRejected = async (context, cancellationToken) =>
            {
                var seconds = context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retry)
                    ? Math.Max(1, (int)Math.Ceiling(retry.TotalSeconds)) : 60;
                context.HttpContext.Response.Headers.RetryAfter = seconds.ToString(CultureInfo.InvariantCulture);
                await Results.Problem(statusCode: 429, title: "Too many requests",
                    detail: "Too many attempts. Please wait and try again.")
                    .ExecuteAsync(context.HttpContext);
            };
        });
        return services;
    }

    private static void AddPolicy(RateLimiterOptions options, string name, int limit, TimeSpan window) =>
        options.AddPolicy(name, context => RateLimitPartition.GetFixedWindowLimiter(
            // Ignore untrusted forwarding headers. These counters are per process.
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = limit,
                Window = window,
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    public static async Task EnforceAsync(HttpContext context, RequestDelegate next)
    {
        if (!context.Request.Path.StartsWithSegments("/api/v1/auth"))
        {
            await next(context);
            return;
        }

        context.Response.Headers.CacheControl = "no-store";
        if (!context.Request.IsHttps)
        {
            await Results.Problem(statusCode: 400, title: "HTTPS required",
                detail: "Authentication requires a secure HTTPS connection.").ExecuteAsync(context);
            return;
        }

        var sizeFeature = context.Features.Get<IHttpMaxRequestBodySizeFeature>();
        if (sizeFeature is { IsReadOnly: false }) sizeFeature.MaxRequestBodySize = MaximumBodyBytes;
        if (context.Request.ContentLength > MaximumBodyBytes)
        {
            await TooLarge().ExecuteAsync(context);
            return;
        }

        // Bound streamed/chunked bodies too, before JSON binding or hashing.
        // Rate limiting runs before this middleware so rejected requests aren't read.
        if (HttpMethods.IsPost(context.Request.Method))
        {
            using var buffered = new MemoryStream();
            var buffer = new byte[4096];
            var original = context.Request.Body;
            try
            {
                int read;
                while ((read = await original.ReadAsync(buffer, context.RequestAborted)) != 0)
                {
                    if (buffered.Length + read > MaximumBodyBytes)
                    {
                        await TooLarge().ExecuteAsync(context);
                        return;
                    }
                    await buffered.WriteAsync(buffer.AsMemory(0, read), context.RequestAborted);
                }
                buffered.Position = 0;
                context.Request.Body = buffered;
                await next(context);
            }
            catch (BadHttpRequestException exception) when (exception.StatusCode == 413)
            {
                await TooLarge().ExecuteAsync(context);
            }
            finally { context.Request.Body = original; }
            return;
        }
        await next(context);
    }

    private static IResult TooLarge() => Results.Problem(statusCode: 413,
        title: "Request too large", detail: "Authentication requests must not exceed 16 KiB.");
}

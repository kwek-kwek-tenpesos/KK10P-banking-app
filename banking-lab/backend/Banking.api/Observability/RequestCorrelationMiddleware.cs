using System.Diagnostics;

namespace Banking.Api.Observability;

public sealed class RequestCorrelationMiddleware(RequestDelegate next,
    ILogger<RequestCorrelationMiddleware> logger)
{
    public const string HeaderName = "X-Request-ID";

    public async Task InvokeAsync(HttpContext context)
    {
        var requestId = Guid.NewGuid().ToString("N");
        context.TraceIdentifier = requestId;
        context.Response.Headers[HeaderName] = requestId;

        using (logger.BeginScope(new Dictionary<string, object> { ["RequestId"] = requestId }))
        {
            var started = Stopwatch.GetTimestamp();
            var pipelineCompleted = false;
            try
            {
                await next(context);
                pipelineCompleted = true;
            }
            finally
            {
                if (context.Request.Path.StartsWithSegments("/api/v1/transfers"))
                {
                    if (pipelineCompleted)
                        logger.LogInformation(
                            "Internal transfer request completed with status {StatusCode} in {DurationMs} ms.",
                            context.Response.StatusCode,
                            Stopwatch.GetElapsedTime(started).TotalMilliseconds);
                    else
                        logger.LogInformation("Internal transfer request was interrupted after {DurationMs} ms.",
                            Stopwatch.GetElapsedTime(started).TotalMilliseconds);
                }
            }
        }
    }
}

public static class RequestCorrelationExtensions
{
    public static IApplicationBuilder UseRequestCorrelation(this IApplicationBuilder app) =>
        app.UseMiddleware<RequestCorrelationMiddleware>();
}

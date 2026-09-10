using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace Banking.Api.Features.ClientCompatibility;

public sealed record ClientCompatibilityResponse(
    string Platform,
    int CurrentBuild,
    int MinimumBuild,
    bool UpdateRequired,
    string? UpdateUri);

public static class ClientCompatibilityEndpoints
{
    public const string Route = "/api/v1/client/compatibility";
    public const string RateLimitPolicy = "client-compatibility";

    public static IServiceCollection AddClientCompatibility(this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton<IValidateOptions<ClientCompatibilityOptions>, ClientCompatibilityOptionsValidator>();
        services.AddOptions<ClientCompatibilityOptions>()
            .Bind(configuration.GetSection(ClientCompatibilityOptions.SectionName))
            .ValidateOnStart();
        services.AddRateLimiter(options => options.AddPolicy(RateLimitPolicy, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 30,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                    AutoReplenishment = true
                })));
        return services;
    }

    public static void MapClientCompatibility(this WebApplication app)
    {
        app.MapGet(Route, (HttpContext context, IOptions<ClientCompatibilityOptions> configured) =>
            {
                var metadata = ClientMetadataParser.Parse(context.Request.Headers).Metadata!.Value;
                var options = configured.Value;
                options.TryGetUpdateUri(out var updateUri);
                return Results.Ok(new ClientCompatibilityResponse(
                    metadata.Platform,
                    metadata.Build,
                    options.MinimumAndroidBuild,
                    false,
                    updateUri?.AbsoluteUri));
            })
            .RequireRateLimiting(RateLimitPolicy)
            .WithName("ReadClientCompatibility")
            .Produces<ClientCompatibilityResponse>()
            .ProducesProblem(400)
            .ProducesProblem(426)
            .ProducesProblem(429);
    }

    public static bool IsCompatibilityPath(PathString path) =>
        string.Equals(path.Value?.TrimEnd('/'), Route, StringComparison.OrdinalIgnoreCase);
}

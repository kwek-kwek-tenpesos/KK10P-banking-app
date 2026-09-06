using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

namespace Banking.Api.Features.Authentication;

public static class TrustedLoopbackForwarding
{
    public static IServiceCollection AddTrustedLoopbackForwarding(this IServiceCollection services)
    {
        services.Configure<ForwardedHeadersOptions>(options =>
        {
            options.ForwardedHeaders =
                ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            options.ForwardLimit = 1;

            options.KnownIPNetworks.Clear();
            options.KnownProxies.Clear();
            options.KnownProxies.Add(IPAddress.Loopback);
            options.KnownProxies.Add(IPAddress.IPv6Loopback);
        });

        return services;
    }
}

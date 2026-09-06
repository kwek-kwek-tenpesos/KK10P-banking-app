using System.Net;
using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Banking.IntegrationTests;

public sealed class TrustedLoopbackForwardingTests
{
    [Fact]
    public void Configuration_TrustsOnlyExactLoopbackProxies_AndOneHop()
    {
        using var services = new ServiceCollection()
            .AddTrustedLoopbackForwarding()
            .BuildServiceProvider();

        var options = services.GetRequiredService<IOptions<ForwardedHeadersOptions>>().Value;

        Assert.Equal(
            ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
            options.ForwardedHeaders);
        Assert.Equal(1, options.ForwardLimit);
        Assert.Empty(options.KnownIPNetworks);
        Assert.Equal(
            [IPAddress.Loopback, IPAddress.IPv6Loopback],
            options.KnownProxies);
    }

    [Theory]
    [InlineData("127.0.0.1", "https")]
    [InlineData("::1", "https")]
    [InlineData("192.0.2.10", "http")]
    public async Task ForwardedHttps_IsAcceptedOnlyFromLoopback(
        string proxyAddress,
        string expectedScheme)
    {
        await using var app = await CreateApplicationAsync(IPAddress.Parse(proxyAddress));
        using var client = app.GetTestClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/");
        request.Headers.TryAddWithoutValidation("X-Forwarded-For", "100.64.0.10");
        request.Headers.TryAddWithoutValidation("X-Forwarded-Proto", "https");

        using var response = await client.SendAsync(request);
        var scheme = await response.Content.ReadAsStringAsync();

        Assert.Equal(expectedScheme, scheme);
    }

    private static async Task<WebApplication> CreateApplicationAsync(IPAddress proxyAddress)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = "Testing"
        });
        builder.WebHost.UseTestServer();
        builder.Services.AddTrustedLoopbackForwarding();

        var app = builder.Build();
        app.Use((context, next) =>
        {
            context.Connection.RemoteIpAddress = proxyAddress;
            return next();
        });
        app.UseForwardedHeaders();
        app.Run(context => context.Response.WriteAsync(context.Request.Scheme));

        await app.StartAsync();
        return app;
    }
}

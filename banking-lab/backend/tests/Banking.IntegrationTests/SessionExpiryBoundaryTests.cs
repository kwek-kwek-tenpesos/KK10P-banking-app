using System.Net;
using System.Net.Http.Json;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

// Regression from batch C review; no PostgreSQL or external requests.
public sealed class SessionExpiryBoundaryTests
{
    [Fact]
    public async Task ExpiryDuringRefreshPersistence_ShouldReturn401InsteadOfThrowing()
    {
        using var baseHost = new RegistrationTestHost();
        var delay = new DelayedWrite();
        using var host = baseHost.WithWebHostBuilder(builder => builder.ConfigureServices(services =>
            services.AddDbContext<AppDbContext>(options => options.AddInterceptors(delay))));
        var user = await CustomerSessionTests.SeedAsync(host.Services);
        using var client = host.CreateClient(new() { BaseAddress = new Uri("https://localhost") });
        var login = await CustomerSessionTests.LoginAsync(client, user.Email!);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync();
            session.AbsoluteExpiresAtUtc = DateTime.UtcNow.AddSeconds(1);
            await db.SaveChangesAsync();
        }
        delay.Enabled = true;
        using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.True(delay.WasDelayed);
    }

    private sealed class DelayedWrite : SaveChangesInterceptor
    {
        public bool Enabled { get; set; }
        public bool WasDelayed { get; private set; }
        public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData data,
            InterceptionResult<int> result, CancellationToken ct = default)
        {
            if (Enabled)
            {
                WasDelayed = true;
                await Task.Delay(TimeSpan.FromSeconds(2), ct);
            }
            return result;
        }
    }
}

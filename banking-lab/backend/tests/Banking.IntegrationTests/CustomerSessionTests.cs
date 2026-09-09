using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Banking.IntegrationTests;

public sealed class CustomerSessionTests
{
    internal const string Password = "Correct Horse Battery Staple!";

    [Theory]
    [InlineData("legacy")]
    [InlineData("wrong-user")]
    [InlineData("wrong-session")]
    [InlineData("expired")]
    [InlineData("wrong-issuer")]
    [InlineData("wrong-audience")]
    [InlineData("wrong-key")]
    public async Task InvalidSignedToken_IsRejected(string cause)
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        await LoginAsync(client, user.Email!);
        using var scope = host.Services.CreateScope();
        var session = await scope.ServiceProvider.GetRequiredService<AppDbContext>().CustomerSessions.SingleAsync();
        var options = scope.ServiceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<JwtOptions>>().Value;
        var owner = cause == "wrong-user" ? Guid.NewGuid().ToString() : user.Id;
        var claims = new List<System.Security.Claims.Claim>
        {
            new("sub", owner), new(System.Security.Claims.ClaimTypes.NameIdentifier, owner)
        };
        if (cause != "legacy") claims.Add(new("sid", cause == "wrong-session" ? Guid.NewGuid().ToString() : session.Id.ToString()));
        var key = cause == "wrong-key" ? "untrusted-test-signing-key-that-is-long-enough-12345" : options.SigningKey;
        var token = new JwtSecurityToken(cause == "wrong-issuer" ? "other-issuer" : options.Issuer,
            cause == "wrong-audience" ? "other-audience" : options.Audience, claims,
            DateTime.UtcNow.AddHours(-1), cause == "expired" ? DateTime.UtcNow.AddMinutes(-1) : DateTime.UtcNow.AddMinutes(5),
            new Microsoft.IdentityModel.Tokens.SigningCredentials(
                new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(System.Text.Encoding.UTF8.GetBytes(key)),
                Microsoft.IdentityModel.Tokens.SecurityAlgorithms.HmacSha256));
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, new JwtSecurityTokenHandler().WriteToken(token)));
    }

    [Fact]
    public void Session_IsInactiveAtEitherExactDeadline()
    {
        var now = new DateTime(2026, 9, 4, 0, 0, 0, DateTimeKind.Utc);
        var session = new CustomerSession { IdleExpiresAtUtc = now, AbsoluteExpiresAtUtc = now.AddDays(1) };
        Assert.False(session.IsActiveAt(now));
        session.IdleExpiresAtUtc = now.AddDays(1);
        session.AbsoluteExpiresAtUtc = now;
        Assert.False(session.IsActiveAt(now));
        Assert.True(session.IsActiveAt(now.AddTicks(-1)));
    }

    [Fact]
    public async Task LogoutAncestor_InvalidatesDescendantsAndAccess_ButNotAnotherLogin()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var first = await LoginAsync(client, user.Email!);
        var other = await LoginAsync(client, user.Email!);
        using var rotated = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { first.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
        var child = (await rotated.Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
        Assert.Equal(HttpStatusCode.OK, await MeAsync(client, first.AccessToken));
        using var logout = await client.PostAsJsonAsync("/api/v1/auth/logout", new { first.RefreshToken });
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, first.AccessToken));
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, child.AccessToken));
        Assert.Equal(HttpStatusCode.OK, await MeAsync(client, other.AccessToken));
        using var refresh = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { child.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
        using var repeated = await client.PostAsJsonAsync("/api/v1/auth/logout", new { first.RefreshToken });
        Assert.Equal(HttpStatusCode.NoContent, repeated.StatusCode);
    }

    [Theory]
    [InlineData("John Doe OR 1=1 -- ")]
    [InlineData("John Doe AND 1=1 -- ")]
    public async Task Logout_WithInjectionShapedUnknownToken_DoesNotRevokeExistingSession(string candidate)
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await LoginAsync(client, user.Email!);

        using var logout = await client.PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = candidate });

        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.Equal(HttpStatusCode.OK, await MeAsync(client, login.AccessToken));
        using var refresh = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
    }

    [Fact]
    public async Task ReplayRevokesOnlyItsSession()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var first = await LoginAsync(client, user.Email!);
        var other = await LoginAsync(client, user.Email!);
        using var rotated = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { first.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
        using var replay = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { first.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, first.AccessToken));
        Assert.Equal(HttpStatusCode.OK, await MeAsync(client, other.AccessToken));
    }

    [Theory]
    [InlineData("idle")]
    [InlineData("absolute")]
    [InlineData("stamp")]
    [InlineData("disabled")]
    [InlineData("unconfirmed")]
    [InlineData("locked")]
    [InlineData("owner")]
    public async Task InvalidSessionOrUser_RejectsBothAccessAndRefresh(string cause)
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await LoginAsync(client, user.Email!);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync();
            if (cause == "idle") session.IdleExpiresAtUtc = DateTime.UtcNow;
            if (cause == "absolute") session.AbsoluteExpiresAtUtc = DateTime.UtcNow;
            if (cause == "owner") session.UserId = "another-user";
            await db.SaveChangesAsync();
        }
        if (cause == "stamp") user.SecurityStamp = Guid.NewGuid().ToString();
        if (cause == "disabled") user.IsEnabled = false;
        if (cause == "unconfirmed") user.EmailConfirmed = false;
        if (cause == "locked") user.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(5);
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, login.AccessToken));
        using var refresh = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task RotationSlidesIdleDeadline_ButNeverAbsoluteDeadline_AndCapsJwt()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await LoginAsync(client, user.Email!);
        var absolute = DateTime.UtcNow.AddMinutes(2);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync();
            Assert.InRange((session.AbsoluteExpiresAtUtc - session.CreatedAtUtc).TotalDays, 90, 90);
            Assert.Equal(session.CreatedAtUtc.AddDays(15), session.IdleExpiresAtUtc);
            session.CreatedAtUtc = absolute.AddDays(-90);
            session.IdleExpiresAtUtc = DateTime.UtcNow.AddMinutes(1);
            session.AbsoluteExpiresAtUtc = absolute;
            await db.SaveChangesAsync();
        }
        using var refresh = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var response = (await refresh.Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
        Assert.InRange(response.ExpiresInSeconds, 1, 120);
        Assert.True(new JwtSecurityTokenHandler().ReadJwtToken(response.AccessToken).ValidTo <= absolute);
        using var verification = host.Services.CreateScope();
        var database = verification.ServiceProvider.GetRequiredService<AppDbContext>();
        var persisted = await database.CustomerSessions.SingleAsync();
        Assert.Equal(absolute, persisted.AbsoluteExpiresAtUtc);
        Assert.Equal(absolute, persisted.IdleExpiresAtUtc);
        Assert.All(await database.RefreshTokens.Where(t => t.RevokedAtUtc == null).ToListAsync(), t => Assert.Equal(absolute, t.ExpiresAtUtc));
    }

    [Fact]
    public async Task SessionRefreshBudget_Returns429_AndCanResumeAfterWindow()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        var login = await LoginAsync(client, user.Email!);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync();
            session.RefreshWindowCount = 30;
            await db.SaveChangesAsync();
        }
        using var limited = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.NotNull(limited.Headers.RetryAfter);
        Assert.True(limited.Headers.CacheControl?.NoStore);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var session = await db.CustomerSessions.SingleAsync();
            session.RefreshWindowStartedAtUtc = DateTime.UtcNow.AddMinutes(-2);
            await db.SaveChangesAsync();
        }
        using var allowed = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { login.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, allowed.StatusCode);
    }

    [Fact]
    public async Task MeRequiresAuthentication_AndReturnsOnlyIdAndDisplayName()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedAsync(host.Services);
        using var client = host.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, null));
        Assert.Equal(HttpStatusCode.Unauthorized, await MeAsync(client, "not-a-jwt"));
        var login = await LoginAsync(client, user.Email!);
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/auth/me");
        request.Headers.Authorization = new("Bearer", login.AccessToken);
        using var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Equal(["displayName", "id"], body.EnumerateObject().Select(p => p.Name).Order().ToArray());
        Assert.Equal(user.Id, body.GetProperty("id").GetString());
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    internal static async Task<ApplicationUser> SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var email = $"session-{Guid.NewGuid():N}@example.test";
        var user = new ApplicationUser
        {
            Email = email,
            UserName = users.NormalizeEmail(email),
            EmailConfirmed = true,
            DisplayName = "Session Test",
            IsEnabled = true,
            LockoutEnabled = true
        };
        Assert.True((await users.CreateAsync(user, Password)).Succeeded);
        return user;
    }

    internal static async Task<CustomerLoginResponse> LoginAsync(HttpClient client, string email)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = Password });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<CustomerLoginResponse>())!;
    }

    internal static async Task<HttpStatusCode> MeAsync(HttpClient client, string? token)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/auth/me");
        if (token is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);
        return response.StatusCode;
    }
}

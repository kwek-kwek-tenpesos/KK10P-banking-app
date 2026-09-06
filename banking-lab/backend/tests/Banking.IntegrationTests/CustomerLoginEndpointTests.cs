using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Banking.Api.Features.Authentication;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class CustomerLoginEndpointTests
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);
    private const string CustomerPassword = "Correct Horse Battery Staple!";

    [Fact]
    public async Task PostLogin_WithValidCredentials_Returns200Ok_AndPersistsHashedRefreshToken()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "login.test1@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var payload = new
        {
            email = "login.test1@example.test",
            password = CustomerPassword
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", payload, WebJson);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var loginResponse = await response.Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);
        Assert.NotNull(loginResponse);
        Assert.False(string.IsNullOrWhiteSpace(loginResponse.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(loginResponse.RefreshToken));
        Assert.Equal("Bearer", loginResponse.TokenType);
        Assert.InRange(loginResponse.ExpiresInSeconds, 598, 600);

        // Access token is readable JWT
        var handler = new JwtSecurityTokenHandler();
        var jwt = handler.ReadJwtToken(loginResponse.AccessToken);
        Assert.Equal(user.Id, jwt.Subject);

        // Verify refresh token hash in database (plaintext token NEVER stored in DB)
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tokenService = scope.ServiceProvider.GetRequiredService<ITokenService>();

        var expectedHash = tokenService.ComputeHash(loginResponse.RefreshToken);
        var tokenInDb = await db.RefreshTokens.SingleOrDefaultAsync(t => t.UserId == user.Id);

        Assert.NotNull(tokenInDb);
        Assert.Equal(expectedHash, tokenInDb.TokenHash);
        Assert.NotEqual(loginResponse.RefreshToken, tokenInDb.TokenHash);
        Assert.True(tokenInDb.IsActive);
        Assert.False(tokenInDb.IsRevoked);
    }

    [Fact]
    public async Task PostLogin_WithInvalidPassword_Returns401Unauthorized_AndIncrementsAccessFailedCount()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "login.badpw@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var payload = new
        {
            email = "login.badpw@example.test",
            password = "WrongPassword12345!"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", payload, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("Invalid email or password.", doc.RootElement.GetProperty("detail").GetString());

        Assert.Equal(1, user.AccessFailedCount);
    }

    [Fact]
    public async Task PostLogin_WithNonExistentEmail_Returns401Unauthorized_WithoutLeakingAccountExistence()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "does.not.exist@example.test",
            password = "AnyValidFormatPassword123!"
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", payload, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("Invalid email or password.", doc.RootElement.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task PostLogin_WhenUserIsLockedOut_ReturnsGeneric401()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "locked.user@example.test", CustomerPassword);
        user.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(15);

        using var client = host.CreateClient();
        var payload = new
        {
            email = "locked.user@example.test",
            password = CustomerPassword
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", payload, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PostLogin_WithConsecutiveFailures_TriggersLockout()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "lockout.target@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var badPayload = new
        {
            email = "lockout.target@example.test",
            password = "WrongPassword99999!"
        };

        // 5 consecutive failed attempts (max allowed is 5)
        for (var i = 1; i <= 4; i++)
        {
            using var r = await client.PostAsJsonAsync("/api/v1/auth/login", badPayload, WebJson);
            Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
        }

        // 5th failed attempt locks out the user
        using var fifthResponse = await client.PostAsJsonAsync("/api/v1/auth/login", badPayload, WebJson);
        Assert.Equal(HttpStatusCode.Unauthorized, fifthResponse.StatusCode);

        // Subsequent attempt with correct password also returns generic 401
        var goodPayload = new
        {
            email = "lockout.target@example.test",
            password = CustomerPassword
        };
        using var lockedResponse = await client.PostAsJsonAsync("/api/v1/auth/login", goodPayload, WebJson);
        Assert.Equal(HttpStatusCode.Unauthorized, lockedResponse.StatusCode);
    }

    [Fact]
    public async Task PostLogin_WithUnmappedExtraProperties_Returns400BadRequest()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        var payload = new
        {
            email = "valid@example.test",
            password = CustomerPassword,
            isAdmin = true // Extra unmapped property
        };

        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", payload, WebJson);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostRefresh_WithValidToken_RotatesTokenAndReturnsNewPair()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "refresh.test@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var loginResponse = await (await client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = "refresh.test@example.test",
            password = CustomerPassword
        }, WebJson)).Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);

        Assert.NotNull(loginResponse);
        var originalRefreshToken = loginResponse.RefreshToken;

        // Perform token refresh
        var refreshPayload = new { refreshToken = originalRefreshToken };
        using var refreshResponse = await client.PostAsJsonAsync("/api/v1/auth/refresh", refreshPayload, WebJson);

        Assert.Equal(HttpStatusCode.OK, refreshResponse.StatusCode);

        var refreshedTokens = await refreshResponse.Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);
        Assert.NotNull(refreshedTokens);
        Assert.NotEqual(originalRefreshToken, refreshedTokens.RefreshToken);
        Assert.False(string.IsNullOrWhiteSpace(refreshedTokens.AccessToken));

        // Check DB state: original token is revoked, new token is active
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tokenService = scope.ServiceProvider.GetRequiredService<ITokenService>();

        var oldHash = tokenService.ComputeHash(originalRefreshToken);
        var newHash = tokenService.ComputeHash(refreshedTokens.RefreshToken);

        var oldTokenEntity = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == oldHash);
        var newTokenEntity = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == newHash);

        Assert.NotNull(oldTokenEntity);
        Assert.NotNull(newTokenEntity);
        Assert.True(oldTokenEntity.IsRevoked);
        Assert.Equal(newHash, oldTokenEntity.ReplacedByTokenHash);
        Assert.True(newTokenEntity.IsActive);
    }

    [Fact]
    public async Task PostRefresh_WithRevokedToken_TriggersCompromiseDetection_AndRevokesAllTokens()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "reuse.detection@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var loginResponse = await (await client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = "reuse.detection@example.test",
            password = CustomerPassword
        }, WebJson)).Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);

        Assert.NotNull(loginResponse);
        var initialRefreshToken = loginResponse.RefreshToken;

        // Legitimate client refreshes once
        var firstRefresh = await (await client.PostAsJsonAsync("/api/v1/auth/refresh", new
        {
            refreshToken = initialRefreshToken
        }, WebJson)).Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);

        Assert.NotNull(firstRefresh);

        // Attacker attempts to replay initialRefreshToken which has already been rotated!
        using var attackResponse = await client.PostAsJsonAsync("/api/v1/auth/refresh", new
        {
            refreshToken = initialRefreshToken
        }, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, attackResponse.StatusCode);

        // Compromise detection: all active tokens for this user must now be revoked
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var activeTokens = await db.RefreshTokens
            .Where(t => t.UserId == user.Id && t.RevokedAtUtc == null)
            .ToListAsync();

        Assert.Empty(activeTokens);

        // Legitimate client can no longer use its second token either
        using var legitimateTry = await client.PostAsJsonAsync("/api/v1/auth/refresh", new
        {
            refreshToken = firstRefresh.RefreshToken
        }, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, legitimateTry.StatusCode);
    }

    [Fact]
    public async Task PostRefresh_WithExpiredToken_Returns401Unauthorized()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "expired.test@example.test", CustomerPassword);

        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tokenService = scope.ServiceProvider.GetRequiredService<ITokenService>();

        var rawToken = tokenService.GenerateRefreshToken();
        var expiredEntity = new CustomerRefreshToken
        {
            UserId = user.Id,
            TokenHash = tokenService.ComputeHash(rawToken),
            ExpiresAtUtc = DateTime.UtcNow.AddHours(-1),
            CreatedAtUtc = DateTime.UtcNow.AddDays(-15)
        };
        db.RefreshTokens.Add(expiredEntity);
        await db.SaveChangesAsync();

        using var client = host.CreateClient();
        using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new
        {
            refreshToken = rawToken
        }, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PostLogout_WithActiveToken_RevokesToken_AndReturns204NoContent()
    {
        using var host = new RegistrationTestHost();
        var user = await SeedUserAsync(host, "logout.test@example.test", CustomerPassword);

        using var client = host.CreateClient();
        var loginResponse = await (await client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            email = "logout.test@example.test",
            password = CustomerPassword
        }, WebJson)).Content.ReadFromJsonAsync<CustomerLoginResponse>(WebJson);

        Assert.NotNull(loginResponse);

        // Logout
        using var logoutResponse = await client.PostAsJsonAsync("/api/v1/auth/logout", new
        {
            refreshToken = loginResponse.RefreshToken
        }, WebJson);

        Assert.Equal(HttpStatusCode.NoContent, logoutResponse.StatusCode);

        // Check DB: token is revoked
        using var scope = host.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tokenService = scope.ServiceProvider.GetRequiredService<ITokenService>();

        var hash = tokenService.ComputeHash(loginResponse.RefreshToken);
        var tokenEntity = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == hash);

        Assert.NotNull(tokenEntity);
        Assert.True(tokenEntity.IsRevoked);

        // Subsequent refresh attempt fails
        using var refreshAttempt = await client.PostAsJsonAsync("/api/v1/auth/refresh", new
        {
            refreshToken = loginResponse.RefreshToken
        }, WebJson);

        Assert.Equal(HttpStatusCode.Unauthorized, refreshAttempt.StatusCode);
    }

    [Fact]
    public async Task PostLogout_WithUnknownToken_Returns204NoContent_Idempotently()
    {
        using var host = new RegistrationTestHost();
        using var client = host.CreateClient();

        using var response = await client.PostAsJsonAsync("/api/v1/auth/logout", new
        {
            refreshToken = "non-existent-refresh-token"
        }, WebJson);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    private static async Task<ApplicationUser> SeedUserAsync(
        RegistrationTestHost host, string email, string password)
    {
        using var scope = host.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var policy = scope.ServiceProvider.GetRequiredService<CustomerPasswordPolicy>();

        var prep = policy.PrepareForCreation(password);
        var user = new ApplicationUser
        {
            Id = Guid.NewGuid().ToString(),
            Email = email,
            UserName = userManager.NormalizeEmail(email),
            DisplayName = "Test Customer",
            EmailConfirmed = true,
            IsEnabled = true,
            LockoutEnabled = true
        };

        var result = await userManager.CreateAsync(user, prep.NormalizedPassword!);
        Assert.True(result.Succeeded);
        return user;
    }
}

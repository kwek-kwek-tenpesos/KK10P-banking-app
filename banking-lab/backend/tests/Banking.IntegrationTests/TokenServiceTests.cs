using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Text;
using Banking.Api.Features.Authentication;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace Banking.IntegrationTests;

public sealed class TokenServiceTests
{
    private readonly TokenService _tokenService;
    private readonly JwtOptions _options;

    public TokenServiceTests()
    {
        _options = new JwtOptions
        {
            SigningKey = "test-only-hmac-sha256-signing-key-banking-lab-at-least-32-chars-long!",
            Issuer = "BankingLabTest",
            Audience = "BankingTestAudience",
            AccessTokenLifetimeMinutes = 10,
            SessionInactivityDays = 15
        };

        _tokenService = new TokenService(Options.Create(_options));
    }

    [Fact]
    public void GenerateAccessToken_ProducesValidSignedJwtWithExpectedClaims()
    {
        var user = new ApplicationUser
        {
            Id = Guid.NewGuid().ToString(),
            Email = "customer@example.test",
            UserName = "CUSTOMER@EXAMPLE.TEST"
        };

        var session = new CustomerSession { UserId = user.Id, IdleExpiresAtUtc = DateTime.UtcNow.AddDays(15), AbsoluteExpiresAtUtc = DateTime.UtcNow.AddDays(90) };
        var issued = _tokenService.GenerateAccessToken(user, session);
        var jwtString = issued.Token;

        Assert.False(string.IsNullOrWhiteSpace(jwtString));

        var handler = new JwtSecurityTokenHandler();
        Assert.True(handler.CanReadToken(jwtString));

        var validationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey)),
            ValidateIssuer = true,
            ValidIssuer = _options.Issuer,
            ValidateAudience = true,
            ValidAudience = _options.Audience,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };

        var principal = handler.ValidateToken(jwtString, validationParameters, out var validatedToken);
        var jwt = Assert.IsType<JwtSecurityToken>(validatedToken);

        Assert.Equal(_options.Issuer, jwt.Issuer);
        Assert.Contains(_options.Audience, jwt.Audiences);
        Assert.Equal(user.Id, jwt.Subject);
        Assert.Contains(jwt.Claims, c => c.Type == "sid" && c.Value == session.Id.ToString());
        Assert.DoesNotContain(jwt.Claims, c => c.Type == JwtRegisteredClaimNames.Email);
        Assert.Equal(jwt.ValidTo, issued.ExpiresAtUtc);
        Assert.DoesNotContain(jwtString, issued.ToString());
        Assert.False(string.IsNullOrWhiteSpace(jwt.Id)); // jti
        Assert.True(jwt.ValidTo > DateTime.UtcNow.AddMinutes(9));
        Assert.True(jwt.ValidTo <= DateTime.UtcNow.AddMinutes(10));
    }

    [Fact]
    public void GenerateRefreshToken_GeneratesHighEntropyUrlSafeString()
    {
        var token1 = _tokenService.GenerateRefreshToken();
        var token2 = _tokenService.GenerateRefreshToken();

        Assert.False(string.IsNullOrWhiteSpace(token1));
        Assert.False(string.IsNullOrWhiteSpace(token2));
        Assert.NotEqual(token1, token2);

        // 32 bytes encoded as Base64Url is 43 characters (no padding)
        Assert.Equal(43, token1.Length);
        Assert.Equal(43, token2.Length);

        // URL safe characters only
        Assert.DoesNotContain("+", token1);
        Assert.DoesNotContain("/", token1);
        Assert.DoesNotContain("=", token1);
    }

    [Fact]
    public void GenerateAccessToken_ExpiredSessionHasSpecificOutcome_NotProgrammingFailure()
    {
        var user = new ApplicationUser { Id = "expired-test" };
        var session = new CustomerSession
        {
            UserId = user.Id,
            IdleExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1),
            AbsoluteExpiresAtUtc = DateTime.UtcNow.AddDays(1)
        };
        Assert.Throws<SessionExpiredException>(() => _tokenService.GenerateAccessToken(user, session));
    }

    [Fact]
    public void GenerateAccessToken_MismatchedOwnerStillThrowsProgrammingFailure()
    {
        var session = new CustomerSession
        {
            UserId = "another-owner",
            IdleExpiresAtUtc = DateTime.UtcNow.AddDays(1),
            AbsoluteExpiresAtUtc = DateTime.UtcNow.AddDays(90)
        };
        Assert.Throws<InvalidOperationException>(() => _tokenService.GenerateAccessToken(new ApplicationUser(), session));
    }

    [Fact]
    public void ComputeHash_ProducesDeterministicSha256Hex()
    {
        const string rawToken = "sample-test-refresh-token-12345";

        var hash1 = _tokenService.ComputeHash(rawToken);
        var hash2 = _tokenService.ComputeHash(rawToken);

        Assert.Equal(hash1, hash2);
        Assert.Equal(64, hash1.Length); // 256 bits = 32 bytes = 64 hex characters
        Assert.Equal(hash1.ToLowerInvariant(), hash1); // Lowercase hex

        var expectedHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken))).ToLowerInvariant();
        Assert.Equal(expectedHash, hash1);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void ComputeHash_WithNullOrWhitespace_ThrowsArgumentException(string? invalidToken)
    {
        Assert.ThrowsAny<ArgumentException>(() => _tokenService.ComputeHash(invalidToken!));
    }
}

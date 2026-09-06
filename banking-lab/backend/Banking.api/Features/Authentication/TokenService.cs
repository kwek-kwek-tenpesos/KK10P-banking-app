using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Banking.Api.Features.Authentication;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string SigningKey { get; set; } = string.Empty;
    public string Issuer { get; set; } = "BankingLab";
    public string Audience { get; set; } = "BankingMobileApp";
    public int AccessTokenLifetimeMinutes { get; set; } = 10;
    public int SessionInactivityDays { get; set; } = 15;
    public int SessionAbsoluteLifetimeDays { get; set; } = 90;
}

public sealed class TokenService(IOptions<JwtOptions> options) : ITokenService
{
    private readonly JwtOptions _options = options.Value;

    public IssuedAccessToken GenerateAccessToken(ApplicationUser user, CustomerSession session)
    {
        ArgumentNullException.ThrowIfNull(user);
        ArgumentNullException.ThrowIfNull(session);
        var now = DateTime.UtcNow;
        if (session.UserId != user.Id)
            throw new InvalidOperationException("Cannot issue access for a mismatched session.");
        if (!session.IsActiveAt(now)) throw new SessionExpiredException();

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            new("sid", session.Id.ToString()),
            new(ClaimTypes.NameIdentifier, user.Id)
        };

        var deadline = now.AddMinutes(_options.AccessTokenLifetimeMinutes);
        if (session.AccessDeadline < deadline) deadline = session.AccessDeadline;
        var expires = DateTimeOffset.FromUnixTimeSeconds(new DateTimeOffset(deadline).ToUnixTimeSeconds()).UtcDateTime;
        // JWT dates have whole-second precision. Do not create exp <= nbf when
        // a session has less than one representable second remaining.
        if (expires <= now) throw new SessionExpiredException();

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = expires,
            NotBefore = now,
            IssuedAt = now,
            Issuer = _options.Issuer,
            Audience = _options.Audience,
            SigningCredentials = credentials
        };

        var handler = new JwtSecurityTokenHandler();
        var token = handler.CreateToken(tokenDescriptor);
        return new IssuedAccessToken(handler.WriteToken(token), expires);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes = RandomNumberGenerator.GetBytes(32);
        return Base64UrlEncoder.Encode(randomBytes);
    }

    public string ComputeHash(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        var bytes = Encoding.UTF8.GetBytes(token);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}

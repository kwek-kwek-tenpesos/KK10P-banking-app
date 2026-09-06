namespace Banking.Api.Features.Authentication;

public interface ITokenService
{
    IssuedAccessToken GenerateAccessToken(ApplicationUser user, CustomerSession session);
    string GenerateRefreshToken();
    string ComputeHash(string token);
}

public sealed record IssuedAccessToken(string Token, DateTime ExpiresAtUtc)
{
    public int RemainingSeconds => Math.Max(0, (int)Math.Floor((ExpiresAtUtc - DateTime.UtcNow).TotalSeconds));
    public override string ToString() => "IssuedAccessToken { Redacted }";
}

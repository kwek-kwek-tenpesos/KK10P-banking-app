using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Banking.Api.Features.Authentication;

public sealed class CustomerSessionService(
    AppDbContext database, UserManager<ApplicationUser> users, ITokenService tokens,
    IOptions<JwtOptions> options, ILogger<CustomerSessionService> logger)
{
    public async Task<TokenRefreshResult> RefreshAsync(TokenRefreshRequest request, CancellationToken ct = default)
    {
        var raw = request.RefreshToken;
        if (string.IsNullOrWhiteSpace(raw) || raw.Length > 512) return TokenRefreshResult.InvalidToken();
        Guid? sessionId = null;
        try
        {
            var token = await database.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == tokens.ComputeHash(raw), ct);
            if (token?.SessionId is not Guid id) return TokenRefreshResult.InvalidToken();
            sessionId = id;
            var session = await database.CustomerSessions.SingleOrDefaultAsync(s => s.Id == id, ct);
            var now = DateTime.UtcNow;
            if (session is null || session.UserId != token.UserId || !session.IsActiveAt(now))
                return TokenRefreshResult.InvalidToken();

            // Replay terminates this family, not unrelated logins belonging to the user.
            if (token.IsRevoked)
                return await RevokeAsync(id, ct) ? TokenRefreshResult.InvalidToken() : TokenRefreshResult.Unavailable();
            if (token.ExpiresAtUtc <= now) return TokenRefreshResult.InvalidToken();
            var user = await users.FindByIdAsync(session.UserId);
            if (user is null || !user.IsEnabled || !user.EmailConfirmed
                || user.SecurityStamp != session.SecurityStamp || await users.IsLockedOutAsync(user))
                return TokenRefreshResult.InvalidToken();

            // Persisted per-session budget; atomic with rotation, shared across API processes.
            if (now >= session.RefreshWindowStartedAtUtc.AddMinutes(1))
            {
                session.RefreshWindowStartedAtUtc = now;
                session.RefreshWindowCount = 0;
            }
            if (session.RefreshWindowCount >= 30) return TokenRefreshResult.RateLimited();
            session.RefreshWindowCount++;
            session.LastActivityAtUtc = now;
            session.IdleExpiresAtUtc = now.AddDays(options.Value.SessionInactivityDays);
            if (session.IdleExpiresAtUtc > session.AbsoluteExpiresAtUtc)
                session.IdleExpiresAtUtc = session.AbsoluteExpiresAtUtc;
            session.Version = Guid.NewGuid();

            var replacement = tokens.GenerateRefreshToken();
            var hash = tokens.ComputeHash(replacement);
            token.Revoke(hash);
            database.RefreshTokens.Add(new CustomerRefreshToken
            {
                UserId = user.Id,
                SessionId = id,
                TokenHash = hash,
                CreatedAtUtc = now,
                ExpiresAtUtc = session.AccessDeadline
            });
            // PostgreSQL SaveChanges transaction: session compare-and-swap, consumption,
            // and replacement insertion either all commit or all roll back.
            await database.SaveChangesAsync(ct);
            var access = tokens.GenerateAccessToken(user, session);
            return TokenRefreshResult.Success(new(access.Token, replacement, "Bearer", access.RemainingSeconds));
        }
        catch (SessionExpiredException)
        {
            return TokenRefreshResult.InvalidToken();
        }
        catch (DbUpdateConcurrencyException)
        {
            database.ChangeTracker.Clear();
            // Two uses of the same token are indistinguishable from theft: fail closed.
            return sessionId is Guid id && await RevokeAsync(id, ct)
                ? TokenRefreshResult.InvalidToken() : TokenRefreshResult.Unavailable();
        }
        catch (Exception ex) when (AuthenticationDependencyFailure.Is(ex))
        {
            logger.LogWarning("Session refresh dependency failed.");
            return TokenRefreshResult.Unavailable();
        }
    }

    public async Task<bool> LogoutAsync(TokenRevocationRequest request, CancellationToken ct = default)
    {
        var raw = request.RefreshToken;
        if (string.IsNullOrWhiteSpace(raw) || raw.Length > 512) return true;
        try
        {
            var token = await database.RefreshTokens.AsNoTracking()
                .SingleOrDefaultAsync(t => t.TokenHash == tokens.ComputeHash(raw), ct);
            // A rotated ancestor can still terminate its own session, including descendants.
            return token?.SessionId is not Guid id || await RevokeAsync(id, ct);
        }
        catch (Exception ex) when (AuthenticationDependencyFailure.Is(ex))
        {
            logger.LogWarning("Session logout dependency failed.");
            return false;
        }
    }

    private async Task<bool> RevokeAsync(Guid id, CancellationToken ct)
    {
        for (var attempt = 0; attempt < 3; attempt++)
        {
            database.ChangeTracker.Clear();
            try
            {
                var session = await database.CustomerSessions.SingleOrDefaultAsync(s => s.Id == id, ct);
                if (session is null || session.RevokedAtUtc is not null) return true;
                session.RevokedAtUtc = DateTime.UtcNow;
                session.Version = Guid.NewGuid();
                var active = await database.RefreshTokens.Where(t => t.SessionId == id && t.RevokedAtUtc == null).ToListAsync(ct);
                foreach (var token in active) token.Revoke();
                await database.SaveChangesAsync(ct);
                return true;
            }
            catch (DbUpdateConcurrencyException) { /* Reload and retry; never restore a stale session. */ }
            catch (Exception ex) when (AuthenticationDependencyFailure.Is(ex))
            {
                logger.LogWarning("Session revocation persistence failed.");
                return false;
            }
        }
        return false;
    }
}

using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Banking.Api.Features.Authentication;

public sealed class CustomerLoginService(
    UserManager<ApplicationUser> users,
    CustomerPasswordPolicy passwords,
    ITokenService tokenService,
    AppDbContext database,
    ILogger<CustomerLoginService> logger,
    IOptions<JwtOptions> options,
    CustomerSessionService sessions)
{
    private static readonly string DummyPasswordHash =
        new PasswordHasher<ApplicationUser>().HashPassword(
            new ApplicationUser(), "BankingLabDummyPasswordForTimingMitigation123!");

    public async Task<CustomerLoginResult> LoginAsync(
        CustomerLoginRequest request, CancellationToken cancellationToken = default)
    {
        try { return await LoginCoreAsync(request, cancellationToken); }
        catch (SessionExpiredException) { return CustomerLoginResult.InvalidCredentials(); }
        catch (Exception exception) when (AuthenticationDependencyFailure.Is(exception))
        {
            logger.LogWarning("Customer login dependency failed.");
            return CustomerLoginResult.Unavailable();
        }
    }

    private async Task<CustomerLoginResult> LoginCoreAsync(
        CustomerLoginRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        var email = request.Email?.Trim();
        var password = request.Password;

        if (string.IsNullOrWhiteSpace(email) || email.Length > ApplicationUser.MaximumEmailLength
            || string.IsNullOrEmpty(password))
        {
            return CustomerLoginResult.InvalidCredentials();
        }

        ApplicationUser? user = null;
        try
        {
            user = await users.FindByEmailAsync(email);
        }
        catch (ArgumentException)
        {
            return CustomerLoginResult.InvalidCredentials();
        }
        catch (Exception exception) when (
            AuthenticationDependencyFailure.Is(exception))
        {
            logger.LogWarning("Customer login lookup failed.");
            return CustomerLoginResult.Unavailable();
        }

        // Reduce the obvious missing/ineligible-user timing shortcut. Database
        // and other branch work still differ; this is not a constant-time guarantee.
        if (user is null || !user.IsEnabled || !user.EmailConfirmed
            || user.PasswordHash is null || await users.IsLockedOutAsync(user))
        {
            var dummyPrep = passwords.PrepareForVerification(password);
            _ = users.PasswordHasher.VerifyHashedPassword(
                new ApplicationUser(),
                DummyPasswordHash,
                dummyPrep.NormalizedPassword ?? string.Empty);

            return CustomerLoginResult.InvalidCredentials();
        }

        var prepared = passwords.PrepareForVerification(password);
        if (!prepared.Succeeded)
        {
            return (await users.AccessFailedAsync(user)).Succeeded
                ? CustomerLoginResult.InvalidCredentials() : CustomerLoginResult.Unavailable();
        }

        var verificationResult = users.PasswordHasher.VerifyHashedPassword(
            user,
            user.PasswordHash ?? string.Empty,
            prepared.NormalizedPassword!);

        if (verificationResult == PasswordVerificationResult.Failed)
        {
            return (await users.AccessFailedAsync(user)).Succeeded
                ? CustomerLoginResult.InvalidCredentials() : CustomerLoginResult.Unavailable();
        }

        // Successful authentication: reset failed access counter
        if (!(await users.ResetAccessFailedCountAsync(user)).Succeeded)
            return CustomerLoginResult.Unavailable();

        var rawRefreshToken = tokenService.GenerateRefreshToken();
        var tokenHash = tokenService.ComputeHash(rawRefreshToken);
        var now = DateTime.UtcNow;
        var session = new CustomerSession
        {
            UserId = user.Id,
            SecurityStamp = user.SecurityStamp,
            CreatedAtUtc = now,
            LastActivityAtUtc = now,
            IdleExpiresAtUtc = now.AddDays(options.Value.SessionInactivityDays),
            AbsoluteExpiresAtUtc = now.AddDays(options.Value.SessionAbsoluteLifetimeDays),
            RefreshWindowStartedAtUtc = now
        };

        var refreshToken = new CustomerRefreshToken
        {
            UserId = user.Id,
            SessionId = session.Id,
            TokenHash = tokenHash,
            ExpiresAtUtc = session.AccessDeadline,
            CreatedAtUtc = now
        };

        try
        {
            database.CustomerSessions.Add(session);
            database.RefreshTokens.Add(refreshToken);
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (Exception exception) when (
            AuthenticationDependencyFailure.Is(exception))
        {
            logger.LogWarning("Customer login token persistence failed.");
            return CustomerLoginResult.Unavailable();
        }

        var accessToken = tokenService.GenerateAccessToken(user, session);
        return CustomerLoginResult.Success(new CustomerLoginResponse(
            AccessToken: accessToken.Token,
            RefreshToken: rawRefreshToken,
            TokenType: "Bearer",
            ExpiresInSeconds: accessToken.RemainingSeconds));
    }

    public Task<TokenRefreshResult> RefreshAsync(
        TokenRefreshRequest request, CancellationToken cancellationToken = default) =>
        sessions.RefreshAsync(request, cancellationToken);

    public Task<bool> LogoutAsync(
        TokenRevocationRequest request, CancellationToken cancellationToken = default) =>
        sessions.LogoutAsync(request, cancellationToken);
}

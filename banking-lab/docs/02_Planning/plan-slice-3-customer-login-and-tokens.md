# Implementation Plan: Slice 3 Customer Login, JWT & Rotating Refresh Tokens (BL-SEC-005)

- Review status (2026-09-04): Historical initial implementation plan, superseded for policy by the [approved authentication repair plan](plan-authentication-repair.md): 10-minute access, 15-day inactivity, 90-day absolute expiry, generic login failures and independently revocable session families. Implementation is tracked in task.md; approval does not mean every repair is complete. Preserve this original plan as a record, not current implementation guidance.

Implement secure customer authentication (`POST /api/v1/auth/login`), short-lived JWT access tokens, cryptographically secure rotating refresh tokens with hashed persistence, session refresh (`POST /api/v1/auth/refresh`), logout, and token reuse detection.

## User Review Required

> [!IMPORTANT]
> **Database Migration Approval**: In compliance with repository boundaries, adding the `CustomerRefreshTokens` table requires an approved EF Core migration applied to the PostgreSQL container.
>
> **Token Security Architecture**:
> 1. **Access Tokens**: Short-lived (15 minutes), signed using HMAC-SHA256, carrying minimal claims (`sub` = UserId, `email`, `jti`).
> 2. **Refresh Tokens**: Cryptographically random (256-bit entropy). **Only SHA-256 hashes are persisted in the database**; plain tokens are never stored at rest (preventing credential dumping per OWASP A02 & API2).
> 3. **Token Rotation & Reuse Detection**: Every refresh invalidates the current token and issues a new pair. If an already-rotated token is ever re-used, the entire token family is immediately revoked, detecting stolen credentials.
> 4. **Anti-Enumeration & Lockout**: Failed logins return generic `401 Unauthorized` without revealing account existence. Consecutive failed attempts trigger ASP.NET Identity account lockout.

## Proposed Changes

### Data & Database Infrastructure (`banking-lab/backend/Banking.api` & `banking-lab/infrastructure`)

#### [NEW] [CustomerRefreshToken.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/CustomerRefreshToken.cs)
- Entity representing an active or revoked refresh token:
  - `Id` (Guid/long)
  - `UserId` (foreign key to `AspNetUsers`)
  - `TokenHash` (SHA-256 hash string, unique index)
  - `ExpiresAtUtc` (DateTime)
  - `CreatedAtUtc` (DateTime)
  - `RevokedAtUtc` (DateTime?)
  - `ReplacedByTokenHash` (string?)
  - Helper properties: `IsExpired`, `IsRevoked`, `IsActive`.

#### [MODIFY] [AppDbContext.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/infrastructure/temporary/AppDbContext.cs)
- Register `DbSet<CustomerRefreshToken> RefreshTokens`.
- Configure `TokenHash` as unique index and foreign key cascade to `ApplicationUser`.

#### [EXECUTE] EF Core Migration
- Generate migration `AddCustomerRefreshTokens`.
- Apply migration to PostgreSQL container via `dotnet ef database update`.

---

### Backend Authentication Domain (`banking-lab/backend/Banking.api/Features/Authentication`)

#### [NEW] [CustomerLoginContracts.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/CustomerLoginContracts.cs)
- DTOs with `[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]`:
  - `CustomerLoginRequest(Email, Password)`
  - `CustomerLoginResponse(AccessToken, RefreshToken, TokenType, ExpiresInSeconds)`
  - `TokenRefreshRequest(RefreshToken)`
  - `TokenRevocationRequest(RefreshToken)`

#### [NEW] [ITokenService.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/ITokenService.cs) & [TokenService.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/TokenService.cs)
- Generates signed JWT access tokens with expiration and claims.
- Generates 256-bit cryptographically random Base64Url refresh tokens.
- Computes SHA-256 hash for database lookups and storage.

#### [NEW] [CustomerLoginService.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/CustomerLoginService.cs)
- Orchestrates:
  1. User lookup by normalized email (anti-enumeration: returns generic error if not found).
  2. Lockout verification (`IsLockedOutAsync`).
  3. Password verification using `UserManager` and `CustomerPasswordPolicy`.
  4. Access failed count tracking (`AccessFailedAsync` / `ResetAccessFailedCountAsync`).
  5. Session generation: creates JWT and records refresh token hash.
  6. Token refresh with rotation: revokes presented token, issues new token pair.
  7. Reuse detection: if a revoked token is presented, revokes all active tokens for that user.
  8. Logout / Revocation: marks token as revoked.

#### [MODIFY] [Program.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Program.cs)
- Register JWT Bearer authentication and token validation parameters (`Issuer`, `Audience`, `SigningKey`).
- Map Minimal API endpoints:
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/refresh`
  - `POST /api/v1/auth/logout`

---

### Backend Integration Tests (`banking-lab/backend/tests/Banking.IntegrationTests`)

#### [NEW] [CustomerLoginEndpointTests.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/tests/Banking.IntegrationTests/CustomerLoginEndpointTests.cs)
- Test valid login returns 200 OK with valid JWT and refresh token.
- Test invalid email returns 401 Unauthorized (anti-enumeration).
- Test invalid password returns 401 Unauthorized and increments failed access counter.
- Test account lockout after consecutive failures.
- Test refreshing an active token returns new access + refresh tokens and revokes old token.
- Test token reuse triggers family revocation (reuse detection).
- Test logout revokes token.

---

## Step-by-Step Logic (Pseudocode)

```text
FUNCTION CustomerLogin(request):
    user = AWAIT userManager.FindByEmailAsync(request.Email.Trim())
    IF user IS NULL OR NOT user.IsEnabled:
        // Anti-enumeration: constant-time equivalent response
        RETURN Unauthorized("Invalid email or password.")

    IF AWAIT userManager.IsLockedOutAsync(user):
        RETURN Locked("Account is temporarily locked due to multiple failed login attempts.")

    preparedPassword = passwordPolicy.PrepareForVerification(request.Password)
    passwordResult = userManager.PasswordHasher.VerifyHashedPassword(
        user, user.PasswordHash, preparedPassword.NormalizedPassword)

    IF passwordResult == Failed:
        AWAIT userManager.AccessFailedAsync(user)
        RETURN Unauthorized("Invalid email or password.")

    AWAIT userManager.ResetAccessFailedCountAsync(user)

    accessToken = tokenService.GenerateAccessToken(user)
    rawRefreshToken = tokenService.GenerateRefreshToken()
    tokenHash = tokenService.ComputeHash(rawRefreshToken)

    refreshToken = NEW CustomerRefreshToken(
        UserId = user.Id,
        TokenHash = tokenHash,
        ExpiresAtUtc = UtcNow.AddDays(14),
        CreatedAtUtc = UtcNow
    )
    AWAIT dbContext.RefreshTokens.AddAsync(refreshToken)
    AWAIT dbContext.SaveChangesAsync()

    RETURN Ok(CustomerLoginResponse(accessToken, rawRefreshToken, "Bearer", 900))

FUNCTION RefreshSession(request):
    tokenHash = tokenService.ComputeHash(request.RefreshToken)
    existing = AWAIT dbContext.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == tokenHash)

    IF existing IS NULL:
        RETURN Unauthorized("Invalid refresh token.")

    IF existing.IsRevoked:
        // Compromise indicator: revoke all tokens for this user
        AWAIT RevokeAllTokensForUser(existing.UserId)
        RETURN Unauthorized("Token compromise detected. Please log in again.")

    IF existing.IsExpired:
        RETURN Unauthorized("Refresh token has expired. Please log in again.")

    user = AWAIT userManager.FindByIdAsync(existing.UserId)
    newRawToken = tokenService.GenerateRefreshToken()
    newTokenHash = tokenService.ComputeHash(newRawToken)

    existing.RevokedAtUtc = UtcNow
    existing.ReplacedByTokenHash = newTokenHash

    newRefreshToken = NEW CustomerRefreshToken(
        UserId = user.Id,
        TokenHash = newTokenHash,
        ExpiresAtUtc = UtcNow.AddDays(14)
    )
    AWAIT dbContext.RefreshTokens.AddAsync(newRefreshToken)
    AWAIT dbContext.SaveChangesAsync()

    newAccessToken = tokenService.GenerateAccessToken(user)
    RETURN Ok(CustomerLoginResponse(newAccessToken, newRawToken, "Bearer", 900))
```

---

## Verification Plan

### Automated Tests
- Run `dotnet test` on solution:
  - `CustomerLoginEndpointTests`:
    - Successful login $\rightarrow$ 200 OK with valid JWT & refresh token.
    - Bad credentials $\rightarrow$ 401 Unauthorized (anti-enumeration).
    - Lockout behavior $\rightarrow$ consecutive failed attempts lock out account.
    - Token rotation $\rightarrow$ `/refresh` issues new token and revokes old.
    - Token reuse detection $\rightarrow$ presenting revoked token revokes session family.
    - Logout $\rightarrow$ `/logout` revokes active token.
  - Full backend suite (92+ tests) passing.
  - Full mobile suite (54 tests) passing.

### Manual & Database Verification
- Confirm EF migration `AddCustomerRefreshTokens` created and applied to PostgreSQL container.
- Query `CustomerRefreshTokens` table in PostgreSQL to verify that only SHA-256 hashes are stored, not plaintext tokens.

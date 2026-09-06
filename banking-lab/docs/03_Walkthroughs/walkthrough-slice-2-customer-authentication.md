# Walkthrough: Slice 2 Customer Authentication & Endpoint Delivery

- Date: 2026-09-04
- Feature: Slice 2 Backend Customer Registration Endpoint & Database Migration
- Status: Endpoint delivery recorded as complete; historical 92/92 test result, not end-to-end registration verification
- Review correction (2026-09-04): Default runtime registration remains unavailable because verification delivery is unconfigured. Tests replace delivery/persistence. Database and test results below are historical records, not checks rerun during the [repair planning step](../02_Planning/plan-authentication-repair.md).

---

## 1. What Was Delivered

1. **Applied EF Core Identity Migration**:
   - Migration `20260903171002_AddCustomerIdentity` was applied to the live PostgreSQL 17 container in Docker.
   - Verified creation of all 7 ASP.NET Identity tables (`AspNetUsers`, `AspNetRoles`, `AspNetUserClaims`, `AspNetUserLogins`, `AspNetUserRoles`, `AspNetUserTokens`, `AspNetRoleClaims`) and the custom SQL check constraint `CK_AspNetUsers_NormalizedLogin`.

2. **Wired Customer Registration Endpoint**:
   - Mapped `POST /api/v1/auth/register` in `banking-lab/backend/Banking.api/Program.cs`.
   - Connected incoming JSON requests to `CustomerRegistrationService.RegisterAsync`.
   - Handled outcome mapping:
     - `Accepted` $\rightarrow$ `202 Accepted`
     - `Invalid` $\rightarrow$ `400 Bad Request` with field-level validation `ProblemDetails`
     - `Unavailable` $\rightarrow$ `503 Service Unavailable` with `ProblemDetails`

3. **Authoring Comprehensive Integration Tests**:
   - Created `banking-lab/backend/tests/Banking.IntegrationTests/RegistrationEndpointTests.cs` using `WebApplicationFactory<Program>`.
   - Verified valid creation, invalid email handling, weak/blocklisted password rejection, anti-enumeration behavior on duplicates, delivery failure recovery, and unmapped property (mass assignment) rejection.
   - Updated existing guard test in `CustomerRegistrationTests.cs`.
   - **All 92 integration tests passed**.

---

## 2. Core Logic Flow

```text
HTTP Client (e.g. Flutter App / Mobile)
        │
        │  POST /api/v1/auth/register { email, password, displayName }
        ▼
[ Program.cs Endpoint ]
        │  (Validates JSON structure, rejects unmapped fields)
        ▼
[ CustomerRegistrationService.RegisterAsync ]
        │
        ├─► [ CustomerUserValidator ] (Checks email syntax, lengths, Unicode normalization)
        ├─► [ CustomerPasswordPolicy ] (15-128 NFC Unicode code points; seven-entry initial blocklist)
        │
        ├─► [ Verification configured? ] (Default: no -> 503, no user created)
        │
        ├─► [ UserManager.CreateAsync ] (ASP.NET Identity PBKDF2 password hashing)
        │     - If duplicate email -> Silently catches conflict & returns Accepted (anti-enumeration)
        │
        └─► [ ICustomerVerificationDelivery ] (Delivery boundary; real transport not implemented)
              - Configured path returns generic 202; it does not confirm email delivery or log in
```

---

## 3. Key Architectural & Security Concepts

### 1. Anti-Enumeration (User Enumeration Defense)
- **Concept**: A security vulnerability where attackers submit lists of emails to an endpoint (such as registration or password reset) and determine whether accounts exist based on whether the server returns `409 Conflict` vs `201 Created`.
- **In Banking Lab**: When an existing email is submitted to `/api/v1/auth/register`, the service catches the duplicate constraint and returns `202 Accepted` with `"If registration can proceed, check your email for the next step."` No account presence is disclosed.

### 2. Mass Assignment Rejection (OWASP API3)
- **Concept**: A vulnerability where a client sends additional, unexpected JSON fields (like `isAdmin: true` or `emailConfirmed: true`) that automatically bind to an internal model.
- **In Banking Lab**: `CustomerRegistrationRequest` is decorated with `[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]` and strictly decoupled from the EF Core `ApplicationUser` entity. Any extraneous properties immediately fail with HTTP 400.

### 3. Database Check Constraints (`CK_AspNetUsers_NormalizedLogin`)
- **Concept**: Engine-enforced database invariants that prevent data corruption or inconsistency even if application code is modified or bypassed.
- **In Banking Lab**: In `AppDbContext.cs`, we enforce `"NormalizedUserName" = "NormalizedEmail"`. This prevents the two stored login identifiers from diverging. It does not prevent visually similar Unicode identifiers (homographs).

---

## 4. Exact Repository Paths & Customization Points

| Item | Path |
| :--- | :--- |
| **Endpoint Definition** | [`banking-lab/backend/Banking.api/Program.cs`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Program.cs) |
| **Registration Service** | [`banking-lab/backend/Banking.api/Features/Authentication/CustomerRegistrationService.cs`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/CustomerRegistrationService.cs) |
| **Password Policy** | [`banking-lab/backend/Banking.api/Features/Authentication/CustomerPasswordPolicy.cs`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Features/Authentication/CustomerPasswordPolicy.cs) |
| **Integration Tests** | [`banking-lab/backend/tests/Banking.IntegrationTests/RegistrationEndpointTests.cs`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/tests/Banking.IntegrationTests/RegistrationEndpointTests.cs) |
| **EF Identity Migration** | [`banking-lab/backend/Banking.api/Migrations/20260903171002_AddCustomerIdentity.cs`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Migrations/20260903171002_AddCustomerIdentity.cs) |

---

## 5. Verified Test Results

Executed non-destructive test suite via `dotnet test`:
```text
Passed!  - Failed:     0, Passed:    92, Skipped:     0, Total:    92, Duration: 1 s - Banking.IntegrationTests.dll (net10.0)
```
Live PostgreSQL tables verified via Docker psql:
```text
 public | AspNetRoleClaims      | table | banking_app
 public | AspNetRoles           | table | banking_app
 public | AspNetUserClaims      | table | banking_app
 public | AspNetUserLogins      | table | banking_app
 public | AspNetUserRoles       | table | banking_app
 public | AspNetUserTokens      | table | banking_app
 public | AspNetUsers           | table | banking_app
 public | SetupProbes           | table | banking_app
 public | __EFMigrationsHistory | table | banking_app
```

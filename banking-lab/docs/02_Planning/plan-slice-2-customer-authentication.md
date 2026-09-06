# Implementation Plan: Slice 2 Customer Authentication & Security Gates

Deliver the public customer registration HTTP endpoint, verify and apply the EF Core Identity database migration in PostgreSQL, validate via automated integration tests, and schedule an OWASP ZAP baseline security scan.

## User Review Required

> [!IMPORTANT]
> **Database Migration Approval**: Per repository rules, database migrations require explicit approval. This plan includes applying migration `20260903171002_AddCustomerIdentity` to create the standard ASP.NET Identity tables with our custom normalization constraints (`CK_AspNetUsers_NormalizedLogin`).
>
> **Security Behavior (Anti-Enumeration)**: In compliance with OWASP recommendations, submitting an existing email address returns `202 Accepted` with a generic message (`"If registration can proceed, check your email for the next step."`) rather than `409 Conflict`, completely mitigating account enumeration attacks.

## Proposed Changes

### Backend API (`banking-lab/backend/Banking.api`)

#### [MODIFY] [Program.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/Banking.api/Program.cs)
- Map `POST /api/v1/auth/register` endpoint using Minimal APIs.
- Bind incoming payload to `CustomerRegistrationRequest`.
- Invoke `CustomerRegistrationService.RegisterAsync(...)`.
- Map outcomes cleanly to HTTP status codes:
  - `CustomerRegistrationOutcome.Accepted` -> `Results.Accepted(..., result)` (`202 Accepted`)
  - `CustomerRegistrationOutcome.Invalid` -> `Results.ValidationProblem(...)` (`400 Bad Request`)
  - `CustomerRegistrationOutcome.Unavailable` -> `Results.Problem(...)` (`503 Service Unavailable`)
- Redact sensitive data from logs; enforce JSON unmapped property rejection (preventing mass assignment per OWASP API3).

---

### Backend Integration Tests (`banking-lab/backend/tests/Banking.IntegrationTests`)

#### [NEW] [RegistrationEndpointTests.cs](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/backend/tests/Banking.IntegrationTests/RegistrationEndpointTests.cs)
- Test HTTP interactions against `WebApplicationFactory<Program>`.
- Verify `202 Accepted` on valid submission.
- Verify `400 Bad Request` with field-keyed validation dictionary when email or password violate policy.
- Verify `202 Accepted` when submitting duplicate emails (anti-enumeration).
- Verify `503 Service Unavailable` when verification delivery is unconfigured.

---

### Database Infrastructure (`banking-lab/infrastructure`)

#### [EXECUTE] PostgreSQL Identity Migration
- Ensure Docker Compose PostgreSQL service is healthy.
- Apply migration `20260903171002_AddCustomerIdentity` to `banking_lab` database.
- Verify table existence and check constraint `CK_AspNetUsers_NormalizedLogin`.

---

### Post-Slice Security Gate (OWASP ZAP)

#### [VERIFY] OWASP ZAP Baseline API Scan
- Configure ZAP API scan against the running API (`/api/v1/auth/register` and `/api/v1/system/info`).
- Fuzz input parameters for SQL injection, oversized payloads, and unhandled Unicode exceptions.
- Ensure zero High or Medium severity vulnerabilities.

---

## Step-by-Step Logic (Pseudocode)

```text
FUNCTION MapCustomerRegistrationEndpoint(app):
    app.MapPost("/api/v1/auth/register", ASYNC (
        CustomerRegistrationRequest request,
        CustomerRegistrationService registrationService,
        CancellationToken cancellationToken) =>
    {
        result = AWAIT registrationService.RegisterAsync(request, cancellationToken)

        MATCH result.Outcome:
            CASE Accepted:
                RETURN Results.Accepted(uri: null, value: result)
            CASE Invalid:
                RETURN Results.ValidationProblem(
                    errors: result.Errors,
                    detail: result.Message,
                    statusCode: 400)
            CASE Unavailable:
                RETURN Results.Problem(
                    detail: result.Message,
                    statusCode: 503)
    })
    .WithName("RegisterCustomer")
    .Produces<CustomerRegistrationResult>(StatusCodes.Status202Accepted)
    .ProducesValidationProblem(StatusCodes.Status400BadRequest)
    .ProducesProblem(StatusCodes.Status503ServiceUnavailable)
```

---

## Verification Plan

### Automated Tests
- Run integration tests via test host:
  - `RegistrationEndpointTests` (verifying HTTP status codes, JSON shapes, and anti-enumeration behavior).
  - Existing suite (`CustomerRegistrationTests`, `CustomerIdentityTests`, `CustomerPasswordPolicyTests`, `AppDbContextModelTests`).

### Manual & Infrastructure Verification
- Verify Docker PostgreSQL service status.
- Confirm EF migration `20260903171002_AddCustomerIdentity` applied successfully in database.
- Execute OWASP ZAP automated baseline API scan using Docker or local ZAP CLI and inspect the generated report.

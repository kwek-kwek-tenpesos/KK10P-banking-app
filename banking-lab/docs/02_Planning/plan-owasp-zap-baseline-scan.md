# Plan: OWASP ZAP OpenAPI Security Scanning (BL-QA-007 / BL-SEC-005)

- Status: Gate A and Gate B completed on 2026-09-09. Gate B's High SQL-injection alert was reproduced with its exact payloads and classified as a false positive; the disposable target was removed and the shared API/database boundary remained intact.
- Current feature gate: [Slice 5 internal transfer API](plan-kk10p-slice-5-internal-transfer-api.md).
- Target: The ASP.NET Core Development/Testing API described by its generated OpenAPI document.

## 1. Decision

Use ZAP at two points:

1. **Before Slice 5 (completed 2026-09-09):** run the existing guarded script in safe mode (`-S`). Its synthetic OpenAPI definition contains only `GET /api/v1/system/info`, so this records passive/header findings without claiming whole-API coverage and does not block implementation.
2. **After Slice 5 (required exit gate):** run safe mode first, confirm endpoint discovery and authentication, then run an explicitly approved active API scan against an isolated database. If only one scan is practical, run this post-Slice-5 gate.

The post-Slice-5 ZAP gate should cover every route published in the real OpenAPI definition rather than maintain a fragile hand-written endpoint list. It complements unit/integration tests and manual authorization review; it cannot prove ownership, financial conservation, idempotency, concurrency, or business-limit correctness.

## 2. Safety Boundary

- Never scan the shared Chris/Gio `banking_lab` database, a production target, or a future public Cloudflare hostname with active rules.
- Start a dedicated API instance connected to an exact disposable database such as `banking_lab_zap_test` with fake scanner identities, sessions, accounts, and funds.
- Validate the target host, OpenAPI server URLs, redirects, database name, and loopback/private boundary before any scan.
- Safe mode skips the active scanner, but importing an API can still send requests. The current pre-Slice-5 script avoids side effects by generating a one-route GET-only definition; the future whole-API scan must use disposable state.
- Pulling `ghcr.io/zaproxy/zaproxy:stable`, creating/deleting the disposable database, and running either scan remain separate explicit-approval actions.
- Scanner credentials/tokens come from temporary environment variables or an ignored local context; never commit or print them.
- Scan reports may contain URLs, payload samples, and identifiers. Store raw HTML/JSON/Markdown under an ignored artifact directory and only commit a sanitized summary after review.

## 3. Coverage

The OpenAPI document must expose all routes mapped in the selected Development/Testing build, including:

- system/health-facing API routes represented in the document;
- customer registration, verification, login, refresh, logout, and session-related routes;
- customer account and balance routes;
- Development funding routes when enabled in the isolated scan environment;
- Slice 5 internal transfer after implementation.

Protected routes require a tested ZAP authentication context. Validate that ZAP remains logged in and actually reaches authenticated responses; a collection of `401` results is not authenticated coverage.

## 4. Planned Artifacts

| Path | Responsibility |
| --- | --- |
| `banking-lab/scripts/run-zap-scan.ps1` | **Modify later:** preserve the current preview/acknowledgement and local-target guards; add an explicitly selected, disposable-only authenticated mode without weakening the existing GET-only mode |
| `banking-lab/scripts/zap-scan-policy.psm1` | **Modify later:** retain immutable local-image, synthetic-definition, report-path, redirect, and target protections; add full-OpenAPI/disposable-target validation as a separate policy path |
| `banking-lab/scripts/test-zap-scan.ps1` | **Modify later:** retain the offline safety suite and prove the expanded mode cannot run without exact target, database, authentication, and active-scan acknowledgements |
| `banking-lab/scripts/zap-rules.tsv` | **Modify later:** separate diagnostic-only and full-API rule policy with evidence-backed reasons; no blanket suppression |
| `banking-lab/scripts/zap/automation.yaml` | **New later:** authenticated context and ordered safe/active jobs without embedded credentials |
| `.gitignore` | Already ignores `/banking-lab/reports/zap/`; extend only if new temporary credential/context paths require it |
| `banking-lab/docs/03_Walkthroughs/walkthrough-owasp-zap-api-scan.md` | Exact PowerShell commands, isolation setup, result interpretation, remediation, and verified evidence |

The current scanner is intentionally limited to a passive GET-only diagnostic check. No ZAP image is downloaded and no script, database, or scan is changed or executed by approving the Slice 5 feature plan alone.

## 5. Execution Flow

```text
REQUIRE explicit scan approval
VERIFY Docker and exact ZAP image/version
CREATE or reset the guarded disposable database only
START a dedicated Development/Testing API connected to that database
VERIFY OpenAPI host/routes and reject redirects outside the allowlist
SEED only fake scanner users, sessions, accounts, and funds
CONFIGURE and verify authenticated context
RUN API scan in safe mode and inspect coverage
IF this is the post-Slice-5 gate and active scanning is approved:
    RUN active API scan against the same isolated target
GENERATE HTML, JSON, and Markdown artifacts in an ignored directory
TRIAGE findings; remediate or document evidence-backed false positives
RUN normal API/security tests because ZAP does not verify business invariants
DESTROY disposable state only through the guarded test harness
```

## 6. Verification and Exit Criteria

- OpenAPI is valid and its route inventory matches the mapped API surface for that build.
- Authenticated coverage is proven with successful protected-route responses, not assumed.
- No request reaches shared data, an unapproved hostname, or a public environment.
- Reports are generated and raw artifacts remain ignored from Git.
- Every High/Medium alert is triaged; no unresolved High or Critical issue passes the post-Slice-5 gate.
- Expected local-only HTTPS/header findings are documented, not silently ignored.
- Existing auth, ownership, input, rate-limit, idempotency, ledger, limit, and concurrency tests remain green.
- The walkthrough records the exact image digest/version, target type, scan mode, routes reached, report checksums/paths, findings, and limitations.

### Gate A evidence — 2026-09-09

- API preflight: `200 application/json` from loopback port 5255 with redirects disabled.
- ZAP version: 2.17.0 from the already-installed immutable local image ID recorded in the ignored execution artifact.
- Scope: one endpoint, `GET /api/v1/system/info`; no authentication or state-changing route was imported.
- Configured rule result: exit 0, 113 PASS, zero alerts, and reports present.
- Insight review: six scanner insights include one Low `insight.log.warn`; the referenced `zap.log` was not preserved by the current runner. This is an evidence gap to correct before Gate B, not a demonstrated application vulnerability.
- Raw reports: stored under the ignored `banking-lab/reports/zap/` tree; no report or credential is staged for Git.
- Walkthrough: [OWASP ZAP API scan walkthrough](../03_Walkthroughs/walkthrough-owasp-zap-api-scan.md).

## 7. Later Automation

### Gate B execution evidence — 2026-09-09

- Target isolation: dedicated HTTPS API on `host.docker.internal:5266`, current Slice 5 migration, exact disposable database `banking_lab_zap_test`; shared `banking_lab` and API port 5255 were not targeted.
- Authentication proof: two fake customers were created in the disposable database; protected `/api/v1/auth/me` and `/api/v1/accounts/me` returned success, and a one-cent internal transfer stayed inside the disposable ledger.
- Safe scan: 20 imported URL/method targets from the generated OpenAPI document; 116 PASS, 0 FAIL, two Low WARN classes (HSTS and CORP headers). `zap.log` was retained and explained the scanner startup warning.
- Active scan: the authorized run reached active timing rules and produced reports, but overloaded the disposable API/database. It reported one High, confidence 2 SQL-injection candidate on `POST /api/v1/auth/logout` `refreshToken` (`John Doe OR 1=1 -- `), plus 614 informational client-error responses. Fresh isolated PostgreSQL reproduction subsequently proved the alert false: both Boolean payload variants returned the intended idempotent 204 without changing the valid session, and EF/Npgsql emitted a parameterized `TokenHash = @ComputeHash` lookup.
- Active limitations: DOM-XSS rules were skipped because ZAP's browser could not start. The active wrapper did not return a reliable completion marker after the database became unavailable; report files are retained as untrusted evidence only.
- Header disposition: `Cross-Origin-Resource-Policy: same-site` is now emitted globally. One-year HSTS is emitted only for non-Development/non-Testing HTTPS responses; its absence in the isolated Development scan is intentional so local hosts do not retain an HSTS policy.
- Cleanup status: the dedicated API was stopped, port 5266 was closed, exact database `banking_lab_zap_test` was removed and verified absent, and the shared API on port 5255 still returned 200.

After the customer transfer and Activity contracts stabilize, convert the post-feature scan into a CI security job for pull requests or release candidates. Keep passive scans frequent and active scans restricted to ephemeral authorized environments. Re-run after meaningful API, authentication, authorization, validation, middleware, or deployment-boundary changes—not as a separate manual command for each endpoint.

Before Cloudflare/public deployment, add a separate release hardening gate covering trusted proxy headers, public origin/host allowlists, TLS, rate-limit client identity, CORS, and the externally reachable route inventory.

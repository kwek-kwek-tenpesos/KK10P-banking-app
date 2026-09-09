# Walkthrough: OWASP ZAP API Security Scanning

- Audience: KK10P developers and QA testers.
- Current state: Gate A completed; Gate B was approved and exercised on 2026-09-09. Gate B remains open pending infrastructure cleanup and SQL-injection candidate triage.
- Canonical plan: [OWASP ZAP OpenAPI Security Scanning](../02_Planning/plan-owasp-zap-baseline-scan.md).

## Delivered Outcome

The first guarded ZAP baseline successfully checked the local diagnostic API with passive rules only. The run returned exit code 0, produced HTML and JSON reports, reported 113 configured PASS results and zero alerts, and did not import authentication, account, funding, or transfer operations.

This is a narrow before-state, not security certification for the bank. The later Gate B must use authenticated whole-API coverage and a disposable database after Slice 5.

## Concepts Used

1. **Passive scan:** ZAP examines requests and responses for known warning patterns without launching its active attack rules. The runner enforces API safe mode with `-S`.
2. **Synthetic OpenAPI scope:** The runner creates a tiny OpenAPI document containing only the permitted GET endpoint. This prevents a changed application OpenAPI document from silently broadening Gate A.
3. **Security exit gate:** A defined check that must be reviewed before a feature is accepted. Gate A is informational; the post-Slice-5 authenticated Gate B is the meaningful feature gate.
4. **Evidence artifact:** A report, execution record, or checksum retained so results can be reviewed. Raw ZAP artifacts remain ignored because scanner reports may contain request details.

## Logic Flow

```text
START the local Development API
VERIFY GET /api/v1/system/info returns 200 JSON without redirects
VERIFY the ZAP image already exists locally
GENERATE a one-route, GET-only OpenAPI definition
RUN zap-api-scan.py with -S inside a hardened container
WRITE reports into a unique ignored directory
PARSE alerts and insights separately
RECORD results and limitations without claiming whole-API coverage
```

## Important Repository Paths

| Path | Purpose |
| --- | --- |
| `banking-lab/scripts/run-zap-scan.ps1` | Preview-first guarded runner and execution record |
| `banking-lab/scripts/zap-scan-policy.psm1` | Local target, GET-only definition, container, and report-path policy |
| `banking-lab/scripts/test-zap-scan.ps1` | Offline regression checks that cannot contact Docker or the API |
| `banking-lab/scripts/zap-rules.tsv` | Current diagnostic-only rule classifications |
| `banking-lab/reports/zap/` | Git-ignored raw execution and report artifacts |
| `banking-lab/docs/02_Planning/plan-owasp-zap-baseline-scan.md` | Gate A/Gate B scope and safety contract |

## PowerShell Commands

Run from the repository root unless a command changes location.

Start the API in one terminal and leave it open:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api
dotnet run --launch-profile http
```

Verify it from another terminal:

```powershell
Invoke-RestMethod http://localhost:5255/api/v1/system/info
```

Preview the scan without Docker, HTTP, or file writes:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app
pwsh -NoProfile -File .\banking-lab\scripts\run-zap-scan.ps1
```

Run the approved Gate A baseline:

```powershell
pwsh -NoProfile -File .\banking-lab\scripts\run-zap-scan.ps1 `
  -Execute `
  -AcknowledgeLocalTestTarget
```

Re-run the offline guard tests at any time:

```powershell
pwsh -NoProfile -File .\banking-lab\scripts\test-zap-scan.ps1
```

## Verified Gate A Results

| Check | Result |
| --- | --- |
| Local preflight | `200 application/json` |
| Scanner | ZAP 2.17.0, already-installed local image |
| Image ID | `sha256:781a2bdaea47324e7bab583e2263f21d257b0aee61ed51521a5be45f5f5081ef` |
| API operations covered | One: `GET /api/v1/system/info` |
| Configured scan result | Exit 0; 113 PASS; 0 alerts |
| HTTP responses | 100% 2xx and JSON for the one endpoint |
| Raw artifact directory | `banking-lab/reports/zap/run-514c130811b546c29567e86187aafeb6/` |
| HTML SHA-256 | `F1D2334BB4B76DE397DDB92F8ADA8C3BCB4B387068DF44959B4725866FBA98E2` |
| JSON SHA-256 | `76AFA7275C55CF2B1602C8D39F1EF8DDC1B14305DA68C796EB1EDC3D4096DCCF` |
| Git protection | Report directory confirmed ignored by `.gitignore` |

The JSON report also contains six scanner insights. One is Low: `insight.log.warn` says ZAP logged one warning, but the current runner does not preserve `zap.log`. Another informational insight marks the single response as slow. With only one request and no retained scanner log, neither should be presented as an application defect or silently dismissed.

## Security Assessment

- Critical application alerts: 0 in the reviewed scope.
- High application alerts: 0 in the reviewed scope.
- Medium application alerts: 0 in the reviewed scope.
- Low application alerts: 0 in the reviewed scope.
- Low scanner-evidence issue: 1 undiagnosed ZAP log warning.
- Overall scope risk: Low, but the scope is only one unauthenticated read-only endpoint.
- Deployment conclusion: None. This baseline is not broad enough to support a deployment-security claim.

## Safe Customization Points

- Adjust rule classifications only in `zap-rules.tsv`, with a written evidence-based reason.
- Do not add POST/PUT/PATCH/DELETE routes to the Gate A synthetic definition.
- Add authenticated full-OpenAPI behavior as a separate guarded mode; do not weaken the current local-host and explicit-acknowledgement controls.
- Preserve `zap.log` during Gate B so every scanner warning can be reviewed.
- Keep tokens and scanner credentials in temporary environment variables or ignored files only.

## Limitations and Next Step

Gate A did not test login, authorization, account ownership, request validation, rate limiting, idempotency, financial limits, ledger conservation, concurrency, or state-changing endpoints. Those remain covered by application tests and the later authenticated Gate B.

The next product step is explicit approval and implementation of Slice 5. Before Gate B, extend the scanner safely, retain its log, prepare a guarded disposable database with fake scanner accounts/funds, verify authenticated coverage, and only then authorize active scanning.

## Gate B execution notes

Gate B used an HTTPS-only dedicated API on port 5266 and the exact disposable PostgreSQL database `banking_lab_zap_test`. Two fake scanner identities, accounts, funds, sessions, and a one-cent transfer were created only there. Protected `/api/v1/auth/me` and `/api/v1/accounts/me` returned successful responses before scanning.

The authenticated safe scan imported 20 URL/method targets from the generated real OpenAPI document. It produced 116 PASS results, no FAIL results, and two Low WARN classes: missing HSTS and missing/invalid CORP. The retained `safe-zap-home/zap.log` records the scanner startup warning that Gate A could not preserve.

The authorized active scan entered timing rules and generated HTML/JSON/Markdown evidence. It reported one High, confidence-2 SQL-injection candidate for the refresh-token value on logout and 614 informational client-error responses. Logout hashes the supplied token and queries it through EF/Npgsql parameters, so this candidate is not yet a confirmed vulnerability; manual reproduction and review are required. ZAP also skipped DOM-XSS rules because its browser could not start. The scan stressed only the disposable workload, but the wrapper did not return a reliable completion marker after PostgreSQL became unavailable.

The dedicated API was stopped. After Docker/PostgreSQL recovered, the exact `banking_lab_zap_test` database was removed and verified absent. Port 5266 was closed and the shared API on port 5255 still returned 200. Treat all raw artifacts under `banking-lab/reports/zap/` as ignored, untrusted evidence and never commit scanner credentials or tokens.

Ignored artifact SHA-256 values: safe HTML `DFC6FD753934E543A32B5533B3B2DBD69EC29A9D4A2DA63722ACCD82B181D22F`, safe JSON `CD2F3851CBE92C2E56F686B98153682A2F17F2FEB11CE0190798A1004E9D5645`, active HTML `59F18DEA7EDA1F99A850D020EE2945A8C1E8D502D4BA8FDBA1701201BF8AC6DC`, and active JSON `7CBBCD71B07E88B56DCEE866DE3C9A220D8BC18D394E85D4842E05BEC499860B`.

## Gate B closeout

The High logout alert was manually reproduced against a fresh, migrated `banking_lab_zap_test` database using ZAP's exact `John Doe OR 1=1 -- ` and `John Doe AND 1=1 -- ` values. Both calls returned the endpoint's intended idempotent `204 No Content`. The valid session count remained `1`, `/api/v1/auth/me` remained `200`, and the genuine refresh token still returned `200`. Runtime EF/Npgsql output showed `WHERE c."TokenHash" = @ComputeHash`; the supplied text was hashed and passed as a bound parameter rather than concatenated into SQL. The alert is therefore classified as a false positive caused by response comparison while the original active target was degrading.

The API now emits `Cross-Origin-Resource-Policy: same-site` on all responses. It emits `Strict-Transport-Security: max-age=31536000` only for secure non-Development/non-Testing responses. Keeping HSTS off during local Development is intentional because HSTS is persistent browser state and should not be pinned to disposable development hosts. A production HTTPS integration test verifies the header.

Verification completed with **237 passed, 0 failed, 20 explicitly gated PostgreSQL tests skipped**, plus **60 passed offline scanner safety checks**. The two exact logout regression cases and the security-header tests are included in that result. Browser-based DOM-XSS rules remain unverified because the scanner container could not launch a browser; that limitation does not cover an HTML surface because Gate B targeted the JSON API only.

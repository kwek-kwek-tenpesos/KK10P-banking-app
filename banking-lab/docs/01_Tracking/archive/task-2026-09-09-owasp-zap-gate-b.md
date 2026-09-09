# Archived Task: OWASP ZAP Gate B

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Completed on 2026-09-09.
- Scope: Authenticated safe-then-active ZAP assessment of the real local API route inventory using only dedicated port 5266 and disposable database `banking_lab_zap_test`.
- Safety boundary: Shared `banking_lab`, port 5255, Chris/Gio data, Flutter, administrator features, tunnels, and external targets were not scanned or modified.
- Plan: [OWASP ZAP OpenAPI Security Scanning](../../02_Planning/plan-owasp-zap-baseline-scan.md).
- Walkthrough: [OWASP ZAP API scan walkthrough](../../03_Walkthroughs/walkthrough-owasp-zap-api-scan.md).

## Completed Checklist

- [x] Prepared the guarded disposable target, authenticated scanner state, retained logs, and offline safety checks.
- [x] Proved authenticated protected-route access before safe and active scanning.
- [x] Ran the safe scan over 20 generated OpenAPI URL/method targets: 116 PASS, 0 FAIL, and two Low header warnings.
- [x] Ran the approved active scan and retained raw ignored reports despite disposable workload saturation.
- [x] Reproduced ZAP's exact `OR 1=1` and `AND 1=1` logout payloads against fresh PostgreSQL state.
- [x] Classified the SQL-injection alert as a false positive: both payloads returned the intended idempotent 204, the active session remained active, the protected profile remained 200, the genuine refresh remained 200, and EF/Npgsql logs showed a bound `@ComputeHash` parameter.
- [x] Added regression coverage proving injection-shaped unknown tokens cannot revoke a valid session.
- [x] Added `Cross-Origin-Resource-Policy: same-site` globally and one-year HSTS only for non-Development/non-Testing HTTPS responses.
- [x] Documented Development HSTS absence as intentional; local HSTS caching is not forced during phone/scanner development.
- [x] Passed 237 database-free backend tests with 20 gated PostgreSQL tests explicitly skipped.
- [x] Passed 60 offline scanner safety checks.
- [x] Stopped the dedicated API, removed only `banking_lab_zap_test`, verified port 5266 closed, and verified shared port 5255 still returned 200.

## Remaining Boundaries

- Browser-based DOM-XSS rules were skipped because the ZAP container could not start a browser. No HTML/browser surface was in this API-only Gate B scope.
- A future public Cloudflare deployment requires a separate external-boundary review of TLS, proxy trust, host/origin allowlists, CORS, and client-IP rate-limit behavior.
- Shared migration rollout and live transfer testing require separate approval.

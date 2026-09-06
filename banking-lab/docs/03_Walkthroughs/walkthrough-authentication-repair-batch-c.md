# Authentication Repair: Batch C and Follow-up Review

- Follow-up status (2026-09-06): The phone authentication and trusted HTTPS gates described as unfinished in this historical delivery were completed later and are recorded in the [completed authentication task archive](../01_Tracking/archive/task-2026-09-05-end-to-end-customer-authentication.md). The passive ZAP diagnostic itself has still not run and still requires Chris's separate explicit approval. Use the [active task](../01_Tracking/task.md) for current runtime state and next actions.
- Date: 2026-09-04
- Audience: Chris and Gio; learning, review and safe prototype operation.
- Delivery: scanner wrapper hardening, narrow artifact ignores and one confirmed session-expiry correction.
- Verification: 60 offline scanner checks passed; backend 163 passed, six PostgreSQL tests skipped. No scanner, Docker daemon, API listener or database contacted by this batch's verification. The earlier batch B result of 166/166 including PostgreSQL remains historical, not a fresh database result.

## Review findings and resolution

| Severity | Finding | Resolution |
| --- | --- | --- |
| High | `run-zap-scan.ps1` described a baseline but invoked the API scanner without safe mode, enabling active attacks. Arbitrary target URLs could broaden scope. | Default preview only; explicit execution acknowledgement; exact local host/port/path validation; generated definition includes only diagnostic GET. |
| High | Target and mount paths were interpolated into `Invoke-Expression`, creating command-injection risk. | Native argument arrays; no shell evaluation; output path constrained and junctions/symlinks rejected. |
| Medium | Readiness checked a fixed endpoint regardless of the target, `-m` was presented as an API time limit, image pulls/updates could occur, and completion text could imply success after failure. | Matching local diagnostic preflight with redirects/proxies disabled, `-T 5`, `--pull=never`, ZAP silent mode, exit/report checks and truthful status messages. |
| Medium | A session could expire during refresh persistence; token issuance then threw an uncaught InvalidOperationException. | Confirmed with a delayed-save test, then fixed using a specific expiry outcome mapped to normal 401. Unrelated owner-mismatch/programming exceptions remain visible. |
| Low | Local SDK cache and raw scan outputs appeared as untracked candidate files. | Root-anchored Git ignores and matching context ignores; no files removed or staged. |

The follow-up review examined session/JWT issuance, refresh/revocation and bearer validation, the scanner wrapper/rules, ignore boundaries and associated tests. This was not a full repository security audit, dependency vulnerability assessment or penetration test. No claim of production banking security is made.

## Scanner logic and scope

```text
Parse exact local target -> build restricted GET-only plan -> return preview by default
Explicit execution + acknowledgement -> require locally installed image -> resolve image ID
-> probe matching diagnostic route without redirects -> create unique restricted output folder
-> run safe-mode ZAP with argument array -> classify exit code and verify report files
```

The accepted `TargetUrl` spelling is HTTP/HTTPS plus `localhost`, `127.0.0.1` or `host.docker.internal`, an explicit valid port, and `/openapi/v1.json`. This URL supplies the origin only: the full remote OpenAPI document is never downloaded or imported. Its authentication POSTs, alternate servers and external references therefore cannot expand the generated definition. Container traffic targets `host.docker.internal` at that port; Windows preflight uses `localhost`. This wrapper targets Docker Desktop local development, not Tailscale peers, public hosts or Linux deployment.

Only `GET /api/v1/system/info` is in the generated scan definition. This intentionally has **no registration/login/refresh/logout, authenticated profile, authorization or transfer coverage**. Safe mode is not zero traffic: an approved run still sends diagnostic requests, starts a container and writes reports. Broader/authenticated/active scanning requires a separately reviewed scope and approval. Target validation is an accident-prevention guard, not network egress isolation against a malicious image or local service.

ZAP's API scanner documents `-S` for skipping active scans and `-T` for startup/passive wait time. `-T 5` is not a universal five-minute container-kill guarantee. See [ZAP API scan documentation](https://www.zaproxy.org/docs/docker/api-scan/). Silent mode also avoids the packaged script's automatic add-on updates; this was checked against [the upstream API scanner source](https://github.com/zaproxy/zaproxy/blob/main/docker/zap-api-scan.py). Compatibility with an actual installed image still requires separately authorized execution.

The wrapper never pulls an image. On authorized execution it resolves the locally installed stable tag to an immutable image ID and runs with `--pull=never`; there is no Docker socket mount or privileged mode. Existing reports are not overwritten: each execution uses a new `banking-lab/reports/zap/run-<id>` folder. The legacy arbitrary `ReportsDir` and `RulesFile` parameters are removed intentionally; inputs and mounts are fixed to this workflow. Report folders are private generated artifacts, not a place for canonical documentation.

Exit 0 means no configured WARN/FAIL findings, not security certification; 1 means FAIL findings, 2 means WARN findings, and other codes are operational failure. Missing HTML/JSON reports also produce operational failure. The execution record is metadata, not a replacement for reviewing and redacting the actual reports. No execution record or new reports were generated by this delivery.

## Session-expiry correction

The initial regression set an absolute deadline one second ahead and delayed refresh persistence for two seconds. The test failed with the actual exception from `TokenService.cs`, through `CustomerSessionService.cs`, before an HTTP response was produced.

Token generation now captures one timestamp for expiry/issued-at/not-before, explicitly rejects an expired session with `SessionExpiredException`, and rejects expiry values that round to the current/past second in JWT representation. Login/refresh map that specific outcome to generic authentication failure. A wrong session owner still throws a programming error; database errors retain their existing 503 mapping. No lifetime extension, grace period, migration, configuration change or authentication bypass was introduced.

If expiry occurs after rotation has committed, the replacement row may remain as already-expired history; it cannot authorize access, and no replacement credential is returned. This fix does not roll back a transaction that already committed. The next request must sign in again.

## Concepts to learn

- **Passive versus active scanning:** Passive checks inspect traffic; active checks send attack-like inputs. Importing an API can itself generate requests, so both the scan mode and operation scope matter.
- **Argument array:** Each command argument is passed as data rather than interpreted as a new shell command. This removes the string-evaluation injection path.
- **Allowlist:** Accept only explicitly supported inputs, such as local host names and one diagnostic route, instead of attempting to blacklist every dangerous string.
- **Domain exception:** A specific expected event, such as session expiry, can be handled without catching and hiding unrelated programming mistakes.
- **Ignore rule:** It prevents generated files appearing as new Git candidates; it does not delete files, reclaim disk space, untrack existing commits or guarantee secret protection.

## Files changed

Repository-relative paths:

- `banking-lab/scripts/run-zap-scan.ps1`: preview/execution boundary, local preflight, immutable local image selection, safe invocation and report checks.
- `banking-lab/scripts/zap-scan-policy.psm1`: testable URL/output policy, restricted OpenAPI generation, Docker arguments and exit classification.
- `banking-lab/scripts/test-zap-scan.ps1`: 60 dependency-free offline assertions; Docker calls are replaced with a failing test function for the incomplete-execution cases.
- `banking-lab/scripts/zap-rules.tsv`: clarified that INFO is supported and exceptions apply only to the diagnostic JSON scope; rule values were not weakened.
- `.gitignore`, `.aiignore`, `.cursorignore`: narrowly exclude `banking-lab/backend/.dotnet/` and `banking-lab/reports/zap/`. Scripts, source and reviewed documentation remain visible. Neither generated directory contained tracked files when checked.
- `banking-lab/backend/Banking.api/Features/Authentication/SessionExpiredException.cs`, `TokenService.cs`, `CustomerLoginService.cs`, `CustomerSessionService.cs`: narrow expiry classification/handling.
- `banking-lab/backend/tests/Banking.IntegrationTests/SessionExpiryBoundaryTests.cs`, `TokenServiceTests.cs`: delayed-save regression, expired-session classification and preserved owner-mismatch behavior.
- `README.md`, `CHANGELOG.md`, `banking-lab/docs/01_Tracking/task.md`, its dedicated implementation archive, this walkthrough and the batch B follow-up link: current evidence and remaining gates.

## Safe verification commands

From the repository root, these do not scan anything and need no PostgreSQL:

```powershell
pwsh -NoProfile -File banking-lab/scripts/run-zap-scan.ps1
pwsh -NoProfile -File banking-lab/scripts/test-zap-scan.ps1
dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --verbosity quiet
```

PowerShell 7 is required. Verified: default preview only; 60 offline scanner checks passed; backend 163 passed, 0 failed, 6 PostgreSQL skips. `git diff --check` passed with existing line-ending notices. Git ignore checks matched generated paths while source/scripts stayed unignored. The earlier failed expiry probe is recorded above; its final regression remains in the suite and now passes.

Not executed: scanner container, scan download/install, target HTTP preflight, live report generation, PostgreSQL tests/migrations, shared rollout or physical-phone tests. Therefore no new scan findings or security clearance exist. The two runtime execution flags are deliberate gates; do not supply them without a separate approved local-test run. Missing images require separate installation approval, not an automatic workaround.

## Remaining delivery gates

Proceed next to a backed-up shared-database rollout and trusted HTTPS phone setup, using the batch B migration review and exact target confirmation. The API still requires a private signing key. Real registration delivery and mobile login/session integration remain unfinished. An optional local diagnostic passive scan can be approved separately, but cannot prove that those features work. No new design asset is needed for this backend/tooling stage.

Assessment: the reviewed defects above are addressed within this scope, but **not ready for a public production deployment or real banking use**. Live scanner compatibility, broader security testing, operational logging/retention, user-facing authentication completion and rollout verification remain outstanding. Tailscale/appsettings, shared/disposable database data, generated-file contents, license and Git history were preserved.

# Task Tracking: Accounts and Balances Implementation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved accounts/balances code, disposable PostgreSQL verification, backed-up shared schema rollout and physical customer-A journey completed on 2026-09-06. Cross-customer B isolation and TalkBack listening remain pending; customer authentication remains completed and archived.
- Target: Finish the remaining physical Android cross-customer/TalkBack checks through the existing trusted HTTPS path. ZAP remains deferred.
- Scope Guard: No actual scan, image update, authenticated/active probing, shared-data cleanup or Git write without its exact approval.

---

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Files: [accounts contract](../04_Architecture/customer-accounts-contract.md); [accounts walkthrough and migration review](../03_Walkthroughs/walkthrough-accounts-and-balances.md); [authentication contract](../04_Architecture/customer-authentication-contract.md); [ZAP batch C walkthrough](../03_Walkthroughs/walkthrough-authentication-repair-batch-c.md).
- Current Status: The current APK was installed in place on the Infinix phone. Customer A registered through local Mailpit, confirmed, signed in, opened one persisted PHP 0.00 account, restored it after force-stop, saw a recoverable API-outage error, recovered the same reference with Retry, passed 200% text/scroll reachability, and logged out with server revocation. Shared evidence is 3 confirmed users, 1 zero-balance account, 4 sessions/10 refresh-token records and 0 active sessions/tokens after logout.
- Current Blocker: A second known test credential is not available for the physical cross-customer check; TalkBack spoken order requires human listening. ZAP remains unapproved.
- Next Immediate Action: If Chris approves one additional fake customer write (or provides another existing test login locally), verify customer B never receives A's account state; then have Chris confirm TalkBack reading order. Do not reset/remove either database or rewrite/push Git history automatically.
- Migration: `20260906042449_AddCustomerAccounts` is applied to disposable `banking_lab_accounts_test` and shared `banking_lab`. Shared post-checks found zero account rows, unchanged 2 users/3 sessions/4 refresh tokens, both CHECK constraints, restricted owner FK, unique owner index and no pending EF model changes. Down drops account data and is not an automatic recovery action.
- Confirmed Scope: One PHP simulator account per customer, explicit Open account action, initial PHP 0.00. Funding and transfers remain separate future slices.
- Approved Invariants: Idempotent PUT and owner-only GET at `/api/v1/accounts/me`; persisted zero-only PHP balance; unique customer FK with restricted deletion; no automatic opening/backfill; minimal DTO with integer-string minor units; HTTPS/no-store/body/rate guards.
- Mobile Invariants: Explicit loading/unopened/opening/success/retry states; bounded refresh/retry; session-generation and secure-storage ordering guard against late work after logout/user switching; integer-only amount formatting; accessible responsive card.
- ZAP Boundary: Scope remains only `GET /api/v1/system/info`; authentication and active attack simulation are excluded. No scan approval was given in this conversation.

## Fresh Conversation Start Here

- Read the repository-root `AGENTS.md`, then this active task. The accounts/balances plan is approved; track execution here without re-reading it unless architecture changes. Do not load drafts/completion archives.
- Relevant references: [ZAP implementation plan](../02_Planning/plan-owasp-zap-baseline-scan.md) and [scanner/security walkthrough](../03_Walkthroughs/walkthrough-authentication-repair-batch-c.md).
- No approval has been granted for an actual scan. Before execution, Chris must explicitly state: `I approve the passive GET-only local ZAP diagnostic scan.`
- Preview and offline safety verification are non-scanning checks:
  - `pwsh -NoProfile -File banking-lab/scripts/run-zap-scan.ps1`
  - `pwsh -NoProfile -File banking-lab/scripts/test-zap-scan.ps1`
- After approval, Docker Desktop and the local API on port `5255` are required. PostgreSQL, Mailpit, Tailscale and the physical phone are not required because the approved route does not use them.
- Approved execution command, only after the exact approval above: `pwsh -NoProfile -File banking-lab/scripts/run-zap-scan.ps1 -Execute -AcknowledgeLocalTestTarget`
- The locally installed `ghcr.io/zaproxy/zaproxy:stable` image must be used with no pull/update. If Docker cannot reach the loopback-bound API through `host.docker.internal`, stop and diagnose the connectivity issue; do not broaden listeners or scan scope without review.
- Review and redact generated HTML/JSON reports before documenting or sharing results. A clean report is not a security certification.

## Active Checklist

- [ ] If explicitly approved, start the API and execute the existing ZAP wrapper with its exact local acknowledgement flags.
- [ ] Review and redact the generated HTML/JSON findings before documenting or sharing them.
- [ ] Keep authenticated, active, shared-database and public-host scans in separate future plans.
- [x] Define accounts/balances scope, acceptance criteria, pseudocode, affected files and preliminary migration safety review.
- [x] Obtain explicit accounts/balances implementation-plan approval.
- [x] Implement backend model, owner-scoped API, strict input/transport/cache/rate guards.
- [x] Generate additive account migration and review SQL without applying it.
- [x] Implement mobile account flow and session-generation/storage race protection.
- [x] Add/run backend and Flutter checks; author guarded PostgreSQL race/constraint/upgrade tests.
- [x] Review changes and update canonical contract, walkthrough, README and changelog.
- [x] Obtain exact disposable database approval, then execute migration/constraint/concurrency verification.
- [x] Obtain shared rollout approval, create/verify backup and apply only the account migration.
- [x] Execute the physical-phone customer-A opening, persistence, outage/retry, logout and 200% text checks.
- [ ] Execute cross-customer B isolation and human TalkBack reading-order checks.
- [ ] Perform a broader security review before any public production deployment.

## Verification Gates

- Reverified 2026-09-06: ZAP default preview passed and 60 offline wrapper safety checks passed; no scanner, Docker daemon or API was contacted and no report was produced.
- Previous handoff reports `ghcr.io/zaproxy/zaproxy:stable` locally installed; not rechecked this turn. Approved execution must resolve the local immutable image without pulling/updating it.
- Verified 2026-09-06: backend build passed; backend tests 196 passed / 0 failed / 10 skipped; full Flutter tests 101 passed; analysis clean; targeted formatting, source whitespace and documentation links checked.
- Database-free suite: six prior session tests plus four account tests were intentionally skipped because both database-test variables were unset. The four account tests were then run separately against the approved fresh disposable PostgreSQL target: 4 passed / 0 failed / 0 skipped.
- Card widget checks: unopened/loaded/error at 320/360/412/768 logical pixels and 200% text; no overflow, accessible focus/tap action and minimum button size verified. On the physical 1080x2400 device, 200% text wrapped the long reference and kept Refresh/Sign out reachable by scrolling; TalkBack listening remains pending.
- Review fixes: read committed account precision on creation; protect trailing-slash input; order secure writes/logout revocation; discard old-generation account/token results; report secure-storage cleanup uncertainty accurately.
- Disposable verification applied migrations and seeded fake test identity/session/account evidence only inside `banking_lab_accounts_test`. Its pre-rollout post-check confirmed the account migration count was 1 there and 0 in shared `banking_lab`. No live API/device check, ZAP scan, push or commit rewrite occurred; keep this task active until remaining gates pass.
- Shared rollout verification: API port `5255` was idle and PostgreSQL had no other `banking_lab` connection. Backup `banking_lab/.local/backups/banking_lab_pre_AddCustomerAccounts_20260906T134746Z.dump` is 25,133 bytes with SHA-256 `e370fb10aab9f95e307e8882eff1fc0d649a2ca8e81dd39ae707325081c2b871`; `pg_restore --list` read 76 entries and confirmed the pre-account schema. The named forward SQL contained no DROP/DELETE/TRUNCATE/UPDATE statement. Shared migration completed and post-checks passed without changing existing identity/session/token counts.
- Physical customer-A verification: private HTTPS diagnostics passed; registration/confirmation used loopback Mailpit; opening created exactly one PHP/zero account; restart and Retry preserved its reference; API downtime produced a recoverable error; logout left 0 active sessions/tokens and no stale account UI after another restart. The initial tap assertion falsely matched explanatory `PHP 0.00` text; screenshot review caught it, the integer coordinate calculation and loaded-state proof were corrected, and no account had been created by the bad tap.
- A ZAP exit code or clean report is not security certification and cannot prove auth, authorization, concurrency or business-rule safety.
- Authentication completion evidence is archived per-file and does not imply the accounts/transfer MVP is complete.

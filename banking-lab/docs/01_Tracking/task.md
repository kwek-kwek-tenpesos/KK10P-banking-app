# Task Tracking: Accounts and Balances Implementation

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved accounts/balances code and database-free verification delivered on 2026-09-06. PostgreSQL/device gates remain pending; customer authentication remains completed and archived.
- Target: Verify accounts on an approved disposable PostgreSQL target, then prepare separately approved shared rollout/device verification. ZAP remains deferred.
- Scope Guard: No actual scan, image update, authenticated/active probing, shared-data cleanup or Git write without its exact approval.

---

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Files: [accounts contract](../04_Architecture/customer-accounts-contract.md); [accounts walkthrough and migration review](../03_Walkthroughs/walkthrough-accounts-and-balances.md); [authentication contract](../04_Architecture/customer-authentication-contract.md); [ZAP batch C walkthrough](../03_Walkthroughs/walkthrough-authentication-repair-batch-c.md).
- Current Status: Customer registration, confirmation, login, session restoration and logout passed on the physical Infinix Android phone over private Tailscale Serve HTTPS. The API, PostgreSQL, Mailpit and test phone are currently stopped. The approved Tailscale Serve configuration may remain configured, but it is not required for the local ZAP diagnostic.
- Current Blocker: Migration/database fixture execution and physical-phone rollout need separate exact-target approval; ZAP remains unapproved.
- Next Immediate Action: Await Chris's next prompt after the requested local commit; no push. Database verification still requires approval to start PostgreSQL 17 and create/use fresh disposable `127.0.0.1:5432 / banking_lab_accounts_test`, then run four account tests. If occupied, stop; never reset/downgrade/clean it automatically. Shared `banking_lab` remains untouched.
- Migration: `20260906042449_AddCustomerAccounts` generated; forward SQL reviewed (new table/index/constraints plus EF history only), unapplied. Down drops account data and is not an automatic recovery action.
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
- [ ] Obtain exact disposable database approval, then execute migration/constraint/concurrency verification.
- [ ] Obtain shared rollout approval and backup; execute migration and physical-phone checks.
- [ ] Perform a broader security review before any public production deployment.

## Verification Gates

- Reverified 2026-09-06: ZAP default preview passed and 60 offline wrapper safety checks passed; no scanner, Docker daemon or API was contacted and no report was produced.
- Previous handoff reports `ghcr.io/zaproxy/zaproxy:stable` locally installed; not rechecked this turn. Approved execution must resolve the local immutable image without pulling/updating it.
- Verified 2026-09-06: backend build passed; backend tests 196 passed / 0 failed / 10 skipped; full Flutter tests 101 passed; analysis clean; targeted formatting, source whitespace and documentation links checked.
- PostgreSQL skips: six prior session tests plus four new account tests. Both database-test environment variables were unset during execution; no database fixture ran.
- Card widget checks: unopened/loaded/error at 320/360/412/768 logical pixels and 200% text; no overflow, accessible focus/tap action and minimum button size verified. Physical-device/visual observations remain pending.
- Review fixes: read committed account precision on creation; protect trailing-slash input; order secure writes/logout revocation; discard old-generation account/token results; report secure-storage cleanup uncertainty accurately.
- Implementation verification performed no database execution, service startup, live API/device checks or Git writes. Chris subsequently authorized local staging/commit only, with no push and no further execution until the next prompt. ZAP remains unexecuted; keep this task active until remaining gates pass.
- A ZAP exit code or clean report is not security certification and cannot prove auth, authorization, concurrency or business-rule safety.
- Authentication completion evidence is archived per-file and does not imply the accounts/transfer MVP is complete.

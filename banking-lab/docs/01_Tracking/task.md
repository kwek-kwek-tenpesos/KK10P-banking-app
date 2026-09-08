# Task Tracking: KK10P Slice 4 Ledger and Development Funding

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Slice 4 source, automated verification, backup, shared rollout, and authenticated funding completed on 2026-09-09. A Flutter non-zero parser regression is fixed and awaits one physical Home refresh check.
- Target: Establish an auditable ledger and bounded Development-only self-funding path for Chris and Gio before internal transfers.
- Scope Guard: No code, migration generation/application, shared-database write, simulator credit, Transfer, Activity, admin, or app-lock work is authorized by planning alone.

---

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Plan: [Slice 4 Ledger and Development Funding Foundation](../02_Planning/plan-kk10p-slice-4-ledger-development-funding.md).
- Parent Roadmap: [KK10P prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md).
- Completed Slice 3: [Archived Slice 3 task](archive/task-2026-09-08-kk10p-slice-3-current-account-clean-home.md).
- Current Contracts: [Authentication](../04_Architecture/customer-authentication-contract.md), [accounts](../04_Architecture/customer-accounts-contract.md), and [ledger/Development funding](../04_Architecture/ledger-development-funding-contract.md).
- Proposed Policy: Fixed PHP 50,000 self-grant, PHP 100,000 per-account daily Development cap on `Asia/Manila` boundaries, no manual reset endpoint, UUID idempotency, and a minimal authenticated Diagnostics trigger.
- Future Transfer Policy: Slice 5 will enforce PHP 50,000 per internal transfer and PHP 100,000 aggregate outgoing per source account per Philippine calendar day. Funding/incoming money and idempotent replays do not consume that outgoing allowance.
- Data Direction: General ledger transaction envelope plus balanced issuer/customer postings; `CustomerAccounts.BalanceMinor` remains transactionally maintained and non-negative.
- Environment Boundary: Funding route maps only in Development; Testing may enable it inside test hosts. Production receives 404.
- Migration Result: After explicit approval, verified backup and disposable proof, only `20260908124011_AddLedgerAndDevelopmentFunding` was applied to shared `banking_lab`; existing identity/session/account counts and zero balances were preserved.
- Verification: 211/211 ordinary backend tests passed with 14 opt-in PostgreSQL tests skipped; the fresh disposable ledger suite passed 4/4; Flutter analysis is clean and 177/177 Flutter tests passed.
- Funding Evidence: Two separately confirmed grants committed about 59 seconds apart, producing 2 transactions, 4 zero-sum postings, and PHP 100,000 on one account. This is the approved daily cap, not a duplicate ledger write; the other account remains zero.
- Runtime: Docker/PostgreSQL/Mailpit are healthy; the .NET API is running on loopback and the restored Tailscale Serve HTTPS path reports Development. An unauthenticated funding probe returned 401/no-store and wrote no ledger rows.
- Deferred: Transfer/Activity, arbitrary or third-party funding, reset/reversal, administrator portal, and biometric/PIN app lock.
- Deferred Admin Reminder: The user-provided React headquarters prototype and proposed WebAuthn/passkey direction are later reference inputs only; do not inspect or implement them during Slice 4.
- Deferred Infrastructure Reminder: Evaluate Cloudflare Tunnel versus Tailscale Serve in a separate plan covering origin trust, Access/DNS, secrets, observability, failure modes, and rollback.
- Deferred Visual Reminder: Investigate the newly reported Light/Dark material-transition roughness in the later visual-polish slice; keep it separate from financial-state reconciliation.
- Recommended Next Action: Hot-reload/restart Flutter, refresh Home, and physically confirm `PHP 100,000.00`; Gio remains unfunded unless separately requested.

## Active Checklist

- [x] Close Slice 3 with physical Light/Dark and TalkBack evidence.
- [x] Record the optional unopened-customer phone path as untested but automated-covered.
- [x] Inspect the current account constraint, API guards, session ownership, diagnostics surface, migration pattern, and PostgreSQL test harness.
- [x] Draft the feature-specific Slice 4 architecture, API, data, concurrency, migration, security, test, and rollout plan.
- [x] Obtain Chris's explicit approval of the Slice 4 plan and proposed funding policy.
- [x] After approval, implement only database-free code/tests and fresh disposable PostgreSQL verification first.
- [x] Obtain separate approval, verify a recovery backup, and apply only the reviewed migration to shared `banking_lab`.
- [x] Reconcile Chris's authenticated funding result without direct database edits; do not credit Gio.
- [ ] Physically verify the corrected Flutter parser renders `PHP 100,000.00` on Home.

# Archived Task: Accounts and Balances

- Completed: 2026-09-06
- Scope: One owner-scoped PHP simulator account per authenticated customer, explicit opening at PHP 0.00, persistence, mobile states and verification.
- Canonical delivery record: [accounts and balances walkthrough](../../03_Walkthroughs/walkthrough-accounts-and-balances.md).

## Completed Checklist

- [x] Define and approve the accounts/balances contract, acceptance criteria and migration review.
- [x] Implement owner-only `GET` and idempotent `PUT /api/v1/accounts/me` with transport, cache, input and rate guards.
- [x] Implement additive account storage, unique customer ownership and PHP zero-balance constraints.
- [x] Implement loading, unopened, opening, loaded, retry, refresh and logout-safe Flutter states.
- [x] Verify backend and Flutter automated checks.
- [x] Verify the migration in a disposable PostgreSQL database.
- [x] Back up shared `banking_lab`, verify the backup and apply only `20260906042449_AddCustomerAccounts` with explicit approval.
- [x] Verify Chris's physical customer-A opening, persistence, outage/retry, logout and 200% text flow.
- [x] Verify Gio's remote customer-B registration, account opening and owner isolation.
- [ ] Listen through Home/account with TalkBack. Chris explicitly transferred this human check to the post-redesign UI-foundation review; it was not claimed as passed.

## Delivery Boundary

Funding, transfers and transaction history were not part of this slice. No shared data was reset or deleted. The ZAP diagnostic scan remains a separate unapproved plan and was not run.

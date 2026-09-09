# Customer Accounts and Balances Contract

- Status: Implemented; backend, Flutter, disposable PostgreSQL, backed-up shared schema rollout, two-customer ownership, TalkBack, non-zero Home rendering, and ledger-backed Development funding are verified through 2026-09-09.
- Scope: One explicitly opened PHP simulator account per customer, starting at PHP 0.00 and later holding non-negative ledger-backed fake funds. The internal-transfer API is implemented as an unapplied Slice 5 candidate; its Flutter journey, transaction history, account closure and multiple accounts remain future work.
- Session policy: [customer authentication contract](customer-authentication-contract.md).
- Delivery evidence and pending manual steps: [walkthrough](../03_Walkthroughs/walkthrough-accounts-and-balances.md).

## Ownership and endpoints

Both endpoints use the existing bearer validator, persisted session checks and current enabled/confirmed/unlocked customer. The backend takes ownership from `HttpContext.Items[typeof(ApplicationUser)]`; request data never selects a user or another account.

| Method | Route | Input | Success |
| --- | --- | --- | --- |
| GET | `/api/v1/accounts/me` | Bearer token; no query or body | `200` with AccountSummary; `404` Problem Details with `code: account_not_opened` if the customer has not opened one |
| PUT | `/api/v1/accounts/me` | Bearer token; empty JSON object `{}`; no query | `201` with AccountSummary and `Location: /api/v1/accounts/me` on creation; `200` with the same persisted summary for a repeated request |

An AccountSummary contains only:

```json
{
  "id": "11111111-1111-1111-1111-111111111111",
  "currency": "PHP",
  "balanceMinor": "0",
  "openedAtUtc": "2026-09-06T00:00:00Z"
}
```

The sample is fictional. `id` is a simulator reference, not a real bank account number. `balanceMinor` is a canonical non-negative base-10 integer string bounded by PostgreSQL/.NET signed 64-bit storage; Flutter parses it with BigInt and formats centavos without floating-point arithmetic. Only PHP is accepted. Negative, decimal, signed, leading-zero, overflow, or otherwise malformed data is an invalid response, never a display fallback.

GET performs no account writes. PUT inserts a server-generated UUID, validated owner, PHP currency, zero balance and UTC opening time. A unique UserId index makes repeats/concurrent attempts converge on one row. Only the named owner-index collision takes the race-recovery path: detach the failed insert and query the winner. Other constraint/programming failures are not converted into successful duplicates. Creation reads the committed row back to return PostgreSQL timestamp precision consistently with future reads.

## Request guards and failures

- All accounts-path responses receive `Cache-Control: no-store`, including transport/rate/auth failures.
- HTTPS is checked before bearer processing. The existing exact-loopback forwarding configuration is preserved. Plain HTTP returns `400`; it does not redirect.
- The account route accepts no query parameters. GET rejects a body; PUT accepts only an empty JSON object. Unknown fields, arrays, null and malformed JSON return `400`; unsupported content types return `415`.
- Bodies, including streamed/chunked input, are limited to 16 KiB (`413`). Trailing-slash routing cannot bypass input validation.
- GET and PUT share a named accounts rate policy: 30 requests/minute per direct or trusted-proxy client IP, no queue. `429` uses the existing Retry-After handler. This is a per-process local-prototype budget, independent of auth limits.
- Missing/forged/revoked/expired credentials and ineligible customers receive `401`; session dependency failures remain `503` through the existing bearer events.
- Account timeouts/transient database failures and a missing account table return a generic `503`. Unexpected errors remain server errors. A failure never becomes an unopened account or a fabricated zero balance.
- Account logs use a fixed generic storage warning, without credentials, customer identifiers, complete response bodies or raw database exceptions.

## Data model and migration boundary

`CustomerAccounts`: UUID `Id` primary key; required text `UserId`; required three-character `Currency`; required bigint `BalanceMinor` default 0; required UTC `OpenedAtUtc` timestamp.

- `IX_CustomerAccounts_UserId`: unique owner index.
- `FK_CustomerAccounts_AspNetUsers_UserId`: references identity with restricted deletion.
- `CK_CustomerAccounts_Currency`: currency equals PHP.
- `CK_CustomerAccounts_NonnegativeBalance`: balance is greater than or equal to zero.

Migration `20260906042449_AddCustomerAccounts` originally added the table with a zero-only balance constraint and no seeds, backfill, or automatic opening. The separately reviewed and deployed migration `20260908124011_AddLedgerAndDevelopmentFunding` replaced that check with the current non-negative constraint and added the balanced, append-only journal; see the [ledger and Development funding contract](ledger-development-funding-contract.md). Existing identity/session/account data was preserved through both backed-up shared rollouts, and app startup still does not apply migrations automatically. An editable balance field is never a substitute for ledger authority, reconciliation, and concurrency control.

The Down migration drops CustomerAccounts and would lose its data after use. Prefer reverting application code while retaining the additive table; schema/data rollback requires separate approval and a reviewed backup path.

## Mobile lifecycle

```text
Authenticated Home -> GET current account
  loading -> exact account_not_opened: offer Open account
          -> summary: show Simulator funds, PHP 0.00, reference and Refresh balance
          -> other failure: show safe error and Retry

Open account -> disable duplicate taps -> PUT {}
  committed success -> display returned summary
  uncertain failure -> explain uncertainty -> Retry GET first
    existing account -> display it
    still unopened -> repeat the idempotent PUT
```

Requests use `getValidAccessToken`, reject insecure API origins before attaching a token, and disable redirects. A protected-call 401 permits one refresh and one retry. A definitive refresh/retry 401 clears the local session and returns to Login; a temporary failure preserves recoverable credentials for Retry.

Account state is scoped to the authenticated customer/session generation. Logout removes the customer from visible UI immediately. Pending account results from an old generation are discarded. Authentication operations also carry a generation, and secure-storage reads/writes/clears are serialized: logout waits for a pending rotation write, reads the latest refresh token for revocation, then clears it; a new login's clear/write cannot be overwritten by old work. Pending controller operations cannot restore an older UI state.

No account data is persisted by the mobile feature. Logout/storage failures report uncertainty rather than falsely claiming that secure credentials were cleared. The card uses the approved Light/Dark blue-accent neumorphic material, a 48-pixel minimum action height, meaningful labels and explicit loading/error states.

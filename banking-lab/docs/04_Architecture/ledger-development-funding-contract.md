# Ledger and Development Funding Contract

- Status: Implemented, automated-verified, backed up, and applied to shared Development `banking_lab` on 2026-09-09. Two separately confirmed grants brought one tester account to the PHP 100,000 daily cap; the other account remains unfunded.
- Scope: Append-only PHP journal foundation plus a fixed, self-only Development grant.
- Parent plan: [Slice 4](../02_Planning/plan-kk10p-slice-4-ledger-development-funding.md).
- Delivery guide: [Slice 4 walkthrough](../03_Walkthroughs/walkthrough-kk10p-slice-4-ledger-development-funding.md).

## Product policy

- A grant is exactly PHP 50,000.00 (`5,000,000` centavos).
- One account may receive at most PHP 100,000.00 through this Development operation in one Philippine calendar day.
- The day is the half-open interval from `00:00` to the next `00:00` in `Asia/Manila`, calculated from the server clock and converted to UTC.
- Funding is simulator issuance, not a customer transfer. It does not consume the separately planned outgoing-transfer allowance.
- There is no arbitrary amount, recipient selection, manual reset, reversal, administrator action, or Production route in this slice.
- The BSP InstaPay PHP 50,000 transaction ceiling informed the future transfer policy. KK10P's PHP 100,000 daily aggregate is an explicit simulator product rule, not a claim of a universal BSP daily limit.

## Endpoint

`POST /api/v1/development/funding/me` is mapped only when the server environment is `Development` or an automated test host is `Testing`. Production returns `404` because the route does not exist.

The request requires:

- HTTPS, with forwarded HTTPS accepted only through the existing exact-loopback trusted proxy boundary;
- an eligible authenticated customer session;
- one canonical UUID in `Idempotency-Key`;
- `Content-Type: application/json`;
- exactly `{}`, no query string, and no more than 16 KiB even when streamed.

The authenticated server context selects the owner. No request field can select a user, account, amount, currency, date, or recipient.

First success is `201`; a same-customer/same-key replay is `200` and returns the original transaction with `replayed: true`:

```json
{
  "transactionId": "11111111-1111-4111-8111-111111111111",
  "accountId": "22222222-2222-4222-8222-222222222222",
  "currency": "PHP",
  "creditedAmountMinor": "5000000",
  "balanceAfterMinor": "5000000",
  "createdAtUtc": "2026-09-08T12:00:00Z",
  "replayed": false
}
```

Stable conflicts are:

| HTTP | Code | Meaning |
| --- | --- | --- |
| 409 | `account_not_opened` | The authenticated customer has no account |
| 409 | `development_funding_daily_limit_reached` | Another grant would exceed today's PHP 100,000 funding cap |
| 409 | `idempotency_conflict` | The caller reused a key for a different server fingerprint/operation |

Transport/input failures use `400`, `413`, or `415`; authentication uses `401`; the dedicated 10/minute per-client-IP budget uses `429` with `Retry-After`; recognized dependency failures use generic `503`. Every response on this path is `Cache-Control: no-store`.

## Journal and account model

`LedgerTransactions` records the operation, initiating Identity user, UUID key, fixed server fingerprint, PHP currency, post-operation balance snapshot, and UTC timestamp. `(InitiatedByUserId, IdempotencyKey)` is unique.

`LedgerPostings` records two signed entries per transaction. Funding writes:

```text
SIMULATOR_ISSUER     -5,000,000 PHP
customer account    +5,000,000 PHP
                     ----------
                              0
```

The EF context rejects modified/deleted journal records, standalone postings, non-paired positions, unequal currencies/timestamps, and non-zero sums. PostgreSQL separately constrains operation/currency, non-zero amounts, positions, exactly one target, issuer name, foreign keys, and unique transaction positions. There is no update/delete ledger endpoint.

`CustomerAccounts.BalanceMinor` remains the fast server-authoritative snapshot and changes in the same database transaction as the journal. Its check changes from exactly zero to nonnegative. A successful grant must reconcile to committed customer postings; floating-point money is never used.

## Concurrency and idempotency

The service begins one PostgreSQL transaction and locks the authenticated account row `FOR UPDATE`. Under that lock it checks the idempotency key, calculates today's committed grants, checked-adds the balance, appends the transaction/postings, and commits.

- Two concurrent calls with the same key become one grant plus one replay.
- Two concurrent new keys may create the two permitted grants.
- A third grant cannot cross the cap.
- An uncertain mobile retry keeps the same UUID, including after one token refresh.
- A definitive unopened/cap/rate/input error discards the key; a new user action receives a new key.

## Mobile boundary

The funding card appears only in API Diagnostics when both conditions are true: the API response environment is exactly `Development`, and the app has an authenticated customer. The card explains that funds are fake, shows the fixed amount/daily cap, requires confirmation, disables rapid duplicate taps, displays safe success/error feedback, and invalidates account state after success.

Flutter visibility is presentation only. The unmapped Production endpoint, bearer authorization, server-derived ownership, fixed server values, and database transaction are the security boundary. No ledger or balance is persisted locally.

## Migration state and rollback

Migration `20260908124011_AddLedgerAndDevelopmentFunding`:

1. replaces only the zero-balance check with a nonnegative check;
2. creates the two journal tables, constraints, restricted foreign keys, and indexes;
3. performs no `UPDATE`, `DELETE`, seed, backfill, account opening, or grant;
4. was applied once to shared `banking_lab` after explicit approval and verified pre-migration backup; it issued no funds.

Its Down operation drops all journal rows and can only restore the zero-only account check when every balance is zero. After any funding, application rollback should retain the additive schema. Database rollback/recovery is destructive and requires a separate reviewed decision and verified backup.

## Internal transfer extension

The implemented [Slice 5 internal-transfer contract](internal-transfer-contract.md) retains the approved PHP 50,000 per-transfer and PHP 100,000 aggregate outgoing-per-source-account Philippine-day rules. Incoming money, Development funding, rejected attempts, and idempotent replays do not consume that outgoing allowance. Source/destination movements reuse the journal as one balanced customer posting pair. Migration `20260909065721_AddInternalTransfers` widens only the operation check constraint; it is fresh-database verified but remains unapplied to shared `banking_lab`, and no live transfer or Flutter Transfer UI exists yet.

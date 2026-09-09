# Internal Fake-Money Transfer Contract

- Status: Implemented, migrated, and real-device verified. Gate 6R safely applied `20260909065721_AddInternalTransfers`, and the reconciled Chris↔Gio acceptance run passed on 2026-09-10.
- Plan: [Slice 5](../02_Planning/plan-kk10p-slice-5-internal-transfer-api.md).
- Delivery guide: [Slice 5 walkthrough](../03_Walkthroughs/walkthrough-kk10p-slice-5-internal-transfer-api.md).

## Product rules

- Transfers move fake PHP only between two distinct, already-open KK10P simulator accounts.
- The authenticated persisted session determines the source. A request cannot supply a source, owner, currency, date, status, or balance.
- Amount is a canonical integer string in centavos from `1` through `5000000` (PHP 0.01–50,000.00).
- Newly committed outgoing internal transfers are capped at `10000000` centavos per source account per `Asia/Manila` calendar day.
- Incoming transfers, Development funding, rejected requests, and idempotent replays do not consume that outgoing allowance.
- A committed transfer is immediately `COMPLETED`; pending settlement, fees, external banks, reversals, recipient search, and admin overrides are outside this slice.

## Endpoint

`POST /api/v1/transfers/internal`

Required boundary:

- HTTPS, an eligible authenticated customer session, and no query parameters;
- exactly one lowercase canonical non-empty UUID `Idempotency-Key`;
- `Content-Type: application/json` and at most 16 KiB, including streamed bodies;
- exactly `destinationAccountReference` and `amountMinor`, with no unknown or duplicate fields.

```json
{
  "destinationAccountReference": "22222222-2222-2222-2222-222222222222",
  "amountMinor": "5000000"
}
```

First commit returns `201`; an exact same-key replay returns `200` with the original persisted values and `replayed: true`.

```json
{
  "transactionId": "11111111-1111-1111-1111-111111111111",
  "sourceAccountReference": "33333333-3333-3333-3333-333333333333",
  "destinationAccountReference": "22222222-2222-2222-2222-222222222222",
  "currency": "PHP",
  "amountMinor": "5000000",
  "sourceBalanceAfterMinor": "5000000",
  "status": "COMPLETED",
  "createdAtUtc": "2026-09-09T00:00:00Z",
  "replayed": false
}
```

No response contains email, phone, display name, Identity user ID, recipient balance, credential, or idempotency key.

## Stable failures

| HTTP | Code or behavior |
| ---: | --- |
| 400 | Invalid transport, key, JSON shape, destination, or amount |
| 401 | Missing, invalid, expired, revoked, or ineligible session |
| 404 | `recipient_not_found` |
| 409 | `account_not_opened`, `self_transfer_not_allowed`, `idempotency_conflict`, `insufficient_funds`, or `outgoing_daily_limit_reached` |
| 413 / 415 | Oversized body / unsupported media |
| 429 | Dedicated 10/minute client-IP budget with `Retry-After` |
| 500 | Safe unexpected failure without raw exception details |
| 503 | Authentication or transfer storage temporarily unavailable |

Every transfer response is `Cache-Control: no-store` and carries a fresh server-generated `X-Request-ID`. Problem Details carries the same value in `traceId`; caller-provided correlation IDs are not trusted.

## Atomic journal behavior

The service begins one PostgreSQL transaction, discovers the source by authenticated owner, locks the source and requested destination rows in database UUID order, then performs replay, limit, and funds checks. A new commit checked-subtracts the source, checked-adds the destination, and appends one immutable transaction with two postings:

```text
source account       -amount PHP   position 1
destination account +amount PHP   position 2
                       ---------
                               0
```

The unique `(InitiatedByUserId, IdempotencyKey)` index spans funding and transfers. The transfer fingerprint is SHA-256 over a versioned server-canonical source, destination, currency, and amount representation. Same-key use for another operation or request returns `idempotency_conflict`.

EF rejects ledger mutation, standalone postings, non-paired positions, currency/time mismatch, and non-zero sums. PostgreSQL keeps the nonnegative balance, posting, relationship, and uniqueness constraints. The operation allow-list is widened only to `DEVELOPMENT_FUNDING` and `INTERNAL_TRANSFER`.

## Migration and release boundary

Migration `20260909065721_AddInternalTransfers` only replaces `CK_LedgerTransactions_Operation`. It adds no table/column, seed, backfill, account, balance update, or transfer. A fresh `banking_lab_transfer_test` upgrade preserved an existing funding record and passed transfer concurrency/constraint tests before that exact disposable database was removed.

Gate 6R quiesced the API, created and catalog-validated a custom PostgreSQL backup, applied only that migration, and reconciled unchanged users, sessions, refresh tokens, accounts, balances, ledger rows, posting sum, and journal validity. The API then restarted and returned HTTP 200 from system info. The rollout itself executed no transfer; the separately performed Chris↔Gio acceptance run later created four intentional, balanced test transfers.

The Down migration cannot be used after an internal-transfer row exists because it narrows the operation constraint back to funding-only. Restore or data recovery after the first transfer therefore requires a separately reviewed recovery plan rather than `database update` to the prior migration.

## Flutter boundary

Slice 6 now exposes Transfer from a loaded Home account and protects `/transfer` behind an authenticated session. The Flutter journey accepts only a canonical non-empty destination UUID and exact PHP text, converts it directly to integer centavos, shows Recipient → Amount → Review, and renders only the strict server receipt after completion.

Before dispatch, Flutter writes a versioned customer-scoped envelope containing the exact destination, amount and generated UUID idempotency key to platform secure storage. Rapid confirmation is single-flight. Timeout, network, cancellation, malformed-success, and server uncertainty retain that same envelope; reopening the route offers same-key reconciliation rather than creating another transfer. Definitive business rejection clears it. If secure storage cannot save, nothing is sent; if cleanup fails after a confirmed result, the receipt remains visible and cleanup is retryable.

The repository uses the current access token, permits one refresh, and resends the identical envelope after refresh. A final authentication failure invalidates the local session without discarding an unresolved transfer. Late responses are guarded by the current customer/session generation. Successful completion refreshes Home account state. Slice 7 still owns persisted Activity/history lookup and historical receipts.

The Flutter implementation, shared schema, and Chris↔Gio physical-device flow are verified. A manual rapid-tap and auto-clicker check produced one movement for one logical confirmation, and the post-test ledger reconciliation found no duplicate or malformed journal. Activity/history presentation remains a Slice 7 responsibility.

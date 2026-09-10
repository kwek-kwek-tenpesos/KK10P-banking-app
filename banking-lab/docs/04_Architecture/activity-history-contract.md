# Account Activity and Historical Receipt Contract

- Status: Implemented and migrated to shared `banking_lab` through the verified Gate 7R rollout. Chris/Gio physical-device acceptance remains pending.
- Plan: [Slice 7](../02_Planning/plan-kk10p-slice-7-activity-history-receipts.md).
- Related contracts: [ledger and Development funding](ledger-development-funding-contract.md) and [internal transfers](internal-transfer-contract.md).

## Product rules

- Activity is a read-only view of committed immutable ledger entries. It never invents transactions or modifies a balance.
- The authenticated persisted session selects the customer's account. A caller cannot provide an account or owner identifier.
- The first slice includes `DEVELOPMENT_FUNDING` and `INTERNAL_TRANSFER` entries only. Every visible item is `COMPLETED` and `PHP`.
- Direction is relative to the signed-in account: a positive posting is `INCOMING`; a negative posting is `OUTGOING`.
- Funding uses the safe `SIMULATOR_ISSUER` counterparty type and no account reference. Transfers expose only an eight-character counterparty suffix in the list; detail may expose the paired KK10P account reference.
- Historical balance-after, search, status filtering, export/share/PDF, repeat transfer, disputes, reversals, fees, external rails, and admin access are outside Slice 7.

## Endpoints

Both endpoints require HTTPS and an eligible authenticated customer session, reject GET bodies, send `Cache-Control: no-store`, and share a dedicated 60-requests-per-minute client-IP budget with no queue.

### List current-account Activity

`GET /api/v1/accounts/me/transactions`

Allowed query parameters, each at most once:

| Parameter | Rule |
| --- | --- |
| `limit` | Canonical integer `1`–`50`; default `20`. |
| `cursor` | Opaque, canonical Base64Url cursor no longer than 64 characters. |
| `direction` | `INCOMING` or `OUTGOING`. Omit for all directions. |
| `type` | `DEVELOPMENT_FUNDING` or `INTERNAL_TRANSFER`. Omit for all types. |

Unknown, repeated, empty, noncanonical, or unsupported parameters return `400 invalid_activity_query`. Results use immutable keyset order by `occurredAtUtc DESC, transactionId DESC`; the server fetches one extra row to determine `nextCursor`.

```json
{
  "items": [
    {
      "transactionId": "11111111-1111-1111-1111-111111111111",
      "type": "INTERNAL_TRANSFER",
      "direction": "OUTGOING",
      "currency": "PHP",
      "amountMinor": "125",
      "status": "COMPLETED",
      "occurredAtUtc": "2026-09-10T01:02:03Z",
      "counterpartyType": "KK10P_ACCOUNT",
      "counterpartyReferenceSuffix": "22222222"
    }
  ],
  "nextCursor": null
}
```

`amountMinor` is an unsigned canonical integer string. The separate `direction` field determines whether the customer's posting was a credit or debit.

### Read one historical receipt

`GET /api/v1/accounts/me/transactions/{transactionId}`

`transactionId` must be one lowercase canonical, non-empty UUID. The endpoint returns a receipt only when the signed-in customer's own account has a posting in that transaction. A missing transaction and another customer's transaction produce the same `404 transaction_not_found` response.

```json
{
  "transactionId": "11111111-1111-1111-1111-111111111111",
  "type": "INTERNAL_TRANSFER",
  "direction": "OUTGOING",
  "currency": "PHP",
  "amountMinor": "125",
  "status": "COMPLETED",
  "occurredAtUtc": "2026-09-10T01:02:03Z",
  "accountReference": "33333333-3333-3333-3333-333333333333",
  "counterpartyType": "KK10P_ACCOUNT",
  "counterpartyAccountReference": "22222222-2222-2222-2222-222222222222"
}
```

## Stable failures

| HTTP | Code or behavior |
| ---: | --- |
| 400 | `invalid_activity_query` for invalid list parameters or transaction UUID. |
| 401 | Missing, invalid, expired, revoked, or ineligible authenticated session. |
| 404 | `account_not_opened` or privacy-preserving `transaction_not_found`. |
| 429 | Dedicated read budget exceeded, with `Retry-After`. |
| 500 | Safe unexpected failure without raw exception or response-body logging. |
| 503 | `activity_unavailable` when storage is unavailable or a committed journal cannot be projected safely. |

Logs contain only safe outcomes and timing. They do not include tokens, emails, names, complete account references, cursor content, amounts, idempotency keys, fingerprints, or response bodies.

## Ledger projection integrity

Before returning a row, the service validates the already committed journal: exactly two postings in positions 1 and 2, matching PHP currency and UTC timestamp, non-zero viewer posting, checked zero-sum arithmetic, and an operation-specific shape. Funding must pair one positive customer posting with one negative simulator-issuer posting. A transfer must pair one negative and one positive customer posting for different accounts.

An invalid shape fails the whole read closed with `503 activity_unavailable`; it is never partially or misleadingly rendered.

## Flutter boundary

Flutter protects `/activity` and `/activity/:transactionId`, strictly parses the server contract with integer minor units, permits one access-token refresh, and discards late results after session changes. Home exposes Activity only for a loaded account. Successful Development funding and internal transfer actions invalidate Activity so the next read starts from page one.

The list groups server rows by local calendar date, provides only compact direction/type filters, keeps existing rows visible on refresh/load-more failure, and requires explicit pagination. The full-screen receipt shows server facts, a readable local occurrence time, explicit UTC server time, simulator disclosure, and selectable references. It deliberately does not claim a historical balance-after value.

## Migration and rollout boundary

Migration `20260910054031_AddActivityHistoryIndex` adds only:

```text
IX_LedgerPostings_Account_CreatedAt_Transaction
  (CustomerAccountId ASC, CreatedAtUtc DESC, LedgerTransactionId DESC)
```

The shortened name remains within PostgreSQL's 63-byte identifier limit. The migration has no table, column, seed, backfill, delete, balance, or ledger-row operation. Its Down path drops only this index.

A fresh disposable `banking_lab_activity_test` database successfully upgraded through the existing funding/transfer schema, retained representative history, applied the index, paged through that history without duplication, performed no read-side writes, and was removed. Gate 7R later backed up and reconciled shared `banking_lab`, applied only the reviewed index migration while the API was quiesced, restarted the API, and passed authenticated read-only list/detail smoke checks without creating funding or transfers. See the [Gate 7R rollout report](../03_Walkthroughs/walkthrough-kk10p-gate-7r-shared-activity-index-rollout.md).

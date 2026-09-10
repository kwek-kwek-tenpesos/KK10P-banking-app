# Gate 7R Walkthrough: Shared Activity-Index Rollout

- Date: 2026-09-10 (`Asia/Shanghai`); backup timestamp is recorded in UTC.
- Result: Completed successfully. The shared schema has the Activity index, the API is running on loopback, and no funding or transfer was executed.
- Migration: `20260910054031_AddActivityHistoryIndex`.
- Contract: [Activity/history](../04_Architecture/activity-history-contract.md).

## Delivered outcome

Gate 7R safely added the read-side index used by owner-scoped Activity pagination. The API was already stopped, database application connections were absent, a fresh custom PostgreSQL backup was created and verified, only the approved migration was applied, protected data facts were reconciled, and the API restarted on `127.0.0.1:5255`. Live authenticated list and detail requests then returned valid no-store responses without changing shared state.

## Migration summary and risk level

The schema change is **low risk**, while its application to shared financial-history data has **medium operational consequence**. It adds one non-unique B-tree index to `LedgerPostings`:

```text
(CustomerAccountId ASC, CreatedAtUtc DESC, LedgerTransactionId DESC)
```

It creates no table, column, constraint, seed, backfill, account, balance, ledger transaction, posting, funding event, or transfer. Generated SQL contained exactly one `CREATE INDEX` followed by the EF migration-history insert.

## Destructive, compatibility, and data review

- No table/column/index drop, delete, truncate, type change, constraint change, cascade change, or data transformation exists in `Up`.
- Existing rows require no cleanup or compatibility conversion.
- Old API/mobile code tolerates the additional index.
- New Activity code remains logically compatible with the old schema, although the index is needed for predictable history-query performance as data grows.
- No background worker or administrator client depends on this schema.
- The `Down` migration drops only this index. Normal application rollback should leave the harmless index in place; dropping it still requires a separately reviewed migration action.

## Locking and index review

Ordinary PostgreSQL index creation can briefly block writes, so the API was quiesced even though `LedgerPostings` contained only 16 rows and occupied 8,192 bytes. The postflight catalog reported the index as ready and valid, with the exact approved name and sort order. It is non-unique and matches Activity's owner-first descending cursor query.

## Backup evidence

- Local ignored backup: `banking-lab/backups/banking_lab_gate7r_pre_20260910T071516Z.dump`.
- Format: PostgreSQL custom archive.
- Catalog: `pg_restore --list` succeeded with 79 data-definition/data entries.
- Size: 43,111 bytes.
- SHA-256: `D3A5439DB42C1F30DDA79D9E849DBB7283BF73065CE20A73534C8BEAA682A3CC`.
- The container and copied-local hashes matched. The archive extension is ignored by Git, and no credential was printed or committed.

## Reconciliation evidence

| Protected fact | Before | After migration | After authenticated smoke |
| --- | ---: | ---: | ---: |
| EF migrations | 7 | 8, approved ID last | 8 |
| Users | 4 | 4 | 4 |
| Sessions | 30 | 30 | 30 |
| Refresh tokens | 65 | 65 | 65 |
| Accounts | 2 | 2 | 2 |
| Combined balance (centavos) | 20,000,000 | 20,000,000 | 20,000,000 |
| Ledger transactions | 8 | 8 | 8 |
| Development funding operations | 4 | 4 | 4 |
| Internal transfer operations | 4 | 4 | 4 |
| Ledger postings | 16 | 16 | 16 |
| Posting amount sum | 0 | 0 | 0 |
| Invalid PHP account/balance rows | 0 | 0 | 0 |
| Malformed two-posting journals | 0 | 0 | 0 |
| Activity index rows in catalog | 0 | 1, valid and ready | 1 |

The stronger postflight journal check also confirmed matching transaction/posting currency and UTC timestamps, positions 1 and 2, the simulator-issuer funding shape, and distinct debit/credit accounts for internal transfers.

## Read-only live smoke evidence

The restarted Development API returned HTTP 200 from `/api/v1/system/info`. A short-lived in-memory verifier used one existing eligible session; it did not log in, rotate a refresh token, or persist a credential. The following protected requests passed:

- `GET /api/v1/auth/me`: HTTP 200.
- `GET /api/v1/accounts/me/transactions?limit=1`: HTTP 200, one server-backed item, continuation cursor present, `Cache-Control: no-store`.
- `GET /api/v1/accounts/me/transactions/{ownedTransactionId}`: HTTP 200, valid completed PHP receipt shape, `Cache-Control: no-store`.

The post-smoke reconciliation matched the post-migration state exactly. No funding or transfer was created.

## Safe deployment sequence used

```text
inspect migration source and exact generated SQL
  -> record shared counts, balances, operations, journals, connections and table size
  -> confirm API already stopped and no application database connection exists
  -> create, catalog-validate, hash and copy a fresh ignored custom backup
  -> recheck quiescence and exact pending migration
  -> apply only 20260910054031_AddActivityHistoryIndex
  -> verify history marker, exact index and unchanged protected state
  -> confirm EF has no pending migration
  -> restart API on loopback and check system info
  -> perform authenticated read-only Activity list/detail smoke
  -> reconcile protected shared state again
```

## Verification checklist

- [x] Migration source, generated SQL, application alignment, and rollback boundary reviewed.
- [x] Existing table size and journal compatibility checked.
- [x] API quiesced and database application connections absent.
- [x] Fresh custom backup created, catalog-validated, hash-matched, and ignored by Git.
- [x] Only `20260910054031_AddActivityHistoryIndex` applied.
- [x] Exact index definition is valid and ready; EF has no pending migration.
- [x] Users, sessions, tokens, accounts, balances, operations, journals, and postings reconciled.
- [x] API restarted and read-only health/authenticated Activity smoke passed.
- [x] No funding or transfer executed.
- [ ] Chris and Gio pull the Slice 7 commit and complete the physical-device checklist.

## Final recommendation

The shared Activity schema and loopback API are ready for Chris/Gio device acceptance. Keep the verified backup as the recovery point, leave the API running, and do not create additional money movement merely to test history; the eight existing reconciled operations already provide list, pagination, funding-receipt, and transfer-receipt coverage.

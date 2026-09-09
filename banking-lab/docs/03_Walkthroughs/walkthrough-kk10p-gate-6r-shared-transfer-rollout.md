# Gate 6R Walkthrough: Shared Internal-Transfer Rollout

- Date: 2026-09-10 (`Asia/Shanghai`); backup timestamp is recorded in UTC.
- Result: Completed successfully; shared schema is ready, API is running, and no transfer or funding action was executed.
- Migration: `20260909065721_AddInternalTransfers`.
- Contract: [internal transfer](../04_Architecture/internal-transfer-contract.md).

## Delivered outcome

Gate 6R safely enabled the existing internal-transfer operation in shared `banking_lab`. The exact API process was stopped, a custom PostgreSQL backup was created and validated, only the approved migration was applied, protected data facts were reconciled, and the Development API restarted on loopback with a successful read-only health response.

## Migration summary and risk level

Risk was **medium consequence, low execution complexity**. The migration touches financial-ledger enforcement, so backup and API quiescence were required. Its SQL only drops and recreates `CK_LedgerTransactions_Operation` inside one transaction, widening the accepted values from only `DEVELOPMENT_FUNDING` to exactly `DEVELOPMENT_FUNDING` or `INTERNAL_TRANSFER`, then records one EF history row.

It creates no table, column, index, seed, backfill, account, balance, ledger transaction, posting, or transfer. The four existing ledger rows all used `DEVELOPMENT_FUNDING`, so they satisfied both the old and new constraints.

## Destructive and compatibility review

- No table/column/data drop, delete, truncate, type change, cascade change, backfill, or index rebuild exists.
- The constraint is briefly dropped and recreated while the API is stopped; EF wraps both statements and the history marker in one transaction.
- Old code remains compatible with the widened constraint.
- New transfer code requires the widened constraint; therefore API quiescence prevented a new-code/old-schema write window.
- Existing Flutter clients are unaffected because no API request/response field changed.
- No background worker or administrator client is present.

## Locking, constraint, and rollback review

`ALTER TABLE` requires a short exclusive table lock. The table had only four rows and the API was quiesced, so observed lock/downtime risk was minimal. No indexes changed.

Forward application is safe. Down migration is only safe while zero `INTERNAL_TRANSFER` rows exist. After the first successful transfer, do not downgrade to the funding-only constraint; restore/recovery would need a separately reviewed plan.

## Backup evidence

- Local ignored backup: `banking-lab/backups/banking_lab_gate6r_pre_20260909T162411Z.dump`.
- Format: PostgreSQL custom archive, version 17.11.
- Catalog: 83 entries; `pg_restore --list` succeeded.
- Size: 41,939 bytes.
- SHA-256: `2836EA0F2307C78EEA0B2B3B5D4C2D31B38761865A3B7CC1C9D23C4FB93E9E27`.
- The backup extension is ignored by Git and no credential was written to tracked files or command output.

## Reconciliation evidence

| Fact | Before | After |
| --- | ---: | ---: |
| EF migrations | 6 | 7, approved ID last |
| Users | 4 | 4 |
| Sessions | 29 | 29 |
| Refresh tokens | 61 | 61 |
| Accounts | 2 | 2 |
| Combined balance (centavos) | 20,000,000 | 20,000,000 |
| Ledger transactions | 4 funding | 4 funding |
| Ledger postings | 8 | 8 |
| Posting amount sum | 0 | 0 |
| Malformed two-posting journals | 0 | 0 |
| Invalid account currency/balance | 0 | 0 |
| Internal transfers | 0 | 0 |

Postflight constraint inspection confirmed exactly the two approved operation values. `dotnet ef migrations list` showed no pending migration. The restarted API listened only on `127.0.0.1:5255`, and `GET /api/v1/system/info` returned HTTP 200 JSON.

## Safe deployment sequence used

```text
inspect migration + generated SQL
  -> inspect exact shared migration history/data/constraint
  -> gracefully stop exact loopback API process
  -> confirm no API listener/application database connection
  -> create and validate custom PostgreSQL backup
  -> target exact migration ID with EF
  -> verify history, constraint, counts, balances and journal conservation
  -> verify no pending migration
  -> restart API
  -> read-only HTTP health check
```

## Verification checklist

- [x] Migration source and exact generated SQL reviewed.
- [x] Existing operation values compatible.
- [x] API quiesced and database application connections absent.
- [x] Backup created, catalog-validated, hashed, and kept outside Git.
- [x] Only `20260909065721_AddInternalTransfers` applied.
- [x] History, constraint, row counts, balances, and ledger sums reconciled.
- [x] No transfer/funding write performed.
- [x] API restarted and read-only health check passed.
- [ ] Chris and Gio execute one small manual transfer and reconcile both balances.
- [ ] Optional controlled uncertainty retry confirms no duplicate debit.

## Final recommendation

The shared schema is ready for the first deliberately small Chris↔Gio fake-money transfer. Use the Slice 6 phone checklist, record sender/recipient balances before and after, and stop immediately if the receipt, debit, credit, or combined total disagrees. Activity/history remains deferred to Slice 7.

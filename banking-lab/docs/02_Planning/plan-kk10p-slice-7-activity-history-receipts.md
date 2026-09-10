# Slice 7 Plan: Account Activity, Transaction Detail, and Historical Receipts

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved for implementation on 2026-09-10; shared migration and live-device verification remain gated by separate Gate 7R approval
- Scope Mode: New Feature — backend-led immutable-ledger reads plus Flutter customer UI
- Parent Roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md)
- Authoritative Contracts: [Ledger/funding](../04_Architecture/ledger-development-funding-contract.md) and [internal transfer](../04_Architecture/internal-transfer-contract.md)
- Visual References Only: `D:\OtherProjects\Banking-UI-UX-Prototype` and the approved KK10P Flutter material
- Shared-State Boundary: shared `banking_lab` contains reconciled development-funding records and four intentional Slice 6 transfers; this plan does not authorize changing or deleting them

Notice: Update this plan in place while it is under review. After approval, track execution in `../01_Tracking/task.md`. A separate Gate 7R approval is required before applying any new migration to shared `banking_lab` or starting Chris/Gio live history verification.

---

## 1. Request Understanding and Goal

Build a truthful Activity experience from the immutable ledger already used by development funding and internal transfers. An authenticated customer can see only transactions posted to their own simulator account, page through them without duplicates, apply a small set of useful filters, open a transaction detail screen, and read an in-app historical receipt whose facts come from PostgreSQL.

The Kotlin prototype contributes the useful hierarchy—date groups, compact transaction rows, filter entry, status label, and detail composition—but not its fake merchants, selectable demo states, payment rails, disputes, repeat-payment actions, PDF/share controls, or fabricated receipt metadata.

### Concrete deliverables

1. Authenticated, account-scoped list and detail endpoints over `LedgerTransactions` and `LedgerPostings`.
2. Stable opaque cursor pagination with deterministic ordering and compact direction/type filters.
3. A protected Flutter `/activity` list and `/activity/:transactionId` detail route.
4. Date-grouped, responsive, pure-neumorphic transaction rows with complete loading, empty, filtered-empty, offline, error, refresh, and load-more states.
5. A share-free in-app historical receipt derived only from committed ledger facts.
6. Focused backend/Flutter tests, a concise implementation walkthrough after delivery, and a separately approved shared migration/device gate.

### Explicitly out of scope

- Search, date-range filters, amount-range filters, status filters, advanced filter drawers, or three permanent filter rows. Current history has only two operation types and one committed status, so those controls would add clutter without value.
- Pending/processing/failed ledger history, reversals, refunds, chargebacks, disputes, repeat transfer, saved beneficiaries, recurring/scheduled transfers, notes, categories, attachments, fees, payment rails, merchant enrichment, geolocation, tax data, or settlement timelines.
- PDF generation, share sheets/links, QR receipts, cryptographic seals, download/export, email, or push notifications.
- Fake prototype transactions, debug state selectors, skeleton/empty/error toggles, hard-coded names, or fabricated balances/timestamps.
- Final bottom navigation, Home recent-activity preview, Accounts/More destinations, or a broad Home redesign; those remain Slice 8.
- PIN/biometric restored-session lock, administrator dashboard behavior, Cloudflare Tunnel work, global material retuning, or Kotlin source changes.
- Editing/deleting ledger records, direct balance updates, cleanup of Chris/Gio test rows, or applying a shared migration without a separate Gate 7R approval.

## 2. Confirmed Product and UX Decisions

| Topic | Slice 7 decision | Reason |
| --- | --- | --- |
| Data source | Existing immutable ledger postings only | History remains reconciliable and cannot invent client-side events. |
| Ownership | Derive the current account from the authenticated user; accept no caller-supplied account ID | Prevents horizontal account access. |
| Transaction types | `DEVELOPMENT_FUNDING` and `INTERNAL_TRANSFER` | These are the only committed ledger operations today. |
| Direction | Derive `INCOMING`/`OUTGOING` from the authenticated account posting sign | Direction is server-owned and cannot be spoofed. |
| Status | Return `COMPLETED` for a valid committed journal | The schema has no pending transaction; a committed balanced pair is final in the current simulator. |
| List filters | Optional direction and type only | Both are useful now; search/status/date/amount controls are premature. |
| Pagination | Opaque keyset cursor, default 20 and maximum 50 | Stable and efficient without offset drift. |
| Ordering | `occurredAtUtc DESC`, then `transactionId DESC` | Same-time rows remain deterministic. |
| Balance-after | Omit from historical list/detail | The stored snapshot belongs to the initiating/source account and would be false for a recipient viewing an incoming transfer. |
| Counterparty | Masked suffix in the list; full involved account reference only on detail; simulator funding says `Simulator issuer` | Useful for recognition while minimizing list disclosure. |
| Receipt | Full-screen in-app detail, no share/export | Better for 200% text and honest to the current scope. |
| Home entry | One working `View activity` action after the loaded account surface | Enables the feature without prematurely introducing Slice 8 navigation. |
| Styling | Existing approved light/dark KK10P material; raised cards/buttons and inset only for selected/pressed/filter state | Preserves the accepted pure-neumorphic rules. |

## 3. Current Findings and Contract Review

| Observation / evidence | Technical interpretation |
| --- | --- |
| Every committed ledger transaction has two zero-sum, same-currency postings | Each activity row can be projected from the current customer's posting plus its paired posting. |
| `LedgerPosting` stores `CustomerAccountId`, signed `AmountMinor`, and `CreatedAtUtc` | Ownership, direction, absolute amount, and keyset order are available without new data columns. |
| Internal transfers post negative to source and positive to destination | The same transaction truthfully appears as outgoing for one customer and incoming for the other. |
| Development funding posts negative to `SIMULATOR_ISSUER` and positive to the customer | Funding appears as an incoming transaction with a non-customer counterparty. |
| `LedgerTransaction.BalanceAfterMinor` is the initiator/source balance snapshot | It must not be projected as a generic viewer balance in historical detail. |
| Existing posting indexes do not cover account plus page order | Add one non-destructive composite index for predictable keyset reads. |
| Flutter already has strict `BigInt` money parsing, bearer refresh, session-generation guards, error mapping, and receipt patterns | Activity should reuse these conventions rather than add a parallel architecture. |
| GoRouter protects only `/home` and `/transfer` | Both Activity routes must join the protected route set, including detail deep links. |
| Slice 6 deliberately deferred Activity cache invalidation | Transfer success will invalidate the new Activity provider; development funding will do the same. |
| The prototype Activity screen exposes fake state selectors and many unsupported controls | Keep its hierarchy but remove those controls and all fake transaction content. |

### Compatibility conclusion

No new ledger table or transaction field is required. Slice 7 needs read-only contracts/services/endpoints plus one additive index migration. Historical `balanceAfterMinor` is intentionally absent; reconstructing it per viewer would require a separately designed running-balance contract and is not necessary for a truthful first Activity slice.

## 4. Proposed API Contract

### 4.1 List current-account activity

```http
GET /api/v1/accounts/me/transactions?limit=20&cursor=<opaque>&direction=INCOMING&type=INTERNAL_TRANSFER
Authorization: Bearer <eligible-session-token>
```

Rules:

- `limit` is optional, canonical decimal text from `1` through `50`; default is `20`.
- `cursor` is optional, URL-safe, opaque, versioned, and strictly decoded. Its decoded sort key is the previous page's UTC occurrence time plus transaction UUID.
- `direction` is optional and accepts exactly `INCOMING` or `OUTGOING`; omission means both.
- `type` is optional and accepts exactly `DEVELOPMENT_FUNDING` or `INTERNAL_TRANSFER`; omission means both.
- Unknown, duplicate, empty, malformed, overlong, or differently cased parameters return `400 invalid_activity_query`.
- GET bodies are rejected. The route accepts no account/user identifier from the caller.

Successful response:

```json
{
  "items": [
    {
      "transactionId": "00000000-0000-0000-0000-000000000000",
      "type": "INTERNAL_TRANSFER",
      "direction": "OUTGOING",
      "currency": "PHP",
      "amountMinor": "1200000",
      "status": "COMPLETED",
      "occurredAtUtc": "2026-09-10T00:00:00Z",
      "counterpartyType": "KK10P_ACCOUNT",
      "counterpartyReferenceSuffix": "1234abcd"
    }
  ],
  "nextCursor": null
}
```

Contract notes:

- `amountMinor` is an absolute canonical unsigned integer string; Flutter never parses it through floating point.
- A funding row uses `counterpartyType: "SIMULATOR_ISSUER"` and `counterpartyReferenceSuffix: null`.
- `nextCursor` is present only as a string when another page exists; otherwise it is JSON `null`.
- The API fetches at most `limit + 1`, returns at most `limit`, and creates the cursor from the final returned row.
- The API never returns user IDs, names, email/phone, recipient balance, idempotency key, request fingerprint, book-account internals beyond the safe counterparty enum, or full counterparty reference in a list response.

### 4.2 Read one historical transaction

```http
GET /api/v1/accounts/me/transactions/{transactionId}
Authorization: Bearer <eligible-session-token>
```

Successful response:

```json
{
  "transactionId": "00000000-0000-0000-0000-000000000000",
  "type": "INTERNAL_TRANSFER",
  "direction": "OUTGOING",
  "currency": "PHP",
  "amountMinor": "1200000",
  "status": "COMPLETED",
  "occurredAtUtc": "2026-09-10T00:00:00Z",
  "accountReference": "00000000-0000-0000-0000-000000000000",
  "counterpartyType": "KK10P_ACCOUNT",
  "counterpartyAccountReference": "00000000-0000-0000-0000-000000000000"
}
```

For development funding, `counterpartyType` is `SIMULATOR_ISSUER` and `counterpartyAccountReference` is `null`.

Detail rules:

- `transactionId` must be a canonical non-zero UUID.
- The service first scopes by the authenticated customer's account posting, not by transaction alone.
- A nonexistent transaction and a transaction owned only by another account both return the same `404 transaction_not_found`; no existence information leaks.
- An authenticated customer without an open account receives `404 account_not_opened` on both endpoints.
- An invalid/malformed journal shape is not partially displayed. Return `503 activity_unavailable`, attach the normal request correlation ID, and emit a safe integrity log without amounts or account references.

### 4.3 Pagination pseudocode

```text
accountId = find open account owned by authenticated user
query = postings where CustomerAccountId == accountId
join transaction and paired posting
apply server-derived direction/type filters
order by posting.CreatedAtUtc descending, LedgerTransactionId descending

IF cursor exists:
    query where occurredAt < cursor.occurredAt
       OR (occurredAt == cursor.occurredAt AND transactionId < cursor.transactionId)

rows = take(limit + 1)
validate each journal projection
items = first limit rows
nextCursor = encode sort key of items.last only when rows has an extra item
```

Because the ledger is append-only, new transactions may appear before an already issued cursor but cannot make the next page repeat or skip rows from the stable result set. Pull-to-refresh starts again without a cursor.

### 4.4 HTTP, cache, throttling, and errors

- HTTPS is mandatory before bearer processing, including trusted loopback proxy handling already used by the app.
- Every Activity response, including auth/rate/error responses, sends `Cache-Control: no-store`.
- Add a fixed-window `activity` read policy of 60 requests per minute per remote IP, no queue, with `Retry-After` on `429`.
- Both endpoints require the existing eligible session-backed bearer principal and permit one normal Flutter refresh/retry after `401`.
- Expected failures use stable Problem Details codes: `invalid_activity_query`, `account_not_opened`, `transaction_not_found`, `activity_rate_limited`, and `activity_unavailable`.
- Requests are cancellation-aware. Logs may contain route, safe outcome, page size, elapsed time, and request ID, but not bearer/refresh tokens, complete account references, cursor content, transaction amounts, emails, names, idempotency keys, fingerprints, or response bodies.
- GET execution is read-only: no account balance, ledger, session, or customer row is changed.

## 5. Database and Migration Design

Add only this model index:

```text
LedgerPostings(CustomerAccountId, CreatedAtUtc DESC, LedgerTransactionId DESC)
```

Planned database name:

```text
IX_LedgerPostings_CustomerAccountId_CreatedAtUtc_LedgerTransactionId
```

Rationale and safety:

- `CustomerAccountId` is the ownership predicate; timestamp plus transaction ID is the page order/tie-break.
- The change is additive: no new table, column, constraint, backfill, ledger rewrite, or balance edit.
- Keep the existing single-column and transaction-position indexes unless PostgreSQL evidence later justifies a separately reviewed cleanup.
- Generate the EF Core migration during implementation, inspect its Up/Down operations, test it on a disposable PostgreSQL database containing representative funding/transfers, and verify rollback removes only this index.
- Do not apply it to shared `banking_lab` during implementation. Gate 7R separately backs up/quiesces/verifies/applies exactly the generated migration and then restarts the API.

## 6. Flutter Journey and Screen Composition

### 6.1 Home entry

- When the account is loaded, show one working secondary `View activity` action after the account surface and before Sign out.
- Do not show it while the account is unopened, opening, loading, uncertain, or unavailable.
- Keep the existing Transfer/Refresh account actions unchanged and avoid a premature bottom bar.

### 6.2 Activity list

- App bar: Back, `Activity`, Refresh, and one compact Filter action.
- Intro copy remains short and clearly identifies simulator history.
- Group rows by the device-local calendar date: `Today`, `Yesterday`, then an unambiguous localized date. Server timestamps remain UTC in models.
- Row titles are server-fact-derived UI labels: `Simulator funding`, `Transfer received`, or `Transfer sent`.
- Row subtitle shows local date/time plus `Simulator issuer` or a masked account reference such as `Account •••• abcd`.
- Amount includes an explicit plus/minus sign, PHP formatting, direction text/semantics, and an icon; color is supplementary only.
- Every row shows `Completed` as text plus icon and opens its transaction detail.
- A visible `Load more` control fetches the next page. Do not use an invisible endless-scroll trigger as the only pagination mechanism.

### 6.3 Compact filters

- One Filter button opens a scroll-safe bottom sheet containing Direction (`All`, `Incoming`, `Outgoing`) and Type (`All`, `Simulator funding`, `Internal transfer`).
- Selected choices use the approved inset/selected treatment; unselected options are raised/flat according to the shared controls.
- Applying a different filter discards the old cursor/items and performs a fresh first-page read.
- The list header summarizes active filters with concise removable chips; Clear filters restores the unfiltered first page.
- Do not add status/search/date/amount controls in this slice.

### 6.4 Loading, empty, offline, and pagination states

- Initial loading uses a small truthful progress state, not fake transaction skeleton content.
- An account with no ledger entries shows `No activity yet` and explains that completed simulator funding/transfers will appear here.
- A valid filter with no matches shows `No matching activity` with a working Clear filters action.
- Initial network/server failure shows the mapped safe message plus Retry.
- Pull/toolbar refresh retains no stale cursor and replaces the collection only after a successful new first page; failure may keep existing rows with a non-destructive message.
- Load-more failure keeps existing items and the same cursor, then offers `Try loading more` without duplicating rows.
- Rapid Refresh/Filter/Load-more taps are serialized; stale or logged-out responses cannot replace newer state.

### 6.5 Transaction detail and historical receipt

- Use a protected full-screen route rather than a cramped modal.
- Header and hero show `Transaction details`, the exact signed/labelled amount, type, direction, and Completed state.
- Receipt fields: transaction ID, server occurrence time (readable local time plus explicit UTC detail), current customer's account reference, counterparty type/reference, currency, and simulator disclosure.
- Funding displays `Simulator issuer`; a transfer displays the full other involved simulator account reference.
- Long UUIDs are selectable/wrappable and never clipped.
- Detail loading, not-found, authentication loss, offline, invalid-response, and Retry states are explicit.
- Do not show balance-after, fees, bank rails, names, email/phone, pending timelines, dispute/repeat controls, QR, PDF, share, or download.

## 7. Flutter State and Logic Design

### Strict models

```text
ActivityItem
    transactionId (canonical non-zero UUID)
    type (known enum only)
    direction (known enum only)
    currency (PHP only)
    amountMinor (canonical positive integer string -> BigInt)
    status (COMPLETED only)
    occurredAtUtc (strict UTC timestamp)
    counterpartyType (known enum only)
    counterpartyReferenceSuffix (required only for KK10P account)

ActivityPage
    items (bounded list)
    nextCursor (null or bounded non-empty opaque string)

ActivityDetail
    ActivityItem facts plus own reference and nullable full counterparty reference
```

Unknown enums, malformed UUIDs/timestamps/amounts, mismatched nullable counterparty fields, excess items, duplicate transaction IDs, or invalid cursor shape make the response invalid; Flutter shows a safe server-data error rather than guessing.

### List controller states

```text
initialLoading
loaded(items, nextCursor, filters, refreshing?, loadingMore?)
empty(filters)
initialFailure(message, requestId?)
loadedWithRefreshFailure(items, cursor, filters, message)
loadedWithPaginationFailure(items, cursor, filters, message)
```

Controller rules:

- Bind every request to the current authenticated customer/session generation.
- Initial load and filter changes replace data; refresh starts at page one; load-more uses exactly the stored next cursor.
- Keep a transaction-ID set while appending as a defensive duplicate guard, but treat server duplicate pages as invalid rather than silently masking a contract bug.
- One bearer refresh may retry the exact GET once; final `401` invalidates authentication.
- Dispose/cancel work when the route leaves where practical, and ignore late generations in every case.
- Invalidate Activity after confirmed internal transfer and confirmed development funding so a subsequently visible list reloads from page one.

### Detail controller

- Fetch by route transaction ID after local canonical UUID validation.
- Use the same auth refresh/session-generation rules as the list.
- Do not fabricate detail from the list item; the list may provide a temporary visual transition, but the historical receipt is complete only after the detail endpoint validates.

## 8. Planned File Changes

Exact private widget boundaries may be combined during implementation when that keeps files small without changing the contract.

| Change | Path | Responsibility |
| --- | --- | --- |
| Add | `banking-lab/backend/Banking.api/Features/Activity/ActivityContracts.cs` | Filter enums, list/detail DTOs, cursor codec, and stable outcome constants. |
| Add | `banking-lab/backend/Banking.api/Features/Activity/ActivityRequestGuards.cs` | HTTPS/no-store, body/query/UUID limits, strict parameter validation, and read rate limiter. |
| Add | `banking-lab/backend/Banking.api/Features/Activity/ActivityService.cs` | Owner-scoped keyset query, direction/type projection, paired-posting integrity validation, and detail lookup. |
| Add | `banking-lab/backend/Banking.api/Features/Activity/ActivityEndpoints.cs` | List/detail route mapping and stable Problem Details responses. |
| Modify | `banking-lab/backend/Banking.api/Program.cs` | Register/map Activity services, guards, middleware, no-store, and throttling. |
| Modify | `banking-lab/infrastructure/temporary/AppDbContext.cs` | Add the composite posting history index definition only. |
| Add | `banking-lab/backend/Banking.api/Migrations/<generated>_AddActivityHistoryIndex.cs` | Additive index-only migration; exact generated name recorded after implementation. |
| Modify | `banking-lab/backend/Banking.api/Migrations/AppDbContextModelSnapshot.cs` | Generated index model snapshot. |
| Add | `banking-lab/backend/tests/Banking.IntegrationTests/ActivityEndpointTests.cs` | Auth, ownership, query guards, mapping, paging, errors, caching, and rate limiting without shared DB. |
| Add | `banking-lab/backend/tests/Banking.IntegrationTests/PostgresActivityTests.cs` | Opt-in disposable PostgreSQL migration, stable cursor, paired journals, index, and read-only behavior. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/data/models/activity_models.dart` | Strict list/detail/cursor parsing and exact `BigInt` amounts. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/data/services/activity_api_service.dart` | Exact GET construction, HTTPS/no-redirect behavior, statuses, Problem Details, and request correlation. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/data/repositories/activity_repository.dart` | Valid token, one refresh, session-generation checks, and list/detail boundary. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/controllers/activity_controller.dart` | Filters, first page, refresh, load-more, stale-result suppression, and partial failure states. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/controllers/activity_detail_controller.dart` | Account-scoped historical receipt loading/retry. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/screens/activity_screen.dart` | Responsive grouped list and all truthful states. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/screens/activity_detail_screen.dart` | Full-screen accessible historical receipt. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/widgets/activity_transaction_card.dart` | Raised compact row with non-color-only direction/status. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/activity/presentation/widgets/activity_filter_sheet.dart` | Compact direction/type controls using shared material. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Loaded-account-only `View activity` entry. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/controllers/internal_transfer_controller.dart` | Invalidate Activity after a confirmed receipt. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/development_funding/presentation/controllers/development_funding_controller.dart` | Invalidate Activity after confirmed funding. |
| Modify | `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Add/protect list and detail routes, including deep links. |
| Add/Modify | `banking-lab/mobile/banking_mobile/test/features/activity/**` | Models, service, repository, controller, screen, detail, filters, paging, semantics, and responsive tests. |
| Modify | `banking-lab/mobile/banking_mobile/test/features/home/customer_home_screen_test.dart` | Loaded/unavailable Activity entry behavior. |
| Modify | `banking-lab/mobile/banking_mobile/test/widget_test.dart` | Protected list/detail routes and app-level regressions. |
| Add after delivery | `banking-lab/docs/04_Architecture/activity-history-contract.md` | Implemented canonical API/privacy/pagination contract. |
| Add after delivery | `banking-lab/docs/03_Walkthroughs/walkthrough-kk10p-slice-7-activity-history-receipts.md` | Outcome, concepts, flow, paths, exact PowerShell commands, test results, recovery, and phone checklist. |

No Kotlin prototype, global material token, authentication schema, ledger row, account balance, admin prototype, or Cloudflare configuration is planned to change.

## 9. Implementation Sequence

1. **Baseline and contract fixtures**
   - Record clean Git status and current backend/Flutter verification.
   - Create exact ledger scenarios for Chris funding, Chris→Gio, Gio→Chris, same-timestamp ties, an unrelated third customer, and malformed journal rejection.

2. **Backend contract and pure cursor logic**
   - Implement strict filter parsing, DTOs, versioned cursor encode/decode, and journal projection validation with focused tests.

3. **Owner-scoped read service and endpoints**
   - Add list/detail queries, identical non-owned/not-found behavior, HTTPS/no-store/input guards, read throttling, safe logs, and stable Problem Details.

4. **Additive index migration in disposable PostgreSQL only**
   - Add the model index, generate the migration, inspect SQL/Up/Down, migrate a disposable database with existing ledger rows, test pagination/query behavior, and roll back the disposable database.
   - Do not touch shared `banking_lab`.

5. **Flutter data boundary**
   - Add strict models, service, repository, one-refresh auth behavior, safe error mapping, and account/session isolation tests.

6. **List/detail state machines**
   - Implement first load, refresh, filters, load-more, partial failure recovery, detail loading, invalidation, and stale-result suppression.

7. **Responsive pure-neumorphic UI**
   - Build Home entry, date groups, rows, compact filter sheet, empty/error/pagination states, and full-screen receipt using the approved shared components.
   - Do not retune global material or add unsupported prototype controls.

8. **Automated quality and security gates**
   - Run formatting, analysis, focused and complete suites, migration/model checks, ownership/privacy checks, and repository diff review.
   - Run only the opt-in disposable Activity PostgreSQL fixture against its dedicated test database.

9. **Separate Gate 7R — shared rollout (not authorized by plan approval)**
   - Reconcile current shared balances/ledger counts/sums and migration state.
   - Create a fresh backup, quiesce the API, apply only the reviewed Activity index migration, verify schema/data/invariants, restart the API, and perform read-only API smoke checks.

10. **Commit before Gio-dependent verification**
    - After automated checks and Gate 7R pass, create the user-authorized detailed Git commit before asking Gio to build/test; the user pushes it to the organization repository.
    - Suggested subject: `feat(activity): add account history and receipts`.

11. **Chris/Gio real-device acceptance and closure**
    - Verify each customer sees their own side of existing transfers, cannot access the other's unrelated records, and receives matching details.
    - No new transfer/funding is required unless a separately agreed small test is necessary.
    - Deliver the concise walkthrough and archive the completed tracking task.

## 10. Acceptance Criteria

### Backend contract and ownership

- [ ] Both endpoints require an eligible authenticated session and derive the account from that principal.
- [ ] A customer sees exactly ledger transactions containing their account posting and no unrelated customer's transaction.
- [ ] Non-owned and nonexistent detail IDs return the same `404 transaction_not_found` response.
- [ ] Funding and internal-transfer journals project the correct server-owned type, direction, absolute amount, status, timestamp, and counterparty.
- [ ] No list/detail response exposes user IDs, personal identity, idempotency keys, fingerprints, recipient balance, or generic/historically false balance-after data.
- [ ] Malformed journals fail safely instead of producing plausible but false receipts.

### Pagination, filtering, and read safety

- [ ] Unfiltered and filtered pages use `(occurredAtUtc DESC, transactionId DESC)` keyset order.
- [ ] Same-timestamp test rows page with no duplicates or missing items under stable data.
- [ ] A new ledger row inserted before an issued cursor does not appear in or disturb the older continuation page; a refresh shows it.
- [ ] Limits, cursors, direction/type filters, unknown/duplicate/empty parameters, canonical UUIDs, and GET bodies are strictly enforced.
- [ ] List/detail GETs perform no database write and do not modify balances or journals.
- [ ] Every response is no-store, plain HTTP is rejected before bearer processing, and throttling returns actionable `429` metadata.
- [ ] The composite index migration is additive, verified on disposable PostgreSQL, and not applied to shared data without Gate 7R approval.

### Flutter behavior

- [ ] Only a loaded authenticated customer sees a working Home Activity entry; signed-out list/detail deep links return to Login.
- [ ] Activity renders server rows in local date groups with explicit direction, exact PHP amount, status text/icon, safe counterparty display, and no fake content.
- [ ] Compact direction/type filters replace the prototype's permanent rows and restart pagination correctly.
- [ ] Initial loading, empty, filtered-empty, offline/server error, refresh failure, and pagination failure each provide a truthful recovery action.
- [ ] Refresh/filter/load-more rapid taps do not duplicate requests/items, and stale responses cannot cross logout/customer changes.
- [ ] Transfer/funding confirmation invalidates Activity so later reads are fresh.
- [ ] Detail uses the server endpoint, displays only approved receipt facts, wraps/selects long references, and contains no share/PDF/dispute/repeat behavior.

### Design, responsiveness, and accessibility

- [ ] Light/dark modes use the approved pure-neumorphic material without global retuning, orange primary accents, or excessive inset surfaces.
- [ ] Raised cards/actions and inset selected/pressed states remain perceptible without relying only on shadows or color.
- [ ] List, filter sheet, empty/error states, and detail are scroll-safe at 320/360/412 logical widths, tablet width, and 200% text.
- [ ] TalkBack announces date group, type, incoming/outgoing direction, signed amount, completion status, counterparty, action, loading/error changes, and receipt fields in a coherent order.
- [ ] Touch targets are at least 48 logical pixels and keyboard/focus traversal remains logical.
- [ ] Content remains clear in grayscale and direction/status are never color-only.

### Scope and handoff

- [ ] No bottom navigation, Home recent-activity block, unsupported operation, fake record, admin work, app lock, public tunnel, or theme redesign is introduced.
- [ ] Automated work and disposable PostgreSQL tests do not write shared `banking_lab`.
- [ ] Gate 7R occurs only after separate approval and preserves all reconciled shared entries/balances.
- [ ] The Gio-dependent device build starts from the committed implementation, and the user receives exact startup/test commands in the walkthrough.

## 11. Automated Verification Plan

From `banking-lab/backend`:

```powershell
Remove-Item Env:BANKING_ACTIVITY_TEST_DATABASE -ErrorAction SilentlyContinue
dotnet test Banking.slnx -c Release --no-restore
```

The ordinary suite must not opt into a PostgreSQL fixture or write shared state. The implementation walkthrough will provide the separately configured disposable-database command for `PostgresActivityTests`; its database name must end in `_test`, be created for that fixture, and be removed only after exact target verification.

Planned backend coverage:

- authentication/session eligibility, account-not-opened, HTTPS, no-store, request ID, rate limit, cancellation, and unavailable storage;
- owner isolation with three customers and identical not-found/non-owned detail responses;
- funding/outgoing/incoming projections, safe counterparties, exact canonical string amounts, and invalid journal rejection;
- default/min/max/invalid limits, strict filters, duplicate/unknown parameters, invalid bodies and UUIDs;
- opaque cursor round trip, corruption/overlength, same-time UUID ties, filtered pages, stable insertion, final null cursor, and no writes;
- disposable PostgreSQL fresh upgrade, upgrade with existing rows, exact index definition, query behavior, invariants, and Down removing only the index.

From `banking-lab/mobile/banking_mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/activity --reporter compact
flutter test --reporter compact
```

Planned Flutter coverage:

- strict list/detail parsing for every enum, UUID, amount, UTC timestamp, nullable counterparty, item bound, duplicate ID, and cursor case;
- exact query encoding, no accidental empty/`All` parameters, HTTPS/no redirect, success/status/error/trace mapping;
- valid token, one `401` refresh, final auth invalidation, and stale session/customer results;
- first load, refresh, filter reset, pagination, rapid taps, partial failure retention/retry, provider invalidation, and deduplication contract failure;
- funding/sent/received rows, Today/Yesterday/date groups with injected clock/timezone, detail receipt, empty/error/offline states, and protected routes;
- 320/360/412 width, tablet width, 200% text, light/dark material, focus/touch targets, semantics, and absence of unsupported prototype labels.

## 12. Manual Chris/Gio Checklist After Gate 7R

1. Pull the committed Slice 7 implementation, start Docker/PostgreSQL, start the ASP.NET API, and run Flutter using the exact PowerShell commands in the delivered walkthrough.
2. Sign in as Chris and open Activity from loaded Home. Confirm existing funding and sent/received transfer rows match Chris's known balance history.
3. Sign in as Gio on the second device/build. Confirm the same shared transfer has the opposite direction but identical amount, timestamp, transaction ID, and Completed status.
4. Open each side's detail. Confirm `Your account` and `Other account` are correctly reversed and neither customer sees names, email, recipient balance, keys, or request data.
5. Try All/Incoming/Outgoing and All/Funding/Internal transfer filters; verify empty filtered results can be cleared.
6. Refresh repeatedly and tap Load more/Filter rapidly. Confirm no duplicated rows, crashes, stale filter results, or false error/success messages.
7. Temporarily interrupt network before a read, restore it, and use Retry. Reads must not affect balances or create ledger rows.
8. Check light/dark mode, 200% text, TalkBack order, long UUID wrapping/selection, and 320-width layout. Record clipping, ambiguous direction, inaccessible controls, excessive depth, or content hidden under system insets.
9. Reconcile database counts, each transaction's zero-sum pair, and Chris+Gio balances after testing; read-only Activity checks must leave all values unchanged.

## 13. Risks, Recovery, and Rollback

| Risk | Mitigation / recovery |
| --- | --- |
| Customer can enumerate another transaction | Scope the query by authenticated account posting and make non-owned indistinguishable from missing. |
| Offset drift duplicates/skips records | Use immutable keyset order with timestamp plus UUID and test same-time ties/new inserts. |
| Recipient sees sender-only balance snapshot | Omit historical balance-after entirely. |
| Malformed journal produces misleading history | Validate operation-specific paired postings and fail the read safely with correlation. |
| Activity becomes as cramped as the prototype | One compact filter entry, no search/status row, scroll-first receipt, and responsive tests. |
| List cache remains stale after a transfer/funding result | Invalidate on confirmed writes and fetch a new first page on entry/refresh. |
| Index migration affects shared use | Test separately, back up and quiesce under Gate 7R, apply one additive migration, then verify before restart. |
| Shared verification accidentally changes money | Use existing entries for read tests; any new transfer/funding requires separate agreement and reconciliation. |
| Slice 7 application code must be reverted | Revert backend/Flutter Activity integration; existing ledger remains valid. The unused additive index may remain safely until a separately reviewed rollback. |

## 14. Approval Boundary and Recommended Next Step

Approval of this plan will authorize the planned backend Activity endpoints, additive migration source, Flutter Activity/detail implementation, automated/disposable tests, contract documentation, and delivery walkthrough. It will **not** authorize:

- applying the new migration to shared `banking_lab`;
- creating/deleting a database outside the exact disposable test fixture;
- funding/transferring/editing/deleting shared fake money;
- Gate 7R, Chris/Gio live Activity verification, ZAP active scanning, public tunnel changes, admin work, or a push;
- bottom navigation, Home recent activity, search/advanced filters, or any excluded feature.

Recommended next step: review this Slice 7 boundary. After explicit approval, implement and verify against in-memory/disposable test state, then return with the exact generated migration and evidence for separate Gate 7R approval.

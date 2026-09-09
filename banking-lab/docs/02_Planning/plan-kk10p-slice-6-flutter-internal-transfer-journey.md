# Slice 6 Plan: Flutter Internal Transfer Journey

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved and implemented; automated verification passed and Gate 6R shared migration completed on 2026-09-10, while the small live phone transfer remains manual
- Scope Mode: New Feature — Flutter-first customer journey over the already-implemented internal-transfer API
- Parent Roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md)
- Authoritative Contract: [Internal transfer](../04_Architecture/internal-transfer-contract.md)
- Visual Reference Only: `D:\OtherProjects\Banking-UI-UX-Prototype`
- Shared-State Gate: the reviewed `20260909065721_AddInternalTransfers` migration is still unapplied to shared `banking_lab`; plan approval does not authorize that migration or a live transfer

Notice: Update this plan in place while it is under review. After approval, track execution in `../01_Tracking/task.md` and do not re-read this full plan unless its architecture or scope changes.

---

## 1. Request Understanding and Goal

Build the first truthful customer-facing transfer journey in Flutter. An authenticated customer will paste another KK10P simulator account reference, enter an exact PHP amount, review the irreversible fake-money movement, submit it once, and receive a server-authored completion receipt or an actionable failure state.

The Kotlin prototype supplies composition ideas—clear step identity, focused cards, a review summary, processing feedback, and a result surface—but not product facts or code. Flutter, Riverpod, GoRouter, the existing pure-neumorphic material, the ASP.NET API, and PostgreSQL remain authoritative.

### Concrete deliverables

1. A protected `/transfer` Flutter journey with Recipient, Amount, Review, Processing, Uncertain, Failure, and Success states.
2. Exact transfer API models/service/repository behavior, including one safe bearer refresh and strict receipt validation.
3. A transfer state machine that prevents duplicate taps and persists an unresolved request's UUID key plus exact payload in device secure storage so the same request can be reconciled after navigation or app restart.
4. A clean Home entry action and an accessible way to copy the current customer's simulator account reference for Chris/Gio testing.
5. Automated tests, a future concise educational walkthrough, and a separately approved shared-migration/live-device gate.

### Explicitly out of scope

- Activity/history list and historical receipt lookup; those remain Slice 7.
- Bottom navigation or a broad Home redesign; those remain Slice 8.
- PIN, fingerprint, Face ID, OTP, or transfer step-up authorization. Restored-session app lock is a later security slice.
- Recipient search by name/email/phone, saved beneficiaries, multiple source accounts, other banks, InstaPay/FedNow/ACH/wire rails, QR transfer, request money, schedules, recurring transfers, fees, delivery speed, purpose categories, notes, attachments, PDF, share links, notifications, reversals, disputes, or pending settlement.
- Any fake recipient identity, fake transaction reference, fake timestamp, selectable simulated outcome, or hard-coded customer/account data from the prototype.
- Backend endpoint/schema redesign, administrator features, Cloudflare Tunnel, theme-transition polish, or a new package dependency.
- Automatic funding, seed transfers, direct balance edits, or applying a migration to shared `banking_lab` without a separate explicit approval.

## 2. Confirmed Product and UX Decisions

| Topic | Slice 6 decision | Reason |
| --- | --- | --- |
| Transfer type | Internal fake PHP between two distinct open KK10P accounts | This is the implemented server contract. |
| Recipient input | Canonical simulator account UUID only | The backend exposes no safe recipient lookup or personal data. |
| Source input | No selector; derive the source from the authenticated session | Prevents impersonation and matches the API. |
| Amount | PHP 0.01–50,000.00; parse directly to integer centavos | No floating-point money. |
| Daily limit | Explain PHP 100,000 outgoing per Philippine day; server remains authoritative | There is no endpoint for reliable client-side remaining-limit calculation. |
| Note | Omitted | The endpoint accepts exactly two fields and rejects unknown fields; a local-only note would be deceptive and would disappear from history. |
| Authorization step | Omitted | A valid persisted bearer session authorizes Slice 6; app lock/step-up is not implemented yet. |
| Steps | Recipient → Amount → Review → server result | Keeps one decision and one primary action per step. |
| Immediate receipt | Display only fields returned by the POST response | Slice 6 owns the immediate result; Slice 7 owns persisted history/detail retrieval. |
| Activity refresh | Refresh the account now; connect Activity invalidation when Slice 7 creates that provider | No mock or nonexistent activity state. |
| Styling | Existing KK10P light/dark material and controls | The material proof is approved; this slice must not retune global shadows/colors. |
| Prototype usage | Copy layout principles only | Its rails, fees, identities, auth simulations, and generated receipts conflict with KK10P. |

## 3. Current Findings and Contract Review

| Observation / evidence | Technical interpretation |
| --- | --- |
| `POST /api/v1/transfers/internal` is implemented and contract-tested | Flutter can integrate with a real endpoint instead of mock settlement logic. |
| The request accepts exactly `destinationAccountReference` and string `amountMinor` | The roadmap's optional note must be removed for this slice. |
| Success may be `201` or same-key replay `200` | Both are successful receipts; a replay must not look like a second debit. |
| The API can return stable recipient, self-transfer, funds, daily-limit, idempotency, auth, rate-limit, and server errors | The feature service should map these codes to distinct safe customer states. |
| Network/timeout/`500`/`503`/invalid-response failures can occur after commit | The UI must call this “status unconfirmed” and retry the identical payload with the identical idempotency key. |
| A screen-local key disappears when a route is disposed or the app restarts | The unresolved envelope must be written to secure storage before the first request and removed only after a confirmed or definitive outcome. |
| Account state already uses `BigInt`, session-generation guards, and one refresh after success | Transfer should follow these patterns and invalidate `accountControllerProvider` after confirmation. |
| GoRouter currently protects only `/home` | `/transfer` must join the protected-route set and redirect a signed-out deep link to `/login`. |
| Home intentionally contains no unsupported Transfer action yet | The new action is added only with the working journey; it must never be a dead button. |
| The shared database lacks the Slice 5 constraint migration | Automated Flutter work can proceed with fakes, but real-device submission must wait for the separately approved migration rollout. |

### API compatibility matrix

| Flutter request/response concern | Backend definition | Planned handling |
| --- | --- | --- |
| Method/path | `POST /api/v1/transfers/internal` | Exact fixed path; no query parameters. |
| Auth | Persisted eligible bearer session | Repository gets a valid token and retries once after `401`, using the same key/payload. |
| Idempotency | One lowercase UUID in `Idempotency-Key` | Generate with `Random.secure`, persist before send, never regenerate for uncertainty. |
| Destination | Canonical non-empty lowercase UUID | Trim/lowercase and locally validate; also reject the visible source reference. |
| Amount | Canonical integer string `1..5000000` | Parse display PHP directly to `BigInt` centavos and serialize with `toString()`. |
| First success / replay | `201` / `200`, same receipt plus `replayed` | Accept only these statuses; validate all receipt fields strictly. |
| Recipient missing | `404 recipient_not_found` | Definitive field-level recipient error; permit correction. |
| Account/self/funds/limit/key | Named `409` codes | Distinct safe messages and actions; do not flatten to generic server failure. |
| Rate limit | `429` plus `Retry-After` | The route guard did not execute the transfer. Retain the staged key/payload for a deliberate retry after the wait, or allow safe cancellation of this known-uncommitted request. |
| Server/storage uncertainty | `500`/`503`, connection, timeout, malformed success | Preserve stored request and offer “Check transfer status” using the same POST. |
| Correlation | `X-Request-ID` and Problem Details `traceId` | Preserve a safe reference in transfer failure state when available for diagnosis; never log body/token/key. |

No blocking frontend/backend mismatch remains after omitting the unsupported note and deferring Activity invalidation to Slice 7.

## 4. Customer Journey and Screen Composition

### Home entry

- In the loaded account card, add a blue primary `Transfer funds` action and retain `Refresh balance` as the secondary action.
- Add a small, explicitly labelled `Copy account reference` action beside/below the selectable reference so another tester can share the exact UUID without retyping it.
- Do not show the transfer action for loading, unopened, opening, uncertain-open, or account-error states.
- Opening `/transfer` directly still requires authentication and a loaded open account; otherwise show a truthful blocked/retry state instead of crashing.

### Step 1 — Recipient

- Header: `Transfer simulator funds`, Back action, and persistent fake-money disclosure.
- Compact three-step indicator: Recipient, Amount, Review. Completed steps may be revisited before submission.
- One inset/field surface labelled `Recipient account reference` with UUID keyboard-safe text input, normal paste support, no suggestions/autocorrect, and a clear action.
- Helper copy: ask the other KK10P tester to copy the reference shown on their Home account card.
- Local validation: required, canonical UUID after trim/lowercase normalization, non-zero, and not the current source account.
- Primary action: `Continue to amount`.

### Step 2 — Amount

- Show available source balance from the current `AccountSummary`; no source-account selector.
- One PHP amount field with a fixed `PHP` prefix, decimal keyboard, and at most two fractional digits.
- Convert user input to centavos with string arithmetic only; never parse through `double`/`num`.
- Client checks: at least PHP 0.01, at most PHP 50,000.00, and no more than the currently displayed balance. The server rechecks all rules under lock.
- Explain that the server enforces a PHP 100,000 total outgoing limit per Philippine calendar day.
- Primary action: `Review transfer`; secondary/back returns to Recipient with the draft preserved.

### Step 3 — Review and submit

- Raised summary card: source account reference, destination reference, exact PHP amount, available balance before submission, `No fee`, and `Completes immediately` only because those facts are in the internal contract.
- Confirmation text states the transfer moves fake money and cannot be reversed in this slice.
- Primary action: `Confirm transfer`; Back remains available only before the first submission starts.
- On tap, focus is cleared, a secure pending envelope is persisted, the button is disabled immediately, and one request is sent.

### Processing

- Use the existing button loading/pressed material and a concise live-region message such as `Confirming your transfer…`.
- Do not use an artificial delay, simulated progress percentage, success prediction, or cancel action.
- Block route/system Back while the request is in flight because cancellation cannot prove whether the server committed.

### Success receipt

- Display `Transfer complete`, amount, source reference, destination reference, source balance after, server transaction ID, server UTC timestamp, and `COMPLETED` status.
- If `replayed` is true, say `This earlier request was safely confirmed` rather than suggesting another debit.
- Primary action: `Done`, returning Home where the account provider has already been invalidated/refetched.
- Do not show recipient name, recipient balance, fee network, PDF/share, QR, or fabricated receipt metadata.

### Definitive failure

- Recipient not found and self-transfer return the customer to Recipient with an inline error.
- Insufficient funds returns to Amount and refreshes the account before allowing another review.
- Daily-limit reached shows the Philippine-day policy and disables blind resubmission of the same failed request.
- Rate limiting is a known-uncommitted, retryable rejection. Show the wait guidance, retain the same staged key/payload for a deliberate retry, allow safe cancellation, and never loop automatically.
- Account-not-opened returns/links to Home account recovery.
- Idempotency conflict is treated as a safety fault: no automatic new key, no silent resend, and a diagnostic reference when available.
- Definitive outcomes clear the stored envelope only after the state is safely reflected in the UI.

### Uncertain outcome and restart recovery

- Connection loss, timeout, cancellation after dispatch, `500`, `503`, or an invalid success receipt produce `Transfer status unconfirmed`—never `failed`.
- Show the stored recipient and amount read-only, explain that the money may already have moved, and offer one primary `Check transfer status` action.
- That action repeats the exact POST with the exact stored key and payload; a `200 replayed` receipt safely resolves a prior commit.
- The unresolved envelope survives leaving the screen, app process death, logout, and later login by the same customer.
- It is namespaced/bound to the authenticated customer ID. A different signed-in customer cannot see or reuse it.
- A customer with an unresolved envelope cannot start a second logical transfer until the first is confirmed or receives a definitive server response.
- There is no unsafe `Forget`, `Generate new key`, or `Try as a new transfer` shortcut.

## 5. State, Storage, and Logic Design

### Draft state

Editable, in-memory-only fields:

- normalized recipient account reference;
- raw/display PHP amount;
- current step;
- local field errors.

Ordinary draft input is not persisted and contains no recipient name or other personal data.

### Persisted pending envelope

Store only after confirmation is requested and before network dispatch:

```text
schemaVersion = 1
customerId
idempotencyKey
destinationAccountReference
amountMinor
createdAtUtc (local diagnostic timestamp only; never shown as server receipt time)
```

- Use `FlutterSecureStorage` through a feature-owned interface/provider so tests can substitute memory storage.
- Validate every restored field strictly. A corrupt pending marker blocks new transfers and requires diagnostic reconciliation; it is never silently cleared because the app cannot prove whether an earlier request committed.
- Use a versioned, customer-specific key; do not mix it with refresh-token or appearance keys.
- Never persist access/refresh tokens, source account IDs from input, receipt data, fake names, or free-form notes in this envelope.

### Controller states

```text
restoringPending
editing(recipient | amount | review)
persistingPending
submitting
uncertain(stored request, failure, requestId?)
retryableRejected(stored request, retryAfter?, requestId?)
definitiveFailure(target step, message, requestId?)
success(validated receipt)
storageFailure(blocked, safe retry)
```

The controller is session-generation-bound like Account and Development funding. Late results from a logged-out or replaced customer are ignored. Final `401` invalidates authentication and routes to sign-in without exposing transfer data to the next session.

### Core submit pseudocode

```text
WHEN customer confirms a valid review:
    IF already submitting OR an unresolved request exists: ignore tap
    BUILD canonical payload from validated recipient + BigInt centavos
    GENERATE secure UUID v4
    WRITE customer-bound pending envelope to secure storage
    IF storage write fails:
        DO NOT call the API
        show blocked storage failure
    ELSE:
        send exact payload + exact key

WHEN sending/reconciling:
    capture current authenticated session generation
    obtain valid access token
    POST once
    IF 401:
        refresh bearer once
        POST exact same payload + exact same key once
    reject stale-session result
    IF strict receipt is valid:
        clear pending envelope
        invalidate/refetch account state
        show success receipt
    ELSE IF response is the known-uncommitted 429 guard rejection:
        retain pending envelope for deliberate same-key retry or safe cancellation
    ELSE IF response is definitive:
        clear pending envelope
        route error to its correction step
    ELSE:
        keep pending envelope unchanged
        show status-unconfirmed recovery
```

### Money pseudocode

```text
NORMALIZE visible input without converting to floating point
VALIDATE digits, optional one decimal point, and zero-to-two fraction digits
SPLIT whole and fraction strings
RIGHT-PAD fraction to exactly two digits
amountMinor = BigInt.parse(whole) * 100 + BigInt.parse(fraction)
VALIDATE 1 <= amountMinor <= 5_000_000
SERIALIZE amountMinor.toString()
FORMAT receipt amounts by integer division/remainder and grouped whole digits
```

## 6. Planned File Changes

Exact private widget/file boundaries may be combined during implementation if that keeps files small without changing this behavior.

| Change | Path | Responsibility |
| --- | --- | --- |
| Add | `banking-lab/mobile/banking_mobile/lib/core/identifiers/secure_uuid_v4.dart` | One tested `Random.secure` UUID-v4 generator shared by transfer and Development funding. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/development_funding/presentation/controllers/development_funding_controller.dart` | Reuse the extracted generator with no funding behavior change. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/domain/internal_transfer_amount.dart` | Exact input validation, `BigInt` centavo parsing, and PHP formatting. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/data/models/internal_transfer_receipt.dart` | Strict `201`/`200` receipt parsing and validation. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/data/models/pending_internal_transfer.dart` | Versioned, strictly validated customer-bound retry envelope. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/data/storage/pending_internal_transfer_store.dart` | Secure read/write/delete boundary and provider. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/data/services/internal_transfer_api_service.dart` | Exact HTTPS/no-redirect POST, headers/body, status acceptance, stable code mapping, and safe request correlation extraction. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/data/repositories/internal_transfer_repository.dart` | Valid-token acquisition, one `401` refresh, same-key replay, and session-generation checks. |
| Modify | `banking-lab/mobile/banking_mobile/lib/core/errors/app_failure.dart` | Add transfer-specific safe failures and optional safe diagnostic metadata where minimally necessary. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/controllers/internal_transfer_controller.dart` | Draft/submit/recovery state machine, secure envelope lifecycle, duplicate suppression, session isolation, and account refresh. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/screens/internal_transfer_screen.dart` | Responsive Recipient/Amount/Review/Processing/Failure/Success journey. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/widgets/internal_transfer_step_indicator.dart` | Compact accessible three-step progress display. |
| Add | `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/widgets/internal_transfer_receipt_card.dart` | Server-only immediate receipt presentation. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart` | Working Transfer entry plus accessible copy-reference action in loaded state only. |
| Modify | `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Navigate from loaded Home account to `/transfer`. |
| Modify | `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Add `/transfer` and protect it under the same restored-session rules as `/home`. |
| Add/Modify | `banking-lab/mobile/banking_mobile/test/features/transfers/**` | Parser, receipt, service, repository, secure recovery, controller, UI, semantics, and responsiveness tests. |
| Modify | `banking-lab/mobile/banking_mobile/test/features/accounts/account_card_test.dart` | Loaded/unavailable Transfer and copy-reference behavior. |
| Modify | `banking-lab/mobile/banking_mobile/test/features/home/customer_home_screen_test.dart` | Replace the old “Transfer absent” assertion with working navigation expectations. |
| Modify | `banking-lab/mobile/banking_mobile/test/widget_test.dart` | Protected route, restored-session, and app-level journey regression coverage. |
| Add after delivery | `banking-lab/docs/03_Walkthroughs/walkthrough-kk10p-slice-6-flutter-internal-transfer-journey.md` | Outcome, concepts, flow, paths, exact PowerShell commands, results, recovery, and phone checklist. |

No backend source, migration, PostgreSQL row, Kotlin prototype file, dependency manifest, or global theme token is planned to change in Slice 6 implementation.

## 7. Implementation Sequence

1. **Baseline and contract fixtures**
   - Record current Flutter analysis/test results.
   - Build test-only receipt/Problem Details fixtures directly from the canonical backend contract.
   - Do not call shared transfer state.

2. **Exact primitives first**
   - Add secure UUID utility and preserve Development funding behavior.
   - Implement/test UUID normalization, PHP parsing/formatting, receipt validation, and pending-envelope validation.

3. **Safe local recovery boundary**
   - Add secure pending storage and in-memory test double.
   - Prove per-customer isolation, corrupt-record handling, write-before-send order, persistence across controller recreation, and delete-after-resolution behavior.

4. **API and authentication integration**
   - Add the fixed service and repository.
   - Prove exact JSON string amount, exact header, HTTPS/redirect rules, `201`/`200`, stable failures, same-key bearer refresh, and stale-session rejection.

5. **Transfer state machine**
   - Add editing, submission, definitive, uncertainty, recovery, success, and storage-failure states.
   - Prove rapid taps create one logical request and uncertainty reuses the stored envelope.

6. **Responsive pure-neumorphic UI**
   - Build the three steps and result states using `KkPageBody`, `KkSoftSurface`, `KkFieldSurface`, `KkEmbossedButton`, existing spacing/radius/tokens, and blue accents only.
   - Use raised surfaces for cards/actions and field/inset treatment only where the existing component system defines it.
   - Add no global material retuning.

7. **Home and protected navigation**
   - Add copy-reference and Transfer actions only for a loaded account.
   - Protect `/transfer`; clear/ignore stale UI state on logout or account switch.

8. **Automated quality gates**
   - Run focused transfer tests, complete Flutter tests, analysis, formatting, and diff checks.
   - Re-run the ordinary backend suite only as a regression gate before shared rollout; do not run the opt-in transfer database fixture against shared data.

9. **Separate Gate 6R — shared rollout (not authorized by this plan approval)**
   - Stop/quiesce the shared API.
   - Inspect current migration state and reconcile counts/sums.
   - Create and verify a fresh pre-rollout backup.
   - Ask for explicit approval to apply only `20260909065721_AddInternalTransfers` to shared `banking_lab`.
   - Apply, verify constraints/model/counts/sums, restart the API, then enable real-device submission testing.

10. **Chris/Gio real-device acceptance**
    - Use existing Development funding once if a source needs fake money; do not seed or edit balances directly.
    - Copy Gio's account reference, send a small exact test amount from Chris, verify both balance changes, then optionally test the reverse direction.
    - Exercise duplicate taps, timeout/network recovery where safely reproducible, light/dark mode, 320-width/200%-text automation, and TalkBack manually.
    - Deliver the concise walkthrough; leave Activity/history expectations for Slice 7.

## 8. Acceptance Criteria

### Functional

- [ ] Only an authenticated customer with a loaded open account can reach the Transfer journey.
- [ ] Home exposes a working `Transfer funds` action and an accessible `Copy account reference` action only in the loaded state.
- [ ] The journey contains Recipient, Amount, and Review steps plus honest processing/result states; it contains none of the excluded prototype features.
- [ ] Recipient input is normalized/validated as a canonical UUID and rejects blank, zero, malformed, and visible self-reference values before review.
- [ ] Amount input uses exact integer-string arithmetic, supports one/two decimal digits, and never uses floating point.
- [ ] Client validation enforces PHP 0.01–50,000.00 and currently visible balance; the text explains the server-authoritative PHP 100,000 Philippine-day limit.
- [ ] The service sends exactly two JSON fields and accepts only strict `201`/`200` receipts.
- [ ] Receipt content comes entirely from the server response and clearly says the money is simulated.

### Idempotency and recovery

- [ ] Ten rapid confirmation taps produce one request and one idempotency key.
- [ ] The pending envelope is durably stored before the first network dispatch; a storage failure sends nothing.
- [ ] Network, timeout, cancellation-after-dispatch, `500`, `503`, and invalid success data retain the exact key/payload and show `status unconfirmed`.
- [ ] Controller recreation/app restart for the same customer restores the unresolved request and reconciles it with the same POST.
- [ ] A different authenticated customer cannot see or submit another customer's stored pending request.
- [ ] A confirmed success or definitive business/input failure clears the pending envelope; `429` may retain it for a deliberate same-key retry or safe cancellation because the route guard did not execute the transfer.
- [ ] Failure to clear safely blocks a new logical transfer until cleanup succeeds; a corrupt pending marker is never silently discarded.
- [ ] `200 replayed` resolves as one confirmed earlier request, not a new transfer.

### Errors, auth, and privacy

- [ ] Unknown recipient, self-transfer, insufficient funds, daily limit, account-not-opened, idempotency conflict, rate limit, authentication loss, and uncertain server/network states are distinguishable.
- [ ] One bearer refresh may retry the identical request; a final `401` invalidates the customer session.
- [ ] Late responses cannot populate UI after logout/customer change.
- [ ] No recipient personal data, bearer/refresh token, idempotency key, body, amount, or full account references are newly logged.
- [ ] The UI never claims real banking rails, regulatory protection, encryption strength, fees, recipient identity, or settlement facts not in the contract.

### Design and accessibility

- [ ] Light/dark modes use the approved KK10P pure-neumorphic material without global theme changes or orange accents.
- [ ] Every screen has one visually primary action; fields, cards, selected steps, and pressed/loading states remain visually distinguishable.
- [ ] The journey is scroll-safe at 320 logical pixels and 200% text with no clipped amount, UUID, error, or action.
- [ ] TalkBack announces step, field purpose/error, current balance, submit warning, processing, unconfirmed status, and receipt in a coherent order.
- [ ] Touch targets are at least 48 logical pixels, keyboard focus advances logically, and the first invalid field receives focus.

### Rollout boundary

- [ ] Flutter unit/widget work performs no write to shared `banking_lab`.
- [ ] No real-device submit occurs before separate migration approval, fresh backup, exact migration application, and post-migration reconciliation.
- [ ] Chris/Gio phone verification confirms sender debit and recipient credit; Activity/history is not claimed until Slice 7.

## 9. Automated Verification Plan

From `banking-lab/mobile/banking_mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/transfers --reporter compact
flutter test --reporter compact
```

Planned focused coverage:

- PHP parser/formatter: `0.01`, `1`, `1.2`, `1.23`, `50,000.00`, blank, zero, negative, exponent, extra fraction, malformed grouping, over-limit, and very large text.
- Receipt parsing: valid create/replay, uppercase/invalid UUID, non-PHP currency, noncanonical/negative amount, invalid status/time/bool, and malformed map.
- Service contract: exact route/body/header/content type, HTTPS requirement, redirects disabled, `201`/`200`, every known error code, `429`, `500`/`503`, and request correlation.
- Repository: valid token, one refresh, same key/payload on refresh, final auth failure, and session-generation changes.
- Secure recovery: write-before-send, restoration, per-customer isolation, corrupt record, delete behavior, and storage faults.
- Controller: validation targets, rapid taps, success refresh, every definitive error, every uncertain error, same-key reconciliation, replay, logout, and late result suppression.
- Widgets/router: all steps, Back rules, loading lock, success/uncertainty/failure semantics, copy action, protected route, 320-width/200%-text in both themes, and no unsupported labels.

Before Gate 6R, from `banking-lab/backend`:

```powershell
Remove-Item Env:BANKING_TRANSFER_TEST_DATABASE -ErrorAction SilentlyContinue
dotnet test Banking.slnx -c Release --no-restore
```

This ordinary command must not opt into the disposable PostgreSQL transfer fixture and must not apply a migration.

## 10. Manual Phone Checklist After Gate 6R

1. Start Docker/PostgreSQL and the ASP.NET API using the exact commands delivered in the Slice 6 walkthrough.
2. Start Flutter with the approved private HTTPS API URL.
3. Verify Home shows Transfer only after the account loads and Copy announces/shows confirmation.
4. Exchange Chris/Gio references through a safe test channel; do not post them in logs or repository files.
5. Check blank/malformed/self recipient, PHP 0.00, PHP 0.01, PHP 50,000.00, PHP 50,000.01, and more than current balance.
6. Send a small amount, rapidly tap Confirm, and verify one receipt plus one sender debit/recipient credit.
7. Refresh both Home screens; verify exact balance conservation. Do not expect Activity until Slice 7.
8. Temporarily interrupt connectivity only at an agreed safe point, restore it, choose `Check transfer status`, and verify no duplicate debit.
9. Repeat visual/read-order checks in light/dark mode and TalkBack; capture any clipping, unclear press state, excessive depth, or ambiguous wording.

## 11. Risks, Recovery, and Rollback

| Risk | Mitigation / recovery |
| --- | --- |
| Duplicate movement after an uncertain response | Persist exact key/payload before dispatch and block new transfers until same-key reconciliation. |
| Secure storage cannot save/clear | Send nothing before a successful save; after success, retain a blocked recovery state until cleanup succeeds. |
| Stale response appears under another customer | Bind state/storage to customer ID and authentication session generation. |
| Client validation drifts from server | Contract fixtures and exact constants; server remains authoritative and maps stable codes. |
| Shared API receives transfer before schema readiness | Gate all live submission behind separately approved migration rollout and reconciliation. |
| Prototype introduces false capabilities | Maintain the explicit keep/strip matrix and assertion tests for unsupported labels. |
| Large text/keyboard makes flow unusable | Scroll-first layout, no fixed-height content cards, responsive widget tests, and device TalkBack review. |
| Slice 6 code must be reverted | Revert Flutter transfer files/router/Home integration; the backend and ledger remain unchanged. |
| Shared migration must be rolled back after a live transfer | Do not run Down. Restore/recover only through a separately approved data-recovery plan because narrowing the operation constraint after transfer rows exist is unsafe. |

## 12. Approval Boundary and Recommended Next Step

Approval of this plan authorizes only the planned Flutter source/tests/documentation work. It does **not** authorize:

- applying `20260909065721_AddInternalTransfers` to shared `banking_lab`;
- creating or deleting a database;
- adding/funding/transferring shared fake money;
- an authenticated live ZAP scan;
- Git staging, commit, push, branch switching, or pull-request actions.

After plan approval, implement through automated Flutter verification first. Before the first phone submission, stop at Gate 6R and request the separate shared-migration approval.

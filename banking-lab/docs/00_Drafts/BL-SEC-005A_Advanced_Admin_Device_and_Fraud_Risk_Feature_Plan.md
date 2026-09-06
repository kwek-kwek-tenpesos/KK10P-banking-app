# Banking Lab Advanced Admin Device and Fraud-Risk Feature Plan and Concept Notes

- **Document ID:** BL-SEC-005A
- **Status:** Controlled future-feature draft; AI guard is concept only, not planned
- **Parent guide:** BL-SEC-005 Authentication, Authorization and Application Security Standard
- **Audience:** Chris and future Banking Lab contributors
- **Project boundary:** Educational simulator using fake money and test data only

## 1. Purpose

This supplement records the approved future direction for:

- restricting each administrator to one active registered workstation;
- using a phone passkey or another standards-based authenticator to approve administrator login;
- recovering administrator access when a registered device is lost, stolen or replaced;
- giving a narrowly scoped security authority the ability to revoke devices and restrict accounts;
- holding or rejecting suspicious incoming transfers before funds become spendable.

These capabilities are **planned, not implemented**. They do not expand the current mobile/authentication foundation work. This supplement also records an optional Bluetooth device-approval learning demo; it is not an authentication mechanism.

**Scope clarification (4 September 2026):** Chris classified the AI guard as a concept, not a planned feature. Section 9 preserves that idea for discussion only. It has no scheduled phase, implementation task, delivery commitment or MVP acceptance requirement. Implementing it would require a new explicit approval; completing other security work does not automatically authorize it.

## 2. Architecture Decision

Banking Lab will use defense in depth rather than relying on one password, one token, one device check or one AI model.

The approved target is:

> An administrator may have one active registered workstation. Administrator login uses a standards-based phone passkey or equivalent phishing-resistant authenticator plus proof from a device-bound key. Device replacement revokes the old device and sessions through a controlled recovery workflow. A narrowly scoped security authority can revoke devices and restrict accounts but cannot rewrite ledger history. Suspicious transfers are rejected or placed in a non-spendable hold by deterministic backend policy.

### Why this design was chosen

- It reduces the usefulness of stolen passwords and copied bearer tokens.
- It gives the project an intentional stolen-device recovery path.
- It avoids one unrestricted super-administrator becoming a single catastrophic target.
- It protects both incoming and outgoing value instead of only blocking future receipts.
- It lets Banking Lab learn advanced security incrementally using explicit, testable backend controls.

### Alternatives not selected

- **Password and OTP only:** simpler, but manually entered OTP values are vulnerable to phishing and relay attacks.
- **A custom Bluetooth fingerprint protocol:** rejected because passkey/WebAuthn platform mechanisms already provide a reviewed cross-device design. Bluetooth may establish proximity but must not be the security protocol.
- **One permanent authenticator with no recovery method:** rejected because loss or damage could permanently lock out the administrator.
- **One all-powerful super-admin:** rejected because compromise would expose device recovery, roles and financial controls at once.
- **AI directly freezes accounts or edits balances:** rejected because model output can be wrong or manipulated and must not bypass deterministic backend authorization.

## 3. Trust Boundaries

| Component | Trusted responsibility | Must not be trusted to do alone |
| --- | --- | --- |
| Flutter/mobile or admin client | Present screens, collect input, request platform authentication and send API requests | Decide permissions, authorize itself, set account restrictions or change balances |
| Phone/platform authenticator | Protect and use the private authentication credential through platform APIs | Assign an application role or approve a backend business action by itself |
| ASP.NET Core backend | Authenticate, authorize, verify device proof, control recovery, evaluate policy and enforce state transitions | Delegate final permission decisions to the client or an AI model |
| PostgreSQL | Persist authoritative device, session, restriction, audit, transfer and ledger state | Accept client-authored authoritative balances or permissions |
| AI risk component (concept only; outside planned architecture) | If separately approved, explore advisory scores and reasons from approved minimal inputs | Receive credentials or directly mutate sessions, roles, restrictions, transfers or ledger entries |

## 4. Administrator Device-Binding Flow

```text
Admin attempts login on a desktop
    -> backend verifies the base account authentication
    -> phone performs a standard passkey/WebAuthn approval
    -> backend checks whether the workstation is the active registered device
        -> registered device: verify fresh device-key proof and create the session
        -> unregistered device: do not create a session; offer a replacement request
    -> every success, denial, registration and replacement is audited
```

The active workstation generates a cryptographic key through the operating system's protected key facility. Its private key must remain non-exportable where supported. The backend stores the public key and device-registration metadata, not the private key.

A future sender-constrained token design, such as DPoP or an equivalent reviewed mechanism, may bind session tokens to possession of the registered device key. DPoP is an additional token-theft defense; it does not replace account authentication, backend authorization, TLS, expiry, refresh rotation or revocation.

### One-device meaning

For this plan, **one device** means one active registered administrator workstation. It does not mean eliminating every recovery authenticator. A sealed recovery method or separately controlled backup authenticator remains necessary to avoid permanent lockout.

Whether ordinary customer accounts should also have a one-device restriction is intentionally undecided. The first approved scope is administrators only.

### Development and demonstration policy for rooted devices

The current physical Android test phone is rooted. Banking Lab must remain usable on that phone during local learning without creating a permanent user-specific or device-specific security backdoor.

The future integrity control will therefore support an explicit environment policy with three conceptual modes. The final configuration names will be chosen during implementation.

| Mode | Intended environment | Behavior |
| --- | --- | --- |
| Disabled | Automated tests or an isolated local scenario only | No external integrity request; tests inject controlled verdicts. |
| Report only | Local development and learning demonstrations | Detect or simulate the integrity result, display/record a safe risk result and allow the test flow to continue. |
| Enforce | Release-like administrator and sensitive-action testing | The backend applies the approved allow, step-up, restrict or reject policy. |

Rules for the exception:

- The exception applies to an explicitly configured non-production environment, not to Chris's identity, phone number, account name, IMEI or another hardcoded device identifier.
- Flutter does not decide that a failed integrity verdict may be bypassed. The backend owns the environment policy and resulting authorization decision.
- Report-only output must never contain integrity tokens, credentials or unique hardware identifiers.
- A development or test build must make its non-enforcing state visible so it cannot be mistaken for a secured release demonstration.
- Production-like configuration must not silently fall back to disabled or report-only mode.
- If a future test genuinely needs a device-specific exception, it must be a backend-owned, time-limited and audited test grant bound to a registered test device key, with a reason and expiry. It must not be compiled into the application.
- Root detection and Play Integrity remain risk signals. Passing a check is not proof that a device is free from compromise.

This allows the rooted learning phone to demonstrate a result such as `Device risk detected — allowed by development report-only policy` while preserving the intended release boundary.

## 5. Lost or Stolen Device Recovery

The recovery workflow is deliberately more difficult than normal login:

```text
Lost/stolen device reported
    -> immediately mark the device compromised
    -> revoke its active sessions and refresh-token family
    -> temporarily suspend sensitive administrator actions
    -> create an auditable replacement request
    -> verify recovery evidence through a separate trusted method
    -> require a different authorized approver when two-person control is available
    -> register the replacement workstation and authenticator
    -> notify the administrator and security authority
```

Recovery requirements:

- An administrator cannot approve their own device replacement.
- Possession of a password alone is insufficient for administrator recovery.
- Old device keys, sessions and refresh tokens remain revoked after replacement.
- Recovery codes or binding codes are single-use, short-lived and never logged in plaintext.
- Every action records actor, target, time, reason and result without recording credentials.
- Unexpected recovery activity produces an out-of-band notification.
- Emergency access is time-limited and reviewed after use.

### Session expiry is not device replacement

Token/session lifetime and registered-device lifetime solve different problems:

- A short-lived access token limits how long one captured API credential remains usable.
- An inactivity timeout ends a session that has not been used recently.
- An absolute timeout requires reauthentication even when the session remains active.
- Refresh-token rotation and reuse detection reduce the value of a copied refresh token.
- A registered device remains associated with the account until it is deliberately revoked, replaced or retired through policy.

Banking Lab must not automatically free the one-device slot merely because a refresh token or session has been inactive for several weeks. Doing so would turn waiting into a device-takeover strategy and could unexpectedly detach a legitimate phone. A long-dormant device may be marked for review, but a new device still requires an authenticated replacement or recovery decision.

Provisional learning values may be tested later, but are not final requirements:

| Context | Example starting policy |
| --- | --- |
| Customer access token | Approximately 10 minutes |
| Customer refresh token | 30-day inactivity limit and 90-day absolute limit |
| Administrator access token | Approximately 5 minutes |
| Administrator interactive session | Reauthenticate after approximately 15 minutes idle or 8 hours overall |
| Administrator refresh token | 7-day inactivity limit and 30-day absolute limit |

The backend must enforce the chosen times. Expiration clears or rejects session credentials; it does not erase device-registration or audit history. Final values require a separate security/usability review.

### Device-change and missing-device branches

```text
Old device is available
    -> authenticate with the current device and a fresh strong factor
    -> request replacement
    -> revoke the old device and its session family
    -> register and confirm the new device

Old device is missing, but a backup authenticator/recovery method is available
    -> complete verified account recovery
    -> revoke the old device and all related sessions
    -> apply a cooling-off period to configured sensitive actions
    -> register and notify the new device

No trusted recovery method is available
    -> open an expiring recovery case/ticket
    -> restrict sensitive actions while the case is verified
    -> require Security Authority review and a separate approver for an administrator
    -> revoke the old device only after sufficient verification or an authorized emergency decision
    -> register the replacement and notify all configured channels
```

An unverified person must not be able to revoke somebody else's device merely by filing a ticket. Pending recovery tickets expire if unfinished, but ticket expiry never grants access or automatically removes the registered device.

## 6. Privileged Roles and Separation of Duties

The final role names will be approved with the backend authorization model. The planned responsibilities are:

| Planned responsibility | May perform | Must not perform |
| --- | --- | --- |
| Administrator | Approved daily administration | Approve own recovery or alter audit history |
| Security Authority | Suspend an admin, revoke devices/sessions, initiate an account restriction and review incidents | Edit balances, delete posted transactions or approve its own highest-risk request |
| Security Approver | Provide the second decision for critical recovery, release or reversal operations | Initiate and approve the same protected action |
| Break-glass operator | Perform a narrowly defined, time-limited emergency recovery | Act as an everyday administrator |

If the learning environment temporarily has only one operator, that limitation must be documented and the workflow simulated in tests. It must not be presented as equivalent to real two-person control.

## 7. Account Restrictions and Suspicious Incoming Money

Stopping only new incoming transfers is insufficient because already-received funds might still be sent out. The backend therefore needs independent restriction capabilities:

- `InboundRestricted`: reject or hold new incoming transfers according to policy.
- `OutboundRestricted`: reject new withdrawals and outgoing transfers.
- `FullyFrozen`: reject both incoming and outgoing financial actions.
- `UnderReview`: permit only explicitly safe actions while the incident is reviewed.

These names describe the proposed behavior, not final database enum or class names.

### Proposed transfer decision flow

```text
Incoming transfer request
    -> authenticate and authorize the caller
    -> validate amount, source, destination and idempotency key
    -> check account restrictions
    -> evaluate deterministic velocity and fraud-risk rules
    -> backend policy chooses one controlled outcome
        -> low risk: post and make available
        -> medium/uncertain risk: place in non-spendable hold and queue review
        -> high or known-bad risk: reject and optionally apply a temporary restriction
    -> atomically persist transfer, ledger, hold and audit results
```

Required financial-integrity behavior:

- Restrictions are enforced by the backend, not by hiding buttons in Flutter.
- The restriction is checked again in the authoritative transaction immediately before posting.
- Held funds do not increase the available balance.
- A timeout or retry cannot create a duplicate transfer.
- Posted ledger entries are never edited or deleted.
- Correcting a posted transfer uses a separately authorized compensating reversal linked to the original transaction.
- Holds and temporary restrictions have an owner, reason, creation time, review status and expiry/review policy.
- A safe manual review and appeal path exists because automated risk signals can be false positives.

## 8. Deterministic Transaction-Risk Rules

The initial risk engine will use explicit, testable rules. Possible future signals include:

- recent device, authenticator, password or recovery changes;
- unusual transfer amount or frequency compared with the account's fake test history;
- many unrelated senders or recipients within a short interval;
- repeated failed authorization or device-proof attempts;
- a restricted source or destination; and
- repeated dispute or reversal patterns in simulator data.

A signal is evidence for review, not proof of fraud. Thresholds and actions must be versioned, tested and auditable.

## 9. AI Guard Concept — Not a Planned Feature

**Status:** Concept only. There is no approved AI implementation, delivery date, selected model, external service or dependency on this concept for completing the app. The earlier ADVSEC-006 task designation is withdrawn, not completed or scheduled.

The idea covers possible AI-assisted abuse detection or transaction-risk advice, including exploring malicious automated activity. It does not promise that AI can reliably identify or stop other AI-driven attacks. Deterministic security controls must stand on their own.

If Chris explicitly approves a separate exploration later, the following are discussion ideas, not an implementation sequence committed by this plan:

1. Collect fake, minimal and labeled simulator events.
2. Run the AI model in **shadow mode**, where it scores events but cannot affect an account or transfer.
3. Compare recommendations with expected outcomes and measure false positives and false negatives.
4. Evaluate whether an advisory score is useful; any move from observation to influencing temporary holds requires separate security and product approval.
5. Keep permanent restrictions, device recovery and reversals under explicit authorization and human review.

Any separately approved prototype would have to:

- receive only the minimal approved data needed for scoring;
- never receive passwords, OTP codes, refresh tokens, private keys or full authorization headers;
- use a service identity with no direct ledger, role, session or account-state write permission;
- return a score, reason codes and model/rule version for auditability;
- fail through a documented deterministic fallback when unavailable; and
- remain replaceable without changing ledger or authorization invariants.

## 10. Placement in the Existing Roadmap

This feature plan is deliberately split so advanced work does not interrupt the current mobile foundation.

| Order | Existing or future milestone | Why it comes here |
| --- | --- | --- |
| Complete | MOB-005 secure session store | Establishes the minimal mobile refresh-token boundary. |
| Partial | MOB-006 local-session repository foundation | Checks token presence and clears local storage; it does not yet authenticate a user. |
| Required before completing MOB-006 | Relevant API/SEC backend identity, token, authorization, rate-limit and TLS foundations | Defines and verifies the login/refresh/logout contract before Flutter consumes it. Detailed implementation choices still require approval. |
| Resume mobile integration | Remaining MOB-006 auth repository and MOB-007 route guards | Connects verified backend authentication to Flutter session state and protected navigation. |
| Domain/data | DATA-003 through DATA-008 and DOM-002 through DOM-012 as applicable | Establishes authoritative ledger, accounts, transfer state, atomic posting, concurrency, idempotency, audit and admin policies. |
| Optional pre-admin learning demo | Bluetooth Device Approval Simulator below | Rehearses cross-device approval UX with real Bluetooth and fake requests; it is not a prerequisite for or substitute for real passkeys. |
| Advanced admin | ADVSEC-001 through ADVSEC-003 below | Adds trusted devices, passkey/device proof and controlled recovery before real privileged administration is considered ready. |
| Fraud controls | ADVSEC-004 and ADVSEC-005 below | Adds restrictions, holds and deterministic risk policy after ledger invariants exist. |

### Optional learning demo: Bluetooth Device Approval Simulator

**Status:** Approved for future planning, not implemented. Revisit when preparing the desktop/phone administrator approval experience, before or alongside the UX planning for ADVSEC-002. It does not interrupt or count toward MOB-006 completion.

**Purpose:** Learn Bluetooth communication and approval-state handling using one Windows PC and one Android phone. The Bluetooth transport is real; authentication and the destination dashboard are simulated. Call it a device-approval simulator, not a working passkey authenticator.

Proposed demonstration flow:

```text
PC starts a fake approval request
    -> send request identifier, demo action and expiry over Bluetooth
    -> phone displays the request while the demo app is open
    -> user approves or rejects
    -> PC accepts only a matching, pending, unexpired response
    -> display a simulated success, rejection or timeout result
```

Boundaries:

- Use a separate demo target/project with a persistent simulation label. Its final structure and dependencies require review before implementation.
- Do not send banking credentials, session tokens, real customer data or raw biometrics over the demo connection.
- Do not connect the approval result to Banking API authentication, administrator permissions, device registration, account recovery or money-changing endpoints.
- A demo approval can open only a fake dashboard. It must never set the real application's authenticated state.
- Request IDs, expiry and duplicate handling are behavior checks, not proof of identity or phishing resistance. Bluetooth pairing or proximity alone is not passkey authentication.
- Keep both apps in the foreground initially. Background services, notification delivery, internet relays, custom cryptography and real passkey integration are outside this demo's initial scope.
- Verify Windows adapter/driver support, Android BLE capabilities and runtime permissions before choosing libraries. Root detection is not part of this isolated demo; the rooted learning phone still needs physical compatibility testing.
- The no-proprietary-authentication rule remains unchanged. This simulator does not authorize creating a custom Bluetooth authentication protocol for the banking application.

Hands-on checkpoints:

1. Confirm hardware and permission support, then send a harmless PC-to-phone message and receive an acknowledgement.
2. Add the fake request display and explicit Approve/Reject controls.
3. Test rejection, timeout, Bluetooth disabled, permission denial, disconnect, duplicate responses and responses for the wrong request. None may produce a simulated approval.
4. Record physical-device verification and demonstrate that no banking session or privileged endpoint can be reached through the simulator.

When real administrator passkeys are implemented, use platform WebAuthn/FIDO mechanisms and backend verification. UI lessons may be reused, but the simulator's approval messages must not become authentication proofs.

### Future atomic task register

#### ADVSEC-001 — Administrator trusted-device registry

- Define device and authenticator lifecycle states.
- Register one active workstation per administrator through an authenticated backend flow.
- Store public keys and safe lifecycle metadata only.
- Reject session issuance from an unregistered workstation.

**Pass condition:** A copied password or token cannot authorize an admin request without valid proof from the active registered device.

#### ADVSEC-002 — Standards-based passkey and device proof

- Use platform WebAuthn/FIDO mechanisms for phone approval.
- Use fresh server challenges and verify proofs on the backend.
- Evaluate hardware-backed key attestation and sender-constrained tokens during the security design review.
- Evaluate Google Play Integrity as a server-verified Android risk signal, subject to separate approval for the external service and dependencies.
- Implement disabled, report-only and enforce environment policies without hardcoded personal/device bypasses.
- Bind an integrity verdict to the protected request and keep the enforcement decision on the backend.
- Do not build a proprietary Bluetooth or fingerprint protocol.

**Pass condition:** Replay, invalid-origin, invalid-signature and revoked-device attempts fail securely and are audited. A rooted development phone can complete an explicitly marked report-only demonstration, while release-like enforcement cannot inherit that bypass.

#### ADVSEC-003 — Security authority and device recovery

- Define narrowly scoped security permissions.
- Implement device-loss reporting, session revocation and replacement approval.
- Add two-person approval for the highest-risk actions when the operating model supports it.
- Add notifications, reason capture and immutable audit events.

**Pass condition:** A stolen device can be revoked promptly, the old credentials cannot be reused, and no actor can initiate and approve their own protected recovery.

#### ADVSEC-004 — Account restrictions and held balance

- Define restriction and hold lifecycle rules before creating schema changes.
- Enforce restriction checks in backend transaction processing.
- Keep held value separate from available value.
- Use append-only reversals for corrections after posting.

**Pass condition:** A restricted recipient cannot obtain spendable value, concurrent requests cannot bypass the restriction, and ledger history remains reconstructable.

#### ADVSEC-005 — Deterministic transaction-risk policy

- Add versioned, explainable rules and velocity controls.
- Map low, uncertain and high risk to post, hold/review and reject/restrict outcomes.
- Add expiry, review, release, rejection and appeal behavior.
- Test false-positive and service-failure paths.

**Pass condition:** Every decision has deterministic inputs, reason codes, an allowed state transition and an audit record.

## 11. Deferred Decisions Requiring Approval

The following are intentionally not decided by this draft:

- the final administrator portal platform and workstation key API;
- the identity provider and exact passkey/WebAuthn server library;
- whether hardware attestation is mandatory or only an additional risk signal;
- whether Google Play Integrity or another platform integrity provider will be used and which verdicts will be enforced;
- final role and permission names;
- the recovery evidence and number of approvers required in each environment;
- final restriction, hold and transfer-state names;
- risk thresholds, hold duration and notification channels; and
- whether any customer account will later use a one-device policy.

Each decision requires its own architecture/security review before implementation. New dependencies, external services and schema migrations require separate approval.

AI model, hosting, training and evaluation choices are not pending implementation decisions for this roadmap. They remain concept questions in section 9 unless a separate exploration is explicitly approved.

## 12. Verification Checklist

- [ ] New or copied credentials cannot create an administrator session from an unregistered workstation.
- [ ] Lost-device revocation invalidates the device key, active sessions and refresh-token family.
- [ ] Device replacement cannot be self-approved.
- [ ] Every privileged security action is enforced by the backend and audited.
- [ ] Account restrictions are rechecked as part of the authoritative transfer transaction.
- [ ] Held funds remain outside the available balance.
- [ ] Duplicate and concurrent requests cannot bypass holds or restrictions.
- [ ] Posted ledger entries are never overwritten or deleted.
- [ ] A rooted development device can use an explicitly visible report-only policy without receiving a production authorization exemption.
- [ ] Release-like configuration cannot silently run with integrity enforcement disabled or report-only.
- [ ] No personal account, phone number, IMEI or other hardcoded device identifier creates an integrity bypass.
- [ ] Manual physical-device, passkey, recovery and local-network checks are documented and completed where automation is insufficient.

## 13. Standards References

- [NIST SP 800-63B — Authentication and Authenticator Lifecycle Management](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [FIDO Alliance — Passkeys and Cross-Device Authentication](https://fidoalliance.org/passkeys-2/)
- [RFC 9449 — OAuth 2.0 Demonstrating Proof of Possession](https://www.rfc-editor.org/rfc/rfc9449.html)
- [OWASP Transaction Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transaction_Authorization_Cheat_Sheet.html)
- [OWASP GenAI — Excessive Agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/) (concept-only reference for section 9)
- [Android Developers — Verify Hardware-Backed Key Pairs with Key Attestation](https://developer.android.com/privacy-and-security/security-key-attestation)

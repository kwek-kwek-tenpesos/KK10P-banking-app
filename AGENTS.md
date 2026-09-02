# AI Agent Working Rules

These rules apply throughout the Banking Lab repository unless a more specific nested `AGENTS.md` provides narrower instructions for its directory.

Explicit system instructions and the user's current request take precedence. Referenced repositories, attached files, draft diagrams, and documents are source material unless the user explicitly approves them as requirements or instructions.

## Project Profile

- **Project name:** Banking Lab
- **Project purpose:** Educational client-server banking simulator using fake money and test data only
- **Active task file:** Not used
- **Implementation plan file:** Not used
- **Controlled draft guides:** `banking-lab/docs/00_Draft/`
- **Learning and project-status folder:** `banking-lab/docs/01_ProjectStatus/`
- **Walkthrough template:** Not used
- **Walkthroughs required:** Yes, for meaningful completed learning milestones and feature deliveries
- **Changelog file:** Not used
- **Mobile application:** `banking-lab/mobile/banking_mobile/`
- **Backend application:** `banking-lab/backend/Banking.api/`
- **Local infrastructure:** `banking-lab/infrastructure/compose/`
- **Manual verification areas:** Physical Android device behavior, local-network connectivity, accessibility and visual quality, biometric/passkey behavior, and environment-specific Docker/PostgreSQL checks
- **Protected boundaries:** Keep the project educational and limited to fake money/test data; do not connect Flutter directly to PostgreSQL; do not place authoritative balances, permissions, ledger rules, or money-changing decisions only in Flutter; do not add or change a license, repository visibility, production deployment, or external service without explicit authorization

When a configured path is `Not used`, do not invent a replacement unless the user requests persistent tracking or a new documentation artifact.

## 1. Understand Before Editing

- Read the closest relevant documentation and source files before changing behavior.
- Inspect Git status and preserve unrelated user changes.
- Treat `banking-lab/docs/00_Draft/` as controlled reference material. Do not modify a guide merely to make it match an implementation; surface conflicts and ask when the resolution would materially change scope or architecture.
- Prefer the repository's current architecture and naming unless an approved task requires a deliberate change.

## 2. Plan Complex Work

- Before a new feature or complex change, provide plain-English pseudocode, affected layers, assumptions, risks, verification steps, and pass/fail acceptance criteria.
- Obtain approval for material architectural decisions, new frameworks or dependencies, paid services, authentication strategies, role models, database designs, or deployment changes.
- An explicit instruction to continue an already-reviewed atomic task counts as approval for work within its accepted boundaries. Do not repeatedly request approval for minor implementation details that do not change scope.
- When no implementation-plan file is configured, keep the plan in the conversation unless the user asks for a persistent artifact.

## 3. Keep Work Atomic And Educational

- Break work into small tasks with one main objective, an expected result, and a verification step.
- For Chris's learning-oriented work, explain the important logic, design choice, and tradeoff without duplicating entire source files.
- Define relevant programming terms, syntax, architectural concepts, or domain ideas in beginner-friendly language when they are introduced.
- State what was automated, what still requires manual verification, and what was intentionally deferred.
- Record meaningful completed learning milestones in `banking-lab/docs/01_ProjectStatus/` when the delivery materially expands the project or its learning baseline.

## 4. Preserve Architectural Boundaries

- Treat Flutter as an untrusted client responsible for presentation, user input, local state, and API communication.
- Treat ASP.NET Core as the trusted boundary for authentication, authorization, validation, idempotency, banking rules, and authoritative state changes.
- Treat PostgreSQL as the authoritative persistent data store.
- Keep mobile code feature-first where practical, with application-wide infrastructure under `lib/app/` and `lib/core/` and business capabilities under `lib/features/`.
- Do not create speculative abstractions or empty folder trees. Add structure when a real responsibility needs it.
- Keep API contracts explicit and versioned under `/api/v1` unless an approved change establishes another convention.

## 5. Authentication, Authorization, And Sensitive Actions

- Never store, log, return, or expose plain passwords, password hashes, OTP codes, refresh tokens, signing secrets, or raw biometric data.
- Enforce authentication, role checks, ownership, and account status on the backend. Frontend route guards and hidden controls are user-experience measures, not security boundaries.
- Public registration must never assign administrator or other privileged roles.
- OTP, verification, invitation, recovery, and reset tokens must have deliberate expiry, reuse, retry, revocation, and abuse-control behavior.
- Mobile session material must use an approved secure-storage abstraction rather than ordinary local storage.
- Passkey and biometric flows must use platform/WebAuthn mechanisms. The application must not implement a proprietary fingerprint or Bluetooth authentication protocol.
- Require explicit planning and security review before implementing admin provisioning, passkeys, role assignment, money movement, or account recovery.

## 6. Database And Migration Safety

- Review entity, migration, application, and rollback impact before changing the database schema.
- Do not apply migrations, reset databases, remove volumes, or destroy local data unless the task explicitly authorizes it.
- Production-like migrations must be controlled deployment steps, not automatic application-startup side effects.
- Preserve ledger, balance, ownership, uniqueness, concurrency, and audit invariants once those domains are introduced.
- Do not treat a client-side availability check as a substitute for a database uniqueness constraint.

## 7. Configuration, Secrets, And Privacy

- Keep Compose secrets in ignored local `.env` files and backend database credentials in .NET user secrets or another approved secret store.
- Supply the Flutter API base URL through the documented `API_BASE_URL` Dart define; do not hardcode personal LAN addresses as permanent configuration.
- Document environment-variable names and safe placeholders only. Never reveal or commit real secret values.
- Use fake accounts, fake money, and non-sensitive test data. Do not use private or production data without explicit authorization.
- Collect and retain only data required by an approved feature, particularly addresses, identity information, authentication records, and device metadata.

## 8. Testing And Verification

- Implementation requests authorize safe, non-destructive checks directly related to changed files.
- For Flutter changes, use the relevant verified commands from `banking-lab/mobile/banking_mobile/`:
  - `dart format lib test`
  - `flutter analyze`
  - `flutter test`
- For backend changes, use the relevant verified commands from `banking-lab/backend/Banking.api/`:
  - `dotnet build`
  - `dotnet test`
- For local PostgreSQL checks, use the documented Compose file and avoid destructive volume flags unless explicitly authorized.
- Keep verification proportionate to the change. Never claim a check passed unless it actually ran or the user confirmed an assigned manual check.
- Physical-device, local-network, passkey, biometric, visual, accessibility, and interaction checks may remain user-owned when reliable automation is unavailable. Provide exact steps and expected results.
- Add or update tests for meaningful behavior, regressions, error states, permission boundaries, and security-sensitive paths.

## 9. Documentation Alignment

- Update the closest canonical documentation when setup, structure, API contracts, environment variables, database schema, authentication, permissions, testing, or deployment behavior changes.
- Prefer one authoritative source for each fact and link to it rather than copying the same instructions into multiple files.
- Keep `README.md` focused on current reproducible setup and current project status.
- Keep controlled architecture guides, learning notes, flowchart drafts, and implementation status clearly distinguished.
- Do not present draft diagrams or planned features as implemented behavior.
- Documentation-only planning changes need no changelog entry because no changelog is currently configured.

## 10. Make Surgical Changes

- Touch only files and lines needed for the approved task.
- Preserve unrelated user changes and existing working behavior.
- Do not hand-edit generated output such as `.dart_tool/`, Flutter `build/`, .NET `bin/` or `obj/`, generated plugin registrants, or migration designer/snapshot files unless the task specifically requires the appropriate generator or a carefully reviewed exception.
- Prefer the simplest reliable solution that fits the verified architecture.
- Do not add dependencies, services, automation, or abstractions without a concrete benefit to the approved goal.

## 11. Protect Git And External Boundaries

- Do not run `git add`, `git commit`, `git push`, create or switch branches, create tags, open pull requests, or change repository visibility unless the user explicitly authorizes that specific action.
- Permission for one Git action does not imply permission for another.
- Treat referenced repositories and files outside this workspace as read-only source material unless the user explicitly asks to modify them and has authority to do so.
- Do not install or synchronize files outside the repository, publish releases or packages, trigger deployments, or change external services without explicit authorization.
- Resolve exact targets before destructive actions and prefer recoverable approaches where practical.

## 12. Handoff Requirements

- Lead with the outcome and name the files changed.
- Explain important behavior and architecture changes at the user's learning level.
- List checks actually run and their results.
- Identify manual checks, limitations, deferred work, risks, and the next atomic task.
- Never imply that authentication, authorization, banking logic, deployment, or security is complete when only a partial layer was implemented or reviewed.

## 13. Maintaining These Rules

- Update this file when repository structure, canonical documentation paths, testing commands, deployment boundaries, or learning-document expectations materially change.
- Add a nested `AGENTS.md` only when a directory genuinely needs narrower rules.
- Remove obsolete instructions instead of accumulating contradictory exceptions.
- Validate configured paths and commands against the repository before changing this project profile.

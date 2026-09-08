
# Banking Lab

Banking Lab is an educational client-server banking simulator built to learn mobile development, backend APIs, databases, testing, security, and deployment concepts. Its delivery target is a genuinely functional, no-paid-service prototype suitable for a public GitHub showcase: identities and money remain fake, but the approved customer flows must work end to end rather than being decorative mock screens.

The customer-facing app is named **KK10P Bank**. Banking Lab remains the internal project name; package identifiers and repository paths are unchanged. See the [approved app identity and visual direction](banking-lab/docs/01_Tracking/BL-LEARN-001_Development_Fundamentals_and_Current_Setup.md#approved-app-identity-and-visual-direction) for the planned interface style.

> Banking Lab uses fake money and test data only. It is not intended for real deposits, payment cards, regulated transactions, or production banking credentials.

The repository is intended as a public showcase. No license is added by this implementation work; publishing, visibility and licensing changes remain explicit owner decisions.

## Current Milestone

The `BL-SETUP-001` foundation and authentication repair batches A/B/C are delivered. Customer sessions enforce 15-day inactivity and 90-day absolute expiry. The [end-to-end customer authentication delivery](banking-lab/docs/03_Walkthroughs/walkthrough-end-to-end-customer-authentication.md) now adds genuine SMTP confirmation, mobile login/session restoration/logout and protected routing. Verification on 2026-09-05 passed 176 database-free backend tests, all six guarded PostgreSQL tests, 73 Flutter tests, clean Flutter analysis, a local registration-to-logout Mailpit journey and the complete physical-phone journey over Tailscale Serve HTTPS. No ZAP scan ran.

Authentication progress: registration, verification/resend, login, refresh/logout and protected `/api/v1/auth/me` endpoints are implemented. Flutter has registration, confirmation, login, secure refresh-token storage, restore/retry, logout, diagnostics and protected Home. The shared session migration is current, a private JWT key and local Mailpit settings are stored in .NET user-secrets, and the [current authentication contract](banking-lab/docs/04_Architecture/customer-authentication-contract.md) is the source of truth. Mailpit is local development infrastructure, not a production email provider.

The [accounts/balances implementation](banking-lab/docs/03_Walkthroughs/walkthrough-accounts-and-balances.md) adds owner-only GET/idempotent PUT `/api/v1/accounts/me`, explicit opening at PHP 0.00, a persisted zero-only account model and Home account states with session-safe retries. On 2026-09-06, 196 database-free backend tests and 101 Flutter tests passed with clean analysis; the four account PostgreSQL tests then passed against a fresh disposable target. After a verified custom-format backup, only the additive account migration was applied successfully to shared `banking_lab`. Chris's physical customer-A path and Gio's remote customer-B ownership-isolation path passed; TalkBack listening remains pending. Use the [accounts contract](banking-lab/docs/04_Architecture/customer-accounts-contract.md) for current behavior.

The customer screens now use the approved accessible blue-accent neumorphic KK10P foundation. Slice 2 adds a truthful first-install Welcome/reusable About screen, persistent Light/Dark/System appearance, coordinated preference/session startup and recomposed Login, Registration, Verification and Diagnostics. Versioned local experience flags contain no identity or credentials and never authorize protected routes. The Flutter preview gallery was removed in favor of normal physical-device hot reload. On 2026-09-08, analysis passed and all 149 serialized Flutter tests passed, including responsive 320/360/412/768-width and 200% text coverage; Chris then accepted every physical Light/Dark Slice 2 checklist item. Home/account TalkBack listening remains pending. The canonical [KK10P mobile design direction](banking-lab/docs/05_Design/kk10p-mobile-ui-design-system.md), [Slice 2 plan](banking-lab/docs/02_Planning/plan-kk10p-slice-2-first-install-auth-surfaces.md) and [Slice 2 walkthrough](banking-lab/docs/03_Walkthroughs/walkthrough-kk10p-slice-2-first-install-auth-surfaces.md) describe the current boundary. Original flowcharts and Word files in `docs/00_Drafts/` are reference ideas, not current behavior contracts.

[Batch C and follow-up review](banking-lab/docs/03_Walkthroughs/walkthrough-authentication-repair-batch-c.md) corrected an expiry-during-persistence exception and hardened the scanner wrapper. `pwsh -NoProfile -File banking-lab/scripts/run-zap-scan.ps1` is now a no-network/no-write preview; `pwsh -NoProfile -File banking-lab/scripts/test-zap-scan.ps1` runs offline guard checks. Actual scanning/downloads need separate approval. Initial scan coverage is diagnostic GET only, not authentication. Generated SDK and raw ZAP folders are ignored but not deleted.

Existing implementation and historical verification:

- PostgreSQL 17 configured and previously verified locally through Docker Compose; it may remain stopped for database-free work
- ASP.NET Core API running on .NET 10
- Entity Framework Core with the Npgsql PostgreSQL provider
- Initial `SetupProbe` database migration
- `GET /api/v1/system/info` endpoint
- Flutter Android application running on a physical device
- Environment-aware Flutter API base URL
- Dio HTTP client configuration
- Shared typed failures for network, timeout, server, malformed-response, cancellation, and unexpected errors
- Central Dio-to-`AppFailure` error mapping
- Explicit validation of the `SystemInfo` API response
- User-safe typed error messages with retry behavior
- Typed `SystemInfo` Dart model
- API service and repository layers
- Riverpod providers and dependency overrides
- Loading, success, failure, and retry UI states
- Flutter unit and widget tests
- First live Flutter-to-ASP.NET request
- Backend Identity service registration with the existing EF user store (foundation only)
- Backend tests for system info, EF model mapping and Identity service/password wiring
- Customer email/display-name validation and Identity model/migration-shape tests; migration application is recorded in the prior delivery walkthrough, not newly verified here
- NFC password preparation, 15-128 Unicode-code-point validation, an initial exact-match offline blocklist and ASP.NET Identity hashing tests
- Registration, verification/resend, login, refresh, logout and protected-profile endpoint tests
- Provider-neutral SMTP delivery with an optional loopback-only Mailpit Compose profile
- Mobile authentication state, secure refresh-token persistence and `go_router` protected navigation

Not implemented yet:

- Verified HTTPS Android App Links for a future public release; the current custom scheme is prototype-only
- Authentication recovery, verified App Links and operational security controls
- Funding/nonzero balances; account code is implemented but migration rollout and real-database/device verification remain pending
- Transfers and ledger rules
- Transaction history
- Production deployment
- Production HTTPS and security hardening
- CI/CD pipeline

## Project Architecture

```text
Android phone
Flutter mobile application
        |
        | HTTPS requests and JSON responses through Tailscale Serve (phone auth)
        v
ASP.NET Core backend API
        |
        | Entity Framework Core and Npgsql
        v
PostgreSQL 17 database
```

The Flutter application is treated as an untrusted client. It must not connect directly to PostgreSQL or make authoritative balance changes.

Future banking operations must pass through ASP.NET Core, where authentication, authorization, validation, transactions, idempotency, audit logging, and ledger rules can be enforced.

## Current End-to-End Flow

```text
Register -> SMTP verification -> confirm deep link -> Login
    -> ASP.NET Core Identity and persisted session family
    -> access token in memory + rotating refresh token in secure storage
    -> protected GET /api/v1/auth/me
    -> authenticated Home
    -> Logout revokes family and clears local credentials

Diagnostics -> Dio GET /api/v1/system/info -> typed success/failure UI
```

Identity and diagnostic values displayed by Flutter come from backend responses and are not hardcoded in the screens.

## Technology Stack


| Area                   | Technology              | Current purpose                           |
| ------------------------ | ------------------------- | ------------------------------------------- |
| Mobile language        | Dart                    | Flutter application code                  |
| Mobile framework       | Flutter                 | Android UI and client behavior            |
| State and dependencies | Riverpod                | State management and dependency injection |
| HTTP client            | Dio                     | Requests from Flutter to ASP.NET Core     |
| Backend language       | C#                      | Backend application code                  |
| Backend framework      | ASP.NET Core on .NET 10 | HTTP API                                  |
| ORM                    | Entity Framework Core   | C# entity and database mapping            |
| PostgreSQL provider    | Npgsql                  | EF Core communication with PostgreSQL     |
| Database               | PostgreSQL 17           | Local relational data storage             |
| Local infrastructure   | Docker Compose          | PostgreSQL and optional Mailpit containers |
| Mobile testing         | Flutter Test            | Unit and widget tests                     |
| Version control        | Git                     | Source and documentation history          |

`go_router` and secure storage are now active parts of authentication. Freezed and generated JSON serialization remain available for later features but are not required by the current hand-written bounded contracts.

## Repository Structure

```text
banking-lab/
  backend/
    Banking.slnx
    Banking.api/             ASP.NET Core API and EF migrations
    tests/Banking.IntegrationTests/  Backend API integration tests

  mobile/
    banking_mobile/          Flutter mobile application and tests
      lib/app/               Startup wiring and application shell
      lib/core/api/          Shared API client configuration
      lib/features/          Feature-first mobile capabilities

  infrastructure/
    compose/                 Local PostgreSQL Compose configuration
    temporary/               Temporary setup AppDbContext and entity

  docs/
    00_Drafts/               Draft/reference material; ignored by default
    01_Tracking/             Active task, historical learning notes and task archives
    02_Planning/             Feature and repair plans
    03_Walkthroughs/          Delivery explanations and verification records
    04_Architecture/          Architecture documents
    05_Design/                Design specifications
    06_Guides/                Setup and contributor guides
    07_Archive/               Superseded documentation

  scripts/                   Reserved for future helper scripts
```

## Prerequisites

Install:

- Git
- .NET 10 SDK
- Docker Desktop with Docker Compose
- Flutter stable SDK
- Android Studio or the required Android SDK tools
- A physical Android device or Android emulator

Visual Studio with the C++ workload is only required for Flutter Windows desktop development. It is not required when targeting Android.

Verify the tools:

```powershell
git --version
dotnet --info
docker --version
docker compose version
flutter --version
flutter doctor
flutter devices
```

A physical Android device should appear in `flutter devices` before running the mobile application.

## 1. Local PostgreSQL Setup

From the repository root, create:

```text
banking-lab/infrastructure/compose/.env
```

Add a local development password:

```dotenv
POSTGRES_PASSWORD=YOUR_LOCAL_DEVELOPMENT_PASSWORD
```

Use a development-only password. Never commit the real `.env` file.

Start PostgreSQL:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml up -d
```

Check its health:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml ps
```

Expected database configuration:


| Setting  | Value                               |
| ---------- | ------------------------------------- |
| Host     | `localhost`                         |
| Port     | `5432`                              |
| Database | `banking_lab`                       |
| Username | `banking_app`                       |
| Password | Value stored in the untracked`.env` |

The PostgreSQL container should report `healthy`.

Stop PostgreSQL without deleting its data:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml down
```

Do not add `-v` unless you intentionally want to delete the local PostgreSQL volume and all local database data.

## 2. Backend Database Secret

Open the backend project directory:

```powershell
cd banking-lab/backend/Banking.api
```

The committed project already contains a `UserSecretsId`. Each developer must store their own connection string outside Git.

Read the same PostgreSQL password without displaying it:

```powershell
$secureBankPassword = Read-Host "Enter the local PostgreSQL password" -AsSecureString
```

Temporarily convert it so it can be passed to the .NET command:

```powershell
$bankPassword = [System.Net.NetworkCredential]::new("", $secureBankPassword).Password
```

Store the connection string:

```powershell
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=banking_lab;Username=banking_app;Password=$bankPassword"
```

Remove the temporary PowerShell variables:

```powershell
Remove-Variable bankPassword
Remove-Variable secureBankPassword
```

The password in the user-secret connection string must match the password used to initialize the Docker PostgreSQL user.

## 3. Restore and Build the Backend

From `banking-lab/backend/Banking.api`, run:

```powershell
dotnet restore
dotnet build
```

Verify the Entity Framework command is available:

```powershell
dotnet ef --version
```

If it is not installed, install the .NET 10-compatible tool:

```powershell
dotnet tool install --global dotnet-ef --version "10.*"
```

## 4. Initial Database Setup and Migration Safety

The shared `banking_lab` database was backed up and verified before applying the exact `20260904152654_AddCustomerSessions` migration on 2026-09-05. Its history, nullable compatibility link, session table, indexes and restrictive foreign keys were verified afterward. Do not run an unqualified `dotnet ef database update`; inspect history, review every pending migration and approve the exact target first.

For an explicitly authorized initial setup of a new database only, make sure PostgreSQL is healthy, then target the initial migration:

```powershell
dotnet ef migrations list
dotnet ef database update InitialSetupProbe
```

The initial migration is:

```text
20260825144009_InitialSetupProbe
```

It creates:

- `SetupProbes`
- `__EFMigrationsHistory`

`SetupProbes` is temporary and exists only to verify the EF Core and PostgreSQL setup.

Skip this setup step if the database is already initialized. Do not target `InitialSetupProbe` on a database with newer migrations: that would roll them back and could delete authentication data. See the [slice 2A migration review](banking-lab/docs/01_Tracking/BL-LEARN-001_Development_Fundamentals_and_Current_Setup.md#slice-2a-customer-identity-data-and-unapplied-migration) for the isolated-database test and approval gates before applying the new migration.

## 5. Run the Backend API

### Required authentication configuration

The API refuses startup without a valid private `Jwt:SigningKey` (or `Jwt__SigningKey` environment variable), even for System Info. Generate a random secret outside source control; never restore the removed fallback. The current machine has a generated key in .NET user-secrets, but every new developer must create their own:

```powershell
$jwtSigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
dotnet user-secrets set "Jwt:SigningKey" $jwtSigningKey
Remove-Variable jwtSigningKey
```

For the free local verification mailbox, configure the non-secret Mailpit values once from `banking-lab/backend/Banking.api`:

```powershell
dotnet user-secrets set "Smtp:Enabled" "true"
dotnet user-secrets set "Smtp:Host" "127.0.0.1"
dotnet user-secrets set "Smtp:Port" "1025"
dotnet user-secrets set "Smtp:Security" "None"
dotnet user-secrets set "Smtp:FromAddress" "no-reply@kk10pbank.local"
dotnet user-secrets set "Smtp:FromName" "KK10P Bank"
dotnet user-secrets set "Smtp:ConfirmationLinkBase" "kk10pbank://auth/verify-email"
```

Start its optional Compose profile only while testing email:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email up -d postgres mailpit
```

Mailpit listens only on `127.0.0.1:1025` (SMTP) and `127.0.0.1:8025` (web/API). Open [http://localhost:8025](http://localhost:8025) on the development PC to read captured simulator emails; nothing is delivered to Gmail or another public mailbox. A link using the `kk10pbank://` scheme must be opened on the Android device (or safely relayed to it), because clicking it in the PC browser does not transfer the link to the phone. Plain SMTP is allowed only to loopback; a future external provider must use TLS. If Mailpit is stopped, registration/resend delivery cannot complete. Mailpit data is disposable and may disappear when its container is recreated.

### PC-only access

To serve the API only through the development machine’s localhost address:

```powershell
dotnet run --launch-profile http
```

The local endpoint is:

```text
http://localhost:5255/api/v1/system/info
```

### Loopback upstream for physical-phone access

The committed Kestrel endpoint `TailscaleServeUpstream` intentionally listens only on `http://127.0.0.1:5255`. The phone must not connect to that HTTP upstream directly. Tailscale Serve supplies the private HTTPS front door described below; `--urls` does not replace the committed Kestrel endpoint.

Test the endpoint from the PC:

```powershell
Invoke-RestMethod http://localhost:5255/api/v1/system/info
```

Expected response:

```json
{
  "name": "Banking API",
  "version": "v1.0.0",
  "environment": "Development"
}
```

### Tailscale HTTPS development access

Credential-bearing phone traffic must use a trusted HTTPS endpoint. After the host and phone are connected to the same authorized tailnet, keep the API upstream on loopback and let Tailscale Serve terminate HTTPS:

```powershell
tailscale serve --bg --https=443 http://127.0.0.1:5255
tailscale serve status
```

Use the exact `https://HOSTNAME.TAILNET.ts.net` URL printed by Tailscale as Flutter's `API_BASE_URL`. Do not commit a personal tailnet hostname and do not substitute a Tailscale IP over HTTP. The API trusts forwarded scheme information only from an exact loopback proxy with a one-hop limit.

Tailscale provides private network connectivity between approved devices. It does not replace application authentication, backend authorization, production HTTPS, or other security controls.

Chris and Gio's approved simulation uses separate fake customer accounts against one shared backend hosted by either person. Hosting the API does **not** grant an application administrator role; admin provisioning remains later work. The machine operator is trusted with development data, so use test identities only. Display names may be shown and need not be unique. Registration and mobile sessions, including the physical-phone Tailscale Serve HTTPS path, are verified. The HTTP example above is diagnostic-only.

The `Development` value comes from `ASPNETCORE_ENVIRONMENT` in `Properties/launchSettings.json`.

Stop the backend with `Ctrl+C`.

## 6. Find the PC’s Local Network Address

For physical-phone testing, run:

```powershell
ipconfig
```

Find the active Wi-Fi or Ethernet adapter’s IPv4 address. It normally resembles:

```text
192.168.x.x
```

The phone and PC must be connected to the same local network.

Do not commit a personal LAN address as the permanent API URL.

## 7. Restore and Verify Flutter

Open a separate PowerShell terminal:

```powershell
cd banking-lab/mobile/banking_mobile
```

Restore Flutter packages:

```powershell
flutter pub get
```

Run static analysis and tests:

```powershell
flutter analyze
flutter test
```

The current tests cover:

- API base URL and Dio configuration
- Typed `SystemInfo` JSON conversion
- API service success and invalid responses
- Repository/provider behavior
- Application success rendering
- Loading UI
- Failure UI
- Retry behavior
- Typed API error mapping
- Preservation of server status codes
- Malformed `SystemInfo` response handling
- User-safe typed error messages

## 8. Run Flutter on Android

Confirm the device is detected:

```powershell
flutter devices
```

### Physical Android phone

For registration, login and sessions, replace the placeholder with the exact HTTPS MagicDNS URL printed by Tailscale Serve:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

Plain LAN HTTP remains usable only for the unauthenticated diagnostics exercise; the mobile auth service rejects it before sending credentials:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5255
```

Do not include Markdown brackets, parentheses, or a missing colon in the URL.

### Android emulator

The standard Android emulator reaches the host PC using `10.0.2.2`, but this plain-HTTP example is diagnostics-only unless a trusted HTTPS proxy is placed in front:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5255
```

### Why the Dart define is required

Flutter reads `API_BASE_URL` using:

```dart
String.fromEnvironment('API_BASE_URL')
```

If the value is missing or is not a complete URL, application startup intentionally fails with a configuration error.

The API URL is supplied at build/run time instead of being hardcoded throughout Flutter widgets.

## 9. Expected Mobile Result

After session restoration, a signed-out phone displays the KK10P Bank login screen. Successful confirmed login displays the protected home greeting using the backend display name. **API diagnostics** remains available and shows live values resembling:

```text
Banking API
Version: v1.0.0
Environment: Development
```

If the backend is stopped or unreachable, Flutter displays a controlled error state and a **Try again** button.

Restarting the backend and tapping **Try again** should restore the success screen.

## Development Ports and Configuration


| Value                                 | Used by                     | Purpose                                    |
| --------------------------------------- | ----------------------------- | -------------------------------------------- |
| `5432`                                | PostgreSQL                  | Local database port                        |
| `5255`                                | ASP.NET Core                | Local HTTP API port                        |
| `1025`                                | Mailpit                     | Loopback-only development SMTP             |
| `8025`                                | Mailpit                     | Loopback-only mailbox web/API              |
| `POSTGRES_PASSWORD`                   | Docker Compose              | Initializes the local PostgreSQL user      |
| `ConnectionStrings:DefaultConnection` | ASP.NET Core user secrets   | Backend database connection                |
| `API_BASE_URL`                        | Flutter`--dart-define`      | Base address of the ASP.NET API            |
| `ASPNETCORE_ENVIRONMENT`              | ASP.NET Core launch profile | Selects`Development` configuration locally |

No real passwords or credentials should appear in committed configuration or documentation.

## Available API Endpoints

Current authentication routes are `POST /api/v1/auth/register`, `/api/v1/auth/verify-email`, `/api/v1/auth/resend-verification`, `/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/auth/logout`, and protected `GET /api/v1/auth/me`. Credential operations require HTTPS and responses use no-store. Registration returns generic `202` after creating/sending or for an existing identity; verification consumes a one-hour token with `204`; resend returns generic `202`; login/refresh return credentials; logout revokes the session family; `/me` exposes only ID and nullable display name. Guards can return `400`, `413`, `429` with `Retry-After`, or `503` for recognized dependency failures. See the [canonical authentication contract](banking-lab/docs/04_Architecture/customer-authentication-contract.md).

### System Information

```http
GET /api/v1/system/info
```

Authentication: Not required.

Request body: None.

Successful response:

```json
{
  "name": "Banking API",
  "version": "v1.0.0",
  "environment": "Development"
}
```

The endpoint currently confirms frontend-to-backend connectivity. It does not query PostgreSQL.

## Useful Development Commands

### Docker

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml up -d
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml ps
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml down
```

### Backend

From `banking-lab/backend/Banking.api`:

```powershell
dotnet restore
dotnet build
dotnet ef migrations list
dotnet run --launch-profile http
```

For the solution build and backend integration test, run from `banking-lab/backend`:

```powershell
dotnet build .\Banking.slnx
dotnet test .\tests\Banking.IntegrationTests\Banking.IntegrationTests.csproj
```

The xUnit suite covers System Info, Identity/model/password behavior, verification delivery, trusted proxy handling, registration, tokens, session deadlines, JWT/session authorization, refresh and logout. On 2026-09-05, 176 database-free cases passed and six opt-in PostgreSQL cases passed separately against only `banking_lab_auth_repair_test`. The latter verify migration upgrade, concurrent refresh/logout, rollback, refresh budgeting and database-failure handling. Without `BANKING_AUTH_TEST_DATABASE` those six explicitly skip and PostgreSQL can remain stopped. Local Mailpit proved adapter wiring, and the complete physical-phone HTTPS journey was also verified manually.

### Flutter

From `banking-lab/mobile/banking_mobile`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

While `flutter run` is active:


| Key | Action                                |
| ----- | --------------------------------------- |
| `r` | Hot reload                            |
| `R` | Hot restart                           |
| `q` | Stop Flutter and return to PowerShell |
| `d` | Detach while leaving the app running  |

Long-running ASP.NET Core and Flutter processes should use separate terminal tabs.

## Troubleshooting

### PostgreSQL reports password authentication failure

Possible causes:

- The Docker `.env` password and .NET user-secret password differ.
- PostgreSQL was initialized earlier using another password.
- Another PostgreSQL installation is already using port `5432`.

Checks:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml ps
docker ps
```

Changing `.env` does not automatically change the password inside an existing PostgreSQL volume.

Deleting the Compose volume with `down -v` destroys the local database. Only do that deliberately when the local data is disposable.

### Phone cannot connect to ASP.NET Core

Confirm:

- Backend is running and responds locally on port `5255`.
- Phone and PC are connected to the authorized Tailscale tailnet.
- `tailscale serve status` shows the loopback API proxy on HTTPS port `443`.
- Flutter uses the exact HTTPS MagicDNS URL printed by Serve, not `localhost`, a raw IP or plain HTTP.
- The HTTPS diagnostics endpoint opens in the phone’s browser without a certificate bypass.

### Flutter reports that `API_BASE_URL` is missing

Start Flutter with:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

### Flutter or Gradle runs out of memory

The Android Gradle configuration is limited to a smaller heap and two workers for the current 16 GB development machine.

Close unused memory-heavy applications and avoid running an Android emulator when a physical phone is available.

### Port `5432` is already in use

A native PostgreSQL installation or another container may already own the port. Stop the conflicting service or intentionally change the Compose host-port mapping and matching backend connection string.

## Security Rules

- Never commit `.env` files, database passwords, connection strings, access tokens, or private keys.
- Keep local database credentials in `.env` and .NET user secrets.
- Use only fake money and test data.
- Treat Flutter as an untrusted client.
- Never place authoritative banking rules only in Flutter.
- Never connect the mobile application directly to PostgreSQL.
- Do not log passwords or future authentication tokens.
- Local HTTP is acceptable only for controlled early development.
- Production-like deployment must use deliberate HTTPS and security configuration.

Before committing, verify that the local `.env` is ignored:

```powershell
git check-ignore banking-lab/infrastructure/compose/.env
```

If ignored correctly, Git prints the file path.

## Documentation

Draft/reference engineering guides (not automatically approved requirements):

```text
banking-lab/docs/00_Drafts/
```

Recommended order:

1. `BL-MASTER-000` — master architecture and engineering roadmap
2. `BL-SETUP-001` — development environment and repository setup
3. `BL-MOB-002` — Flutter architecture and UI engineering
4. `BL-API-003` — ASP.NET Core backend architecture and API design
5. `BL-DATA-004` — PostgreSQL and ledger architecture
6. `BL-SEC-005` — authentication, authorization, and security
7. `BL-DOM-006` — banking features and domain rules
8. `BL-QA-007` — testing, QA, and performance
9. `BL-OPS-008` — infrastructure and deployment
10. `BL-CICD-009` — CI/CD and operational readiness

Beginner learning notes:

```text
banking-lab/docs/01_Tracking/BL-LEARN-001_Development_Fundamentals_and_Current_Setup.md
```

## Known Limitations

The project currently has:

- Customer authentication is verified end to end locally and on the physical Android phone; production email and verified App Links remain future work
- The custom `kk10pbank` URI scheme must become a verified HTTPS App Link before public authentication use
- Owner-only account endpoints and a zero-balance PHP account model are implemented; account migration rollout is pending
- No funding, nonzero balances, transfers, transaction history or ledger
- Four guarded account PostgreSQL tests are authored but not executed; six existing session PostgreSQL tests were skipped in this database-free delivery
- Backend validation and ProblemDetails exist, but error handling and security controls still need the documented repairs
- No production database environment
- No production HTTPS configuration
- No CI/CD pipeline
- No monitoring, backups, or incident procedures
- No production security review
- No app-store release configuration

These capabilities will be added incrementally through the controlled project guides.

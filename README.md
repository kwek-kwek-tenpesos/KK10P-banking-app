
# Banking Lab

Banking Lab is an educational client-server banking simulator built to learn mobile development, backend APIs, databases, testing, security, and deployment concepts.

> Banking Lab uses fake money and test data only. It is not intended for real deposits, payment cards, regulated transactions, or production banking credentials.

## Current Milestone

The project is completing `BL-SETUP-001`, the development-environment and repository-setup milestone.

Implemented and verified:

- PostgreSQL 17 running locally through Docker Compose
- ASP.NET Core API running on .NET 10
- Entity Framework Core with the Npgsql PostgreSQL provider
- Initial `SetupProbe` database migration
- `GET /api/v1/system/info` endpoint
- Flutter Android application running on a physical device
- Environment-aware Flutter API base URL
- Dio HTTP client configuration
- Typed `SystemInfo` Dart model
- API service and repository layers
- Riverpod providers and dependency overrides
- Loading, success, failure, and retry UI states
- Flutter unit and widget tests
- First live Flutter-to-ASP.NET request

Not implemented yet:

- Registration and login
- Authentication or authorization
- Accounts and balances
- Transfers and ledger rules
- Transaction history
- Production deployment
- Production HTTPS and security hardening
- CI/CD pipeline
- Dedicated backend automated test project

## Project Architecture

```text
Android phone
Flutter mobile application
        |
        | HTTP requests and JSON responses
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
SystemInfoScreen
    -> Riverpod FutureProvider
    -> SystemInfoRepository
    -> SystemInfoApiService
    -> Dio GET /api/v1/system/info
    -> ASP.NET Core endpoint
    -> JSON response
    -> typed SystemInfo model
    -> loading, success, or failure UI
```

The values displayed by Flutter come from the backend response and are not hardcoded in the screen.

## Technology Stack

| Area                   | Technology              | Current purpose                           |
| ---------------------- | ----------------------- | ----------------------------------------- |
| Mobile language        | Dart                    | Flutter application code                  |
| Mobile framework       | Flutter                 | Android UI and client behavior            |
| State and dependencies | Riverpod                | State management and dependency injection |
| HTTP client            | Dio                     | Requests from Flutter to ASP.NET Core     |
| Backend language       | C#                      | Backend application code                  |
| Backend framework      | ASP.NET Core on .NET 10 | HTTP API                                  |
| ORM                    | Entity Framework Core   | C# entity and database mapping            |
| PostgreSQL provider    | Npgsql                  | EF Core communication with PostgreSQL     |
| Database               | PostgreSQL 17           | Local relational data storage             |
| Local infrastructure   | Docker Compose          | PostgreSQL container and volume           |
| Mobile testing         | Flutter Test            | Unit and widget tests                     |
| Version control        | Git                     | Source and documentation history          |

Some installed Flutter packages, including `go_router`, Freezed, JSON serialization, and secure storage, are intended for later architecture tasks and are not fully used yet.

## Repository Structure

```text
banking-lab/
  backend/
    Banking.slnx
    Banking.api/             ASP.NET Core API and EF migrations

  mobile/
    banking_mobile/          Flutter mobile application and tests

  infrastructure/
    compose/                 Local PostgreSQL Compose configuration
    temporary/               Temporary setup AppDbContext and entity

  docs/
    00_Draft/                Controlled architecture and engineering guides
    01_ProjectStatus/        Current learning and progress documentation

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

| Setting  | Value                                 |
| -------- | ------------------------------------- |
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

## 4. Apply the Database Migration

Make sure PostgreSQL is healthy, then run:

```powershell
dotnet ef migrations list
dotnet ef database update
```

The initial migration is:

```text
20260825144009_InitialSetupProbe
```

It creates:

- `SetupProbes`
- `__EFMigrationsHistory`

`SetupProbes` is temporary and exists only to verify the EF Core and PostgreSQL setup.

## 5. Run the Backend API

### PC-only access

To serve the API only through the development machine’s localhost address:

```powershell
dotnet run --launch-profile http
```

The local endpoint is:

```text
http://localhost:5255/api/v1/system/info
```

### Physical-phone access

For a phone on the same trusted private network, allow ASP.NET Core to listen through the PC’s network interfaces:

```powershell
dotnet run --urls "http://0.0.0.0:5255"
```

`0.0.0.0` is a server-listening address. Do not use `0.0.0.0` as the URL on the phone.

This is a local-development HTTP configuration. It is not a production deployment configuration.

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

## 8. Run Flutter on Android

Confirm the device is detected:

```powershell
flutter devices
```

### Physical Android phone

Replace `YOUR_PC_IPV4` with the PC’s active private IPv4 address:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IPV4:5255
```

Example shape only:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5255
```

Do not include Markdown brackets, parentheses, or a missing colon in the URL.

### Android emulator

The standard Android emulator reaches the host PC using `10.0.2.2`:

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

While ASP.NET Core is running and reachable, the phone should display live values resembling:

```text
Banking API
Version: v1.0.0
Environment: Development
```

If the backend is stopped or unreachable, Flutter displays a controlled error state and a **Try again** button.

Restarting the backend and tapping **Try again** should restore the success screen.

## Development Ports and Configuration

| Value                                   | Used by                     | Purpose                                      |
| --------------------------------------- | --------------------------- | -------------------------------------------- |
| `5432`                                | PostgreSQL                  | Local database port                          |
| `5255`                                | ASP.NET Core                | Local HTTP API port                          |
| `POSTGRES_PASSWORD`                   | Docker Compose              | Initializes the local PostgreSQL user        |
| `ConnectionStrings:DefaultConnection` | ASP.NET Core user secrets   | Backend database connection                  |
| `API_BASE_URL`                        | Flutter`--dart-define`    | Base address of the ASP.NET API              |
| `ASPNETCORE_ENVIRONMENT`              | ASP.NET Core launch profile | Selects`Development` configuration locally |

No real passwords or credentials should appear in committed configuration or documentation.

## Available API Endpoints

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
dotnet test
dotnet ef migrations list
dotnet ef database update
dotnet run --launch-profile http
```

There is currently no dedicated backend test project. `dotnet test` is retained as a setup and future test-suite verification command.

### Flutter

From `banking-lab/mobile/banking_mobile`:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://YOUR_API_HOST:5255
```

While `flutter run` is active:

| Key   | Action                                |
| ----- | ------------------------------------- |
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

- Backend was started with `http://0.0.0.0:5255`.
- Phone and PC use the same trusted private network.
- Flutter uses the PC’s IPv4 address, not `localhost`.
- Windows Firewall allows the development process on the private network.
- The endpoint opens in the phone’s browser.

### Flutter reports that `API_BASE_URL` is missing

Start Flutter with:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_API_HOST:5255
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

Controlled engineering guides:

```text
banking-lab/docs/00_Draft/
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
banking-lab/docs/01_ProjectStatus/BL-LEARN-001_Development_Fundamentals_and_Current_Setup.md
```

## Known Limitations

The project currently has:

- No user registration or login
- No authentication tokens or route protection
- No account ownership or permission system
- No balances, transfers, transaction history, or ledger
- No dedicated backend test project
- No backend validation or standardized API error model
- No production database environment
- No production HTTPS configuration
- No CI/CD pipeline
- No monitoring, backups, or incident procedures
- No production security review
- No app-store release configuration

These capabilities will be added incrementally through the controlled project guides.

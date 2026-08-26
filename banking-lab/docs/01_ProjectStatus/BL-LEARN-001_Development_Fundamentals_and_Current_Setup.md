# Banking Lab Development Fundamentals and Current Setup

- **Document ID:** BL-LEARN-001
- **Audience:** Beginner developer / project owner
- **Purpose:** A reusable explanation of the tools, architecture, and verified setup completed during BL-SETUP-001
- **Last verified:** 26 August 2026
- **Scope:** Educational banking simulator using fake money and test data only

> This document explains the current development foundation. It is not a production deployment guide, a security certification, or authorization to operate a real financial service.

## 1. What Banking Lab Is Becoming

Banking Lab is planned as a client-server application with three primary layers:

```text
Android phone
Flutter mobile application
        |
        | HTTP requests and JSON responses
        v
ASP.NET Core backend API
        |
        | Entity Framework Core / SQL
        v
PostgreSQL database
```

The mobile application displays information and collects user actions. The backend is the trusted system that will eventually validate permissions and banking rules. PostgreSQL stores permanent structured data.

The mobile application must not directly change balances or connect directly to PostgreSQL. Sensitive operations must be accepted, validated, authorized, and recorded by the backend.

## 2. Languages, Frameworks, and Tools

| Name                  | Category                     | Current purpose                                    |
| --------------------- | ---------------------------- | -------------------------------------------------- |
| Dart                  | Programming language         | Mobile application source code                     |
| Flutter               | UI framework and SDK         | Builds the Dart application for Android            |
| C#                    | Programming language         | Backend source code                                |
| .NET                  | Runtime and SDK              | Compiles and runs C#                               |
| ASP.NET Core          | Web/API framework            | Receives HTTP requests and returns responses       |
| SQL                   | Database language            | Queries and modifies relational data               |
| PostgreSQL            | Database management system   | Stores permanent application data                  |
| Entity Framework Core | Object-relational mapper     | Maps C# entities to PostgreSQL tables              |
| Npgsql                | PostgreSQL provider for .NET | Lets EF Core communicate with PostgreSQL           |
| Docker                | Container platform           | Runs the local PostgreSQL environment              |
| Git                   | Version-control system       | Records source and documentation history           |
| JSON                  | Data format                  | Carries structured data between mobile and backend |
| HTTP                  | Network protocol             | Defines requests and responses between systems     |

### Important terminology

- Dart and C# are **languages**.
- Flutter and ASP.NET Core are **frameworks**.
- An SDK is a set of tools used to build software for a platform.
- A runtime provides the environment in which compiled software executes.
- A dependency or package is reusable code added to a project.

## 3. What Runs on Each Machine

### On the Android phone

The installed application contains the compiled Dart code, Flutter framework functionality, the Flutter rendering engine, package code, and a small Android host layer.

In debug mode, Flutter supports hot reload through the Dart development runtime. In a release build, Dart is compiled ahead of time for the phone's processor.

ASP.NET Core and PostgreSQL do not run inside the phone in the current architecture.

### On the development computer

The computer currently runs:

- The ASP.NET Core backend process.
- PostgreSQL 17 inside Docker.
- Flutter and Android build tools.
- ADB for communication with the physical Android phone.
- Git and the project files.

During local development, the computer temporarily acts as the backend server. In a future deployment, ASP.NET Core and PostgreSQL would move to controlled server infrastructure.

## 4. How Dart Communicates with C#

Dart does not call C# functions directly. The Flutter application and ASP.NET Core backend communicate using HTTP and JSON, which are language-independent standards.

The current contract is:

```http
GET /api/v1/system/info
```

The backend returns HTTP status `200 OK` and JSON shaped like:

```json
{
  "name": "Banking API",
  "version": "v1.0.0",
  "environment": "Development"
}
```

The current Flutter flow is:

```text
Flutter screen
    -> Riverpod provider / ViewModel
    -> repository
    -> Dio API service
    -> HTTP GET request
    -> ASP.NET Core endpoint
    -> JSON response
    -> typed Dart SystemInfo model
    -> loading, success, or failure UI
```

The two applications only need to agree on the API contract:

- HTTP method
- URL path
- required headers
- request body or parameters
- response status code
- JSON field names and data types
- error behavior

The backend could be written in another server language and the Flutter app could remain unchanged if the HTTP contract stayed compatible.

## 5. Why Flutter Must Not Connect Directly to PostgreSQL

Database credentials placed in a mobile application can be extracted from the installed APK. A malicious user could bypass the UI and issue database commands directly.

The required trust boundary is:

```text
Untrusted client (Flutter) -> Trusted backend (ASP.NET Core) -> PostgreSQL
```

The backend will eventually be responsible for checks such as:

- Is the user authenticated?
- Does the user own the account?
- Is the requested operation allowed?
- Is the amount valid?
- Is the balance sufficient?
- Is this a duplicate request?
- Should the operation be audited?

Hiding a button in Flutter is not security. Important rules must be enforced by the backend.

## 6. Repository and Git Fundamentals

The main project layout is:

```text
banking-lab/
  backend/          ASP.NET Core API and migrations
  mobile/           Flutter mobile application
  infrastructure/   Docker Compose and temporary EF setup
  docs/             Controlled guides and project notes
  scripts/          Future helper scripts
```

Git records file history as commits. Common `git status` indicators are:

| Indicator | Meaning                               |
| --------- | ------------------------------------- |
| `M`     | Modified tracked file                 |
| `A`     | Added/staged file                     |
| `D`     | Deleted tracked file                  |
| `??`    | Untracked file                        |
| `AM`    | Added to staging, then modified again |

The root `.gitignore` excludes local secrets and generated files, including:

- `.env` files except a safe `.env.example`
- .NET `bin/` and `obj/`
- Flutter `.dart_tool/` and build output
- IDE-specific settings
- test output
- local database files and dumps

`.gitignore` is not encryption and does not erase an already committed secret. It prevents matching untracked files from being added in normal Git operations.

## 7. Docker and PostgreSQL Fundamentals

The local database is described by `infrastructure/compose/compose.dev.yml`.

### Docker concepts

- **Image:** reusable template, currently `postgres:17`.
- **Container:** running PostgreSQL instance created from the image.
- **Volume:** persistent storage for PostgreSQL data.
- **Compose file:** configuration recipe for services, ports, environment, storage, and health checks.

The port mapping is:

```text
Windows localhost:5432 -> PostgreSQL container:5432
```

The named volume is `banking_pgdata`. A normal Compose shutdown preserves it. Running Compose down with `-v` intentionally deletes the volume and local database data.

The health check uses `pg_isready` to confirm that PostgreSQL is accepting connections for the configured development database and user.

### Verified database identifiers

- Database: `banking_lab`
- Development role: `banking_app`
- Port: `5432`

No real password is included in this document.

### Port-conflict lesson

A native Windows PostgreSQL service previously occupied port `5432`. The backend reached that server instead of the Docker container and reported password authentication failures. Stopping the conflicting service allowed Docker to own the intended host port.

This demonstrated that only one process can normally listen on the same IP-address-and-port combination.

## 8. Secrets and Configuration

Docker Compose reads the development PostgreSQL password from an untracked `.env` file.

The ASP.NET Core connection string is stored with .NET user secrets. The project file contains a `UserSecretsId`, but the actual connection string is stored outside the repository in the Windows user profile.

A connection string identifies how the backend reaches PostgreSQL:

```text
Host=localhost;
Port=5432;
Database=banking_lab;
Username=banking_app;
Password=<local-development-password>;
```

Documentation and committed configuration must use placeholders rather than real credentials.

## 9. ASP.NET Core Fundamentals

The backend entry point is `backend/Banking.api/Program.cs`.

Its current responsibilities are:

1. Create the application builder.
2. Register `AppDbContext` through dependency injection.
3. Build the web application.
4. Map `GET /api/v1/system/info`.
5. Start listening for requests.

The development backend has been run on port `5255`.

This command listens through every suitable network interface during local testing:

```powershell
dotnet run --urls "http://0.0.0.0:5255"
```

This HTTP configuration is for controlled local development. Production traffic must use an appropriate HTTPS deployment configuration.

## 10. Entity Framework Core and Migrations

Entity Framework Core is an object-relational mapper:

```text
C# entities <-> EF Core/Npgsql <-> PostgreSQL tables
```

The temporary `AppDbContext` exposes:

```csharp
DbSet<SetupProbe> SetupProbes
```

The `SetupProbe` entity contains:

- `Id`: integer primary key
- `Status`: required text
- `CheckedAt`: timestamp with time zone

The applied `InitialSetupProbe` migration created the `SetupProbes` table. EF Core also tracks applied migrations in `__EFMigrationsHistory`.

Applying the migration proved that the backend could authenticate, connect, and execute schema commands. The migration creates the table; it does not automatically guarantee that a `SetupProbe` row exists.

A migration contains:

- `Up()`: changes used when applying the migration.
- `Down()`: reversal instructions used when rolling it back deliberately.

## 11. Flutter and Android Fundamentals

The Flutter entry point is `mobile/banking_mobile/lib/main.dart`.

Application startup currently performs these steps:

1. Read `API_BASE_URL` from `--dart-define`.
2. Validate that it is a complete URL.
3. Create Riverpod's root `ProviderScope`.
4. Override `appConfigProvider` with the validated configuration.
5. Mount `BankingLabApp`.
6. Display `SystemInfoScreen`.

`BankingLabApp` is a `StatelessWidget` responsible for application-level configuration such as the Material theme and starting screen.

`SystemInfoScreen` is a `ConsumerWidget`. A `ConsumerWidget` can use a `WidgetRef` to watch Riverpod providers.

The screen runs:

```dart
final systemInfoAsync = ref.watch(systemInfoProvider);
```

The provider returns an `AsyncValue<SystemInfo>`. This represents three possible states:

```text
Loading -> request has not completed
Data    -> request completed successfully
Error   -> request failed
```

The screen uses `systemInfoAsync.when()` to select the appropriate UI:

- Loading displays a progress indicator.
- Success displays API name, version, and environment.
- Failure displays a safe error message.
- **Try again** invalidates the provider and starts another request.

### Widget concept

Flutter describes interfaces using widgets. Text, buttons, layouts, themes, screens, loading indicators, and navigation are all represented by widgets.

Widgets should display state and capture user actions. They should not own database credentials, backend authorization rules, or authoritative banking calculations.

### Android tools

- Android SDK Platform: APIs used when compiling.
- Android Build Tools: packages the Android application.
- Android Platform Tools: includes ADB.
- Android Command-line Tools: manages installed SDK components.
- Android Studio: IDE and SDK manager; it does not need to stay open.
- Android Emulator: optional because a physical device is being used.

The Android compile SDK can be newer than the phone's Android version. Compatibility also depends on the application's minimum supported SDK.

### ADB and wireless debugging

ADB is the Android Debug Bridge. Pairing establishes trust; connecting opens the debugging session. Flutter uses ADB to discover the phone, install the debug APK, launch the application, stream logs, and support debugging.

### What `flutter run` performs

1. Reads and compiles Dart code.
2. Uses Gradle and Android build tools.
3. Creates `app-debug.apk`.
4. Transfers the APK through ADB.
5. Installs and launches it on the phone.
6. Connects the Dart debugger and hot-reload service.

The first build is slower because Gradle and Android dependencies may need to be downloaded and prepared.

## 12. Development Commands and Their Purposes

| Command                       | Purpose                                                  |
| ----------------------------- | -------------------------------------------------------- |
| `flutter run`               | Build, install, launch, and debug the app                |
| `flutter analyze`           | Find Dart type, syntax, lint, and static-analysis issues |
| `flutter test`              | Run automated Flutter tests                              |
| `flutter devices`           | List targets recognized by Flutter                       |
| `dotnet run`                | Build and run the ASP.NET Core backend                   |
| `dotnet build`              | Compile the backend without starting it                  |
| `dotnet ef migrations list` | Show known EF Core migrations and applied status         |
| `dotnet ef database update` | Apply pending migrations                                 |
| `docker compose ... ps`     | Show Compose service state and health                    |
| `Invoke-RestMethod <URL>`   | Send an HTTP request from PowerShell                     |

During `flutter run`:

- `r`: hot reload
- `R`: hot restart
- `q`: quit and return to PowerShell
- `d`: detach while leaving the app running

Long-running backend and Flutter processes normally use separate terminal tabs.

## 13. Networking Fundamentals

A development API URL has these parts:

```text
http://192.168.x.x:5255/api/v1/system/info
|      |             |    |
scheme host          port path
```

- `localhost` means the current device.
- On the PC, `localhost` means the PC.
- On the phone, `localhost` means the phone.
- `0.0.0.0` tells a server to listen on available network interfaces.
- A client uses the PC's real private LAN address, not `0.0.0.0`.
- Windows Firewall should expose the development server only on the intended private network.

Opening the endpoint in the phone browser first verified:

```text
Phone browser -> local network -> Windows -> ASP.NET Core -> JSON response
```

The completed Flutter vertical slice later verified:

```text
Flutter screen
    -> Riverpod
    -> repository
    -> Dio
    -> local network
    -> ASP.NET Core
    -> JSON
    -> typed Dart model
    -> Flutter screen
```

The live phone screen displayed `Development`, while the automated test displayed `Test`. This proves that the screen renders values supplied by its provider rather than hardcoded API information.

### Verified phone result

![Banking Lab system-info screen displaying the live ASP.NET Core response](assets/flutter_01.png)

The system-info endpoint does not currently query PostgreSQL. It verifies mobile-to-backend connectivity, not a complete mobile-to-database request.

## 14. Installed Flutter Packages

The current `pubspec.yaml` includes:

### Application dependencies

- `flutter_riverpod`: state management and dependency provision.
- `dio`: HTTP client for API calls.
- `go_router`: application navigation and route protection later.
- `freezed_annotation`: annotations for immutable generated models.
- `json_annotation`: annotations for generated JSON conversion.
- `flutter_secure_storage`: protected token/session storage later.

### Development dependencies

- `build_runner`: runs Dart code generators.
- `freezed`: generates immutable Dart model code.
- `json_serializable`: generates JSON parsing and serialization.
- `flutter_test`: Flutter test framework.
- `flutter_lints`: static-analysis and style rules.

Installing a package only makes its code available; it does not automatically integrate the package into the application.

Currently used:

- Riverpod for configuration, dependency provision, asynchronous state, and test overrides.
- Dio for the system-info HTTP request.
- Flutter Test for unit and widget tests.

Installed for later work but not yet integrated:

- `go_router`
- Freezed and generated JSON serialization
- `flutter_secure_storage`

`pubspec.yaml` declares acceptable dependency constraints. `pubspec.lock` records the exact dependency versions resolved for reproducible builds.

## 15. Singleton and Dependency Lifetimes

A singleton is one shared object instance within a defined application lifetime.

```text
One configured Dio client
    -> system-info repository
    -> authentication repository
    -> accounts repository
```

Sharing one configured Dio client can centralize the base URL, timeouts, headers, authentication interceptors, safe logging rules, and reusable HTTP connections.

A singleton is not global across all devices. Each phone process has its own instance. Restarting the application creates a new lifetime. The backend process has separate instances of its own services.

Common dependency lifetimes are:

| Lifetime  | Meaning                                                        |
| --------- | -------------------------------------------------------------- |
| Singleton | One instance for the application/container lifetime            |
| Scoped    | One instance for a defined scope, commonly one ASP.NET request |
| Transient | A new instance each time it is requested                       |

`AppDbContext` is normally scoped per ASP.NET request, not singleton. A shared singleton DbContext could cause concurrency, stale tracking, and cross-request problems.

Riverpod providers can supply singleton-like shared instances within a `ProviderScope`, while still allowing controlled disposal, recreation, and test overrides.

Do not make every object a singleton. Shared infrastructure may benefit from controlled reuse, while screen-specific values and request-specific database tracking need shorter lifetimes.

## 16. Current Verified Status

| Area | Status |
| --- | --- |
| Git repository structure | Created |
| Secret and build-output ignore rules | Configured |
| Docker PostgreSQL | Healthy during verification |
| PostgreSQL credentials and connection | Verified |
| EF Core migration | Applied |
| ASP.NET Core build and startup | Verified |
| `GET /api/v1/system/info` | Returns live JSON |
| Flutter Android project | Builds and installs |
| Physical Infinix device | Connected through wireless ADB |
| Flutter system-info screen | Displays live backend values |
| Environment-aware API URL | Implemented |
| Dio client and API service | Implemented |
| Repository and Riverpod provider | Implemented |
| Loading, success, and failure UI | Verified |
| Retry behavior | Verified |
| Flutter analyzer | Passed |
| Flutter automated tests | Passed |
| Flutter-to-ASP.NET request | Verified on physical phone |
| Authentication and authorization | Not implemented |
| Accounts, balances, transfers, and transactions | Not implemented |
| Production deployment and hardening | Not implemented |

## 17. Completed Setup Milestone

The first end-to-end vertical slice in `BL-SETUP-001` Section 8 is complete.

Verified flow:

```text
SystemInfoScreen
    -> Riverpod FutureProvider
    -> SystemInfoRepository
    -> SystemInfoApiService
    -> Dio GET /api/v1/system/info
    -> ASP.NET Core
    -> JSON response
    -> typed SystemInfo model
    -> loading, success, or failure UI
```

Section 9, local Caddy, is optional and has been skipped during early development because direct local HTTP works on the physical Android device.

The `BL-SETUP-001` acceptance checks are complete:

```text
PostgreSQL healthy
-> EF migration applied
-> ASP.NET Core build and test command passed
-> Flutter analyze and tests passed
-> physical-phone API request verified
-> developer documentation updated
-> Git contents and secret exclusions reviewed
```

The next controlled guide is `BL-MOB-002`, Flutter Mobile Architecture and UI Engineering.

Some early `BL-MOB-002` foundations already exist because the setup guide required a working vertical slice. These foundations will be reviewed rather than recreated.

## 18. Review Questions

Use these questions for self-review:

1. Which programming language runs the mobile application code?
2. Which framework receives HTTP requests on the backend?
3. Why does Flutter communicate with ASP.NET through HTTP rather than calling C# directly?
4. What contract must both sides agree on?
5. Why must the phone not connect directly to PostgreSQL?
6. What is the difference between a Docker image, container, and volume?
7. What does an EF Core migration change?
8. Why does `localhost` mean something different on the phone and PC?
9. What does the live Flutter system-info screen prove, and why does it not yet prove a database request?
10. What is a singleton, and why should `AppDbContext` not be one?
11. What is the difference between `flutter analyze`, `flutter test`, and `flutter run`?
12. Which parts of Banking Lab are still unimplemented?

## 19. Short Mental Model

```text
PHONE
Dart = language
Flutter = UI framework
Dio = HTTP client

NETWORK
HTTP = request/response protocol
JSON = shared data format

SERVER
C# = language
ASP.NET Core = API framework
EF Core + Npgsql = database access

DATABASE
PostgreSQL = permanent relational storage

OPERATIONS
Docker = controlled local service environment
Git = source and documentation history

LIFETIME
Singleton = one shared instance inside a defined application lifetime
```

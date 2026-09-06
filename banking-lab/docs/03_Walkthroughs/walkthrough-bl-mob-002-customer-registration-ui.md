# Walkthrough: Mobile Customer Registration UI & Riverpod State (BL-MOB-002)

- Date: 2026-09-04
- Feature: BL-MOB-002 Flutter Customer Registration Screen & State Management
- Status: Initial UI delivery with historical 54/54 mobile and 92/92 backend test results; runtime registration remains gated
- Review correction (2026-09-04): The UI's 12-character guidance below describes the current defect, not the backend policy (15-128 NFC Unicode code points). See the [repair plan](../02_Planning/plan-authentication-repair.md). Widget tests do not establish manual/physical-device verification; no such check was performed during this documentation correction. The default email-delivery service is unconfigured, so a live valid registration returns 503 rather than a confirmation card.

---

## 1. What Was Delivered

1. **Error Hierarchy & ProblemDetails Mapping**:
   - Added `ValidationFailure` to `lib/core/errors/app_failure.dart` carrying field-level validation errors (`Map<String, List<String>>`).
   - Extended `lib/core/errors/api_error_mapper.dart` to catch HTTP 400 responses with ASP.NET Core `ProblemDetails` and extract field errors.

2. **Authentication Data Layer**:
   - Created `RegistrationRequest` model with `toJson()` matching backend parameters.
   - Created `RegistrationResponse` model with `fromJson()` parsing the 202 outcome.
   - Implemented `AuthenticationApiService` using Dio to execute `POST /api/v1/auth/register`.
   - Updated `AuthenticationRepository` with `register(RegistrationRequest)` and centralized error translation.

3. **Presentation Layer & UI**:
   - Built `RegistrationState` and `RegistrationController` using Riverpod `StateNotifier`.
   - Built `RegistrationScreen` with Material 3 design, email keyboard type, password visibility toggle, field error display, loading indicator, and a privacy-preserving success screen.
   - Added navigation from `SystemInfoScreen` ("Create Account" button).

4. **Automated Unit and Widget Tests**:
   - Created `registration_models_test.dart` (serialization & deserialization).
   - Created `authentication_api_service_test.dart` (Dio interceptor network tests).
   - Extended `authentication_repository_test.dart` (repository error mapping).
   - Created `registration_controller_test.dart` (pre-validation, loading, success, and error mapping).
   - Created `registration_screen_test.dart` (form rendering, password toggle, field error validation, submit flow, and success view).
   - **All 54 mobile tests passed**.

---

## 2. Core Logic Flow

```text
[ User fills RegistrationScreen ]
         │
         │  Taps 'Register'
         ▼
[ RegistrationController.register ]
         │
         ├─► Client-side validation:
         │     - Email format valid?
         │     - Password >= 12 chars?
         │     - Display name <= 60 chars?
         │     (If invalid -> set RegistrationStatus.failure with fieldErrors)
         │
         ▼ (If valid)
[ Set status: RegistrationStatus.submitting ]
         │
         ▼
[ AuthenticationRepository.register ]
         │
         ▼
[ AuthenticationApiService.register ]
         │  Dio POST /api/v1/auth/register
         ▼
[ ASP.NET Core Backend (Port 5000 / Docker Postgres) ]
         │
         ├─► Success (HTTP 202) -> return RegistrationResponse
         └─► Bad Request (HTTP 400) -> ProblemDetails with field errors
         │
         ▼
[ api_error_mapper -> ValidationFailure / NetworkFailure ]
         │
         ▼
[ Controller updates RegistrationState ]
         │
         ├─► On Success: displays confirmation screen ("Check your email to verify")
         └─► On Error: highlights specific invalid fields in red with error messages
```

---

## 3. Key Architectural & Security Concepts

### 1. StateNotifier / Riverpod Reactive State Management
- **Concept**: A pattern where immutable UI state is stored and modified strictly within a dedicated controller class.
- **In Banking Lab**: `RegistrationController` extends `StateNotifier<RegistrationState>`. UI widgets observe state via `ref.watch(registrationControllerProvider)` and reactively re-render only when relevant properties (`isSubmitting`, `fieldErrors`, `isSuccess`) change, completely decoupling business logic from widget lifecycle.

### 2. RFC 7807 Problem Details Handling in Mobile Clients
- **Concept**: A standard specification for HTTP error responses that provides structured machine-readable error reasons.
- **In Banking Lab**: When the ASP.NET Core API rejects a submission with HTTP 400, `api_error_mapper.dart` parses the `errors` dictionary and creates a `ValidationFailure`. The controller feeds this directly into the UI text fields, displaying errors (e.g. "Password must be at least 12 characters") right beneath the relevant input.

### 3. Anti-Enumeration Confirmation Flow in Mobile UX
- **Concept**: A security-conscious UX flow where the app never informs the client whether an account already existed.
- **In Banking Lab**: Upon receiving HTTP 202, the UI transitions to a dedicated confirmation card explaining that a verification link was sent to their email, accompanied by an explicit privacy note explaining that account existence is never disclosed.

---

## 4. Exact Repository Paths

| Component | Repository Path |
| :--- | :--- |
| **Error Mapper** | [`banking-lab/mobile/banking_mobile/lib/core/errors/api_error_mapper.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/core/errors/api_error_mapper.dart) |
| **Request Model** | [`banking-lab/mobile/banking_mobile/lib/features/authentication/data/models/registration_request.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/models/registration_request.dart) |
| **API Service** | [`banking-lab/mobile/banking_mobile/lib/features/authentication/data/services/authentication_api_service.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/services/authentication_api_service.dart) |
| **Repository** | [`banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart) |
| **Controller** | [`banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/registration_controller.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/registration_controller.dart) |
| **Screen Widget** | [`banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart) |
| **Widget Tests** | [`banking-lab/mobile/banking_mobile/test/features/authentication/presentation/screens/registration_screen_test.dart`](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/test/features/authentication/presentation/screens/registration_screen_test.dart) |

---

## 5. Verified Test Results

```text
flutter test:
00:19 +54: All tests passed! (0 failures)

dotnet test:
Passed!  - Failed: 0, Passed: 92, Skipped: 0, Total: 92 (Banking.IntegrationTests.dll)
```
Total automated test coverage across full-stack: **146 tests passed (0 failures)**.

# Implementation Plan: Mobile Customer Registration UI & Riverpod State (BL-MOB-002)

Build the Flutter customer registration screen, Riverpod state controller, and authentication API service in `banking_mobile`, connecting the mobile app to the backend registration endpoint with structured validation and accessible loading states.

## User Review Required

> [!IMPORTANT]
> **Anti-Enumeration UX**: In compliance with the backend's anti-enumeration design, successful submission does not log the user in immediately (email verification is required). The UI displays a dedicated confirmation card: *"If registration can proceed, check your email for the next step."*
>
> **Validation correction (2026-09-04)**: The initial UI implemented 12-character validation, which does not match `CustomerPasswordPolicy` (15-128 NFC Unicode code points). The [repair plan](plan-authentication-repair.md) covers alignment. The code/examples below are historical implementation details, not the approved password policy; do not copy their weaker rule into new features.

## Proposed Changes

### Core Error Infrastructure (`banking-lab/mobile/banking_mobile/lib/core/errors`)

#### [MODIFY] [app_failure.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/core/errors/app_failure.dart)
- Add `ValidationFailure` extending `AppFailure` with `Map<String, List<String>> fieldErrors` to capture field-keyed errors returned from ASP.NET Core `ProblemDetails`.

#### [MODIFY] [api_error_mapper.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/core/errors/api_error_mapper.dart)
- When receiving HTTP `400 Bad Request` with an `errors` object in response data, parse and map to `ValidationFailure` instead of a generic `ServerFailure`.

---

### Authentication Data Layer (`banking-lab/mobile/banking_mobile/lib/features/authentication/data`)

#### [NEW] [registration_request.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/models/registration_request.dart)
- Request DTO containing `email`, `password`, and optional `displayName` with `toJson()` serialization matching backend `CustomerRegistrationRequest`.

#### [NEW] [registration_response.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/models/registration_response.dart)
- Response DTO containing `outcome` (int/enum) and `message` (string) with `fromJson()` parsing.

#### [NEW] [authentication_api_service.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/services/authentication_api_service.dart)
- Injects `Dio` via `dioProvider`.
- Sends `POST /api/v1/auth/register` with JSON body.
- Returns `RegistrationResponse`.

#### [MODIFY] [authentication_repository.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart)
- Inject `AuthenticationApiService`.
- Expose `Future<RegistrationResponse> register(RegistrationRequest request)` catching exceptions and mapping through `mapApiError`.

---

### Authentication Presentation Layer (`banking-lab/mobile/banking_mobile/lib/features/authentication/presentation`)

#### [NEW] [registration_state.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/registration_state.dart)
- State record or union holding:
  - `status`: `idle`, `submitting`, `success`, `failure`
  - `fieldErrors`: `Map<String, String>`
  - `generalErrorMessage`: `String?`
  - `successMessage`: `String?`

#### [NEW] [registration_controller.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/registration_controller.dart)
- Riverpod `StateNotifier<RegistrationState>` / `NotifierProvider`.
- Performs client-side pre-validation.
- Calls `AuthenticationRepository.register`.
- Updates UI state seamlessly.

#### [NEW] [registration_screen.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart)
- Material 3 styled registration view:
  - Email field with autofocus and email keyboard type.
  - Password field with show/hide toggle icon and helper text (*Minimum 12 characters*).
  - Optional Display Name field.
  - Primary Submit button with loading spinner when submitting.
  - Success view with verification instructions and button to return.

#### [MODIFY] [app.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/app/app.dart) & [system_info_screen.dart](file:///d:/OtherProjects/kwek-kwekBank/banking-lab/mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart)
- Add navigation action to navigate from `SystemInfoScreen` to `RegistrationScreen`.

---

## Step-by-Step Logic (Pseudocode)

```text
FUNCTION SubmitRegistration(email, password, displayName):
    fieldErrors = {}
    IF email.trim().isEmpty:
        fieldErrors["email"] = "Email is required."
    ELSE IF NOT isValidEmail(email):
        fieldErrors["email"] = "Enter a valid email address."

    IF password.isEmpty:
        fieldErrors["password"] = "Password is required."
    ELSE IF password.length < 12:
        fieldErrors["password"] = "Password must be at least 12 characters."

    IF displayName != null AND displayName.length > 60:
        fieldErrors["displayName"] = "Display name cannot exceed 60 characters."

    IF fieldErrors is NOT empty:
        state = RegistrationState(status: failure, fieldErrors: fieldErrors)
        RETURN

    state = RegistrationState(status: submitting)
    TRY:
        response = AWAIT authRepository.register(RegistrationRequest(
            email: email.trim(),
            password: password,
            displayName: displayName?.trim(),
        ))
        state = RegistrationState(status: success, successMessage: response.message)
    CATCH ValidationFailure vf:
        state = RegistrationState(
            status: failure,
            fieldErrors: mapValidationErrors(vf.fieldErrors),
            generalErrorMessage: vf.message,
        )
    CATCH AppFailure af:
        state = RegistrationState(status: failure, generalErrorMessage: af.message)
```

---

## Verification Plan

### Automated Tests
- Run `flutter test` across all mobile test suites:
  - `authentication_api_service_test.dart`: verify POST call, JSON payload shape, and 202 parsing.
  - `authentication_repository_test.dart`: verify error mapping to `ValidationFailure` and `NetworkFailure`.
  - `registration_controller_test.dart`: verify state transitions (idle $\rightarrow$ submitting $\rightarrow$ success/failure).
  - `registration_screen_test.dart`: widget tests verifying form inputs, validation error rendering, loading spinner, and success confirmation screen.

### Manual Verification
- Visual inspection via `flutter test` widget tester and Flutter preview widget.

sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure()
    : super('Unable to reach the server. Check your connection and try again.');
}

final class SecureConnectionRequiredFailure extends AppFailure {
  const SecureConnectionRequiredFailure()
    : super(
        'Sign-in, registration and account access require an HTTPS API address. Ask the host to configure a trusted secure connection.',
      );
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure()
    : super('The request took too long. Please try again.');
}

final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode})
    : super('The server could not complete the request. Please try again.');

  final int? statusCode;
}

final class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure()
    : super('The server returned data the app could not understand.');
}

final class RequestCancelledFailure extends AppFailure {
  const RequestCancelledFailure() : super('The request was cancelled.');
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure()
    : super('Something unexpected happened. Please try again.');
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;
}

final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure()
    : super('Your session is no longer valid. Please sign in again.');
}

final class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure() : super('Invalid email or password.');
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure()
    : super('Too many attempts. Please wait a moment and try again.');
}

final class SessionStorageFailure extends AppFailure {
  const SessionStorageFailure()
    : super('Secure session storage is unavailable. Please sign in again.');
}

final class DevelopmentAccountRequiredFailure extends AppFailure {
  const DevelopmentAccountRequiredFailure()
    : super('Open your simulator account before adding test funds.');
}

final class DevelopmentFundingLimitFailure extends AppFailure {
  const DevelopmentFundingLimitFailure()
    : super(
        'This account has reached its PHP 100,000 Development funding limit for today in the Philippines.',
      );
}

final class IdempotencyConflictFailure extends AppFailure {
  const IdempotencyConflictFailure()
    : super('That retry key was already used for a different request.');
}

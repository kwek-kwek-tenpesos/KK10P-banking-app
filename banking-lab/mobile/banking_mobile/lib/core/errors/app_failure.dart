sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.requestId});

  final String message;
  final String? requestId;

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
  const ServerFailure({this.statusCode, super.requestId})
    : super('The server could not complete the request. Please try again.');

  final int? statusCode;
}

final class ClientUpgradeRequiredFailure extends AppFailure {
  const ClientUpgradeRequiredFailure({
    required this.platform,
    required this.minimumBuild,
    required this.updateUri,
    this.currentBuild,
    super.requestId,
  }) : super('A newer KK10P Bank app is required before you can continue.');

  final String platform;
  final int? currentBuild;
  final int minimumBuild;
  final Uri updateUri;
}

final class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure({super.requestId})
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
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.requestId,
  });

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
  const RateLimitedFailure({this.retryAfterSeconds, super.requestId})
    : super('Too many attempts. Please wait a moment and try again.');

  final int? retryAfterSeconds;
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

final class TransferAccountRequiredFailure extends AppFailure {
  const TransferAccountRequiredFailure({super.requestId})
    : super('Open your simulator account before transferring funds.');
}

final class TransferRecipientNotFoundFailure extends AppFailure {
  const TransferRecipientNotFoundFailure({super.requestId})
    : super('That simulator account cannot receive this transfer.');
}

final class TransferSelfNotAllowedFailure extends AppFailure {
  const TransferSelfNotAllowedFailure({super.requestId})
    : super('Choose another simulator account.');
}

final class TransferInsufficientFundsFailure extends AppFailure {
  const TransferInsufficientFundsFailure({super.requestId})
    : super('Your simulator account does not have enough funds.');
}

final class TransferDailyLimitFailure extends AppFailure {
  const TransferDailyLimitFailure({super.requestId})
    : super(
        'This transfer would exceed the PHP 100,000 daily outgoing limit for the current Philippine day.',
      );
}

final class TransferIdempotencyConflictFailure extends AppFailure {
  const TransferIdempotencyConflictFailure({super.requestId})
    : super(
        'This transfer retry no longer matches the server record. Do not submit it as a new transfer.',
      );
}

final class ActivityAccountRequiredFailure extends AppFailure {
  const ActivityAccountRequiredFailure({super.requestId})
    : super('Open your simulator account to view Activity.');
}

final class ActivityTransactionNotFoundFailure extends AppFailure {
  const ActivityTransactionNotFoundFailure({super.requestId})
    : super('That transaction is not available for this simulator account.');
}

final class PendingTransferStorageFailure extends AppFailure {
  const PendingTransferStorageFailure({this.corrupt = false})
    : super(
        corrupt
            ? 'Saved transfer recovery data is damaged. New transfers are blocked until it is safely reconciled.'
            : 'Secure transfer recovery storage is unavailable. Transfers are blocked until it is available.',
      );

  final bool corrupt;
}

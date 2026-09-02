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

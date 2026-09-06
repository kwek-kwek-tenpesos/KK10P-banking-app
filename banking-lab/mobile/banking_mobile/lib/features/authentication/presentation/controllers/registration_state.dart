enum RegistrationStatus { idle, submitting, success, failure }

class RegistrationState {
  final RegistrationStatus status;
  final Map<String, String> fieldErrors;
  final String? generalErrorMessage;
  final String? successMessage;

  const RegistrationState({
    this.status = RegistrationStatus.idle,
    this.fieldErrors = const {},
    this.generalErrorMessage,
    this.successMessage,
  });

  bool get isSubmitting => status == RegistrationStatus.submitting;
  bool get isSuccess => status == RegistrationStatus.success;
  bool get isFailure => status == RegistrationStatus.failure;

  RegistrationState copyWith({
    RegistrationStatus? status,
    Map<String, String>? fieldErrors,
    String? generalErrorMessage,
    String? successMessage,
  }) {
    return RegistrationState(
      status: status ?? this.status,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      generalErrorMessage: generalErrorMessage,
      successMessage: successMessage,
    );
  }
}

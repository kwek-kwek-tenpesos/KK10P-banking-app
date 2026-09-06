class RegistrationResponse {
  final int outcome;
  final String message;

  const RegistrationResponse({required this.outcome, required this.message});

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    final outcome = json['outcome'];
    final message = json['message'];

    if (outcome is! int || message is! String) {
      throw const FormatException(
        'Registration response requires integer outcome and string message fields.',
      );
    }

    return RegistrationResponse(outcome: outcome, message: message);
  }
}

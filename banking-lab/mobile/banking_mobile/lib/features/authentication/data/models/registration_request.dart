class RegistrationRequest {
  final String email;
  final String password;
  final String? displayName;

  const RegistrationRequest({
    required this.email,
    required this.password,
    this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (displayName != null && displayName!.isNotEmpty)
      'displayName': displayName,
  };
}

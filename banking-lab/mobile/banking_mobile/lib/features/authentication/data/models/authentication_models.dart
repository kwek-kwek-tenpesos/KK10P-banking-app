class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class AuthenticationTokens {
  const AuthenticationTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInSeconds,
  });

  factory AuthenticationTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final tokenType = json['tokenType'];
    final expiresInSeconds = json['expiresInSeconds'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        tokenType != 'Bearer' ||
        expiresInSeconds is! int ||
        expiresInSeconds < 1 ||
        expiresInSeconds > 600) {
      throw const FormatException('Invalid authentication token response.');
    }

    return AuthenticationTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresInSeconds: expiresInSeconds,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInSeconds;
}

class AuthenticatedCustomer {
  const AuthenticatedCustomer({required this.id, this.displayName});

  factory AuthenticatedCustomer.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final displayName = json['displayName'];

    if (id is! String ||
        id.isEmpty ||
        (displayName != null && displayName is! String)) {
      throw const FormatException('Invalid customer profile response.');
    }

    return AuthenticatedCustomer(id: id, displayName: displayName as String?);
  }

  final String id;
  final String? displayName;
}

class AuthenticationSession {
  const AuthenticationSession({
    required this.customer,
    required this.accessToken,
    required this.accessTokenExpiresAt,
  });

  final AuthenticatedCustomer customer;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
}

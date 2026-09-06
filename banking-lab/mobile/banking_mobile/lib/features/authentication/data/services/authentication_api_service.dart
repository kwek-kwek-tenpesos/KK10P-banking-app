import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/authentication/data/models/authentication_models.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_request.dart';
import 'package:banking_mobile/features/authentication/data/models/registration_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthenticationApiService {
  AuthenticationApiService(this._dio);

  final Dio _dio;

  Future<RegistrationResponse> register(RegistrationRequest request) async {
    _requireSecureConnection();
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: request.toJson(),
      options: _credentialOptions(),
    );

    final data = response.data;
    if (data == null) {
      throw const FormatException('Expected non-null registration response.');
    }

    return RegistrationResponse.fromJson(data);
  }

  Future<AuthenticationTokens> login(LoginRequest request) async {
    _requireSecureConnection();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: request.toJson(),
        options: _credentialOptions(),
      );
      return AuthenticationTokens.fromJson(_requireBody(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const InvalidCredentialsFailure();
      }
      rethrow;
    }
  }

  Future<AuthenticationTokens> refresh(String refreshToken) async {
    _requireSecureConnection();
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: _credentialOptions(),
    );
    return AuthenticationTokens.fromJson(_requireBody(response.data));
  }

  Future<void> logout(String refreshToken) async {
    _requireSecureConnection();
    await _dio.post<void>(
      '/api/v1/auth/logout',
      data: {'refreshToken': refreshToken},
      options: _credentialOptions(),
    );
  }

  Future<AuthenticatedCustomer> getCurrentCustomer(String accessToken) async {
    _requireSecureConnection();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/me',
      options: _credentialOptions(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return AuthenticatedCustomer.fromJson(_requireBody(response.data));
  }

  Future<void> confirmEmail({
    required String userId,
    required String token,
  }) async {
    _requireSecureConnection();
    await _dio.post<void>(
      '/api/v1/auth/verify-email',
      data: {'userId': userId, 'token': token},
      options: _credentialOptions(),
    );
  }

  Future<String> resendVerification(String email) async {
    _requireSecureConnection();
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/resend-verification',
      data: {'email': email},
      options: _credentialOptions(),
    );
    final data = _requireBody(response.data);
    final message = data['message'];
    if (message is! String || message.isEmpty) {
      throw const FormatException('Expected a verification response message.');
    }
    return message;
  }

  void _requireSecureConnection() {
    final uri = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SecureConnectionRequiredFailure();
    }
  }

  Options _credentialOptions({Map<String, dynamic>? headers}) => Options(
    // Never forward a credential-bearing request through a redirect.
    followRedirects: false,
    maxRedirects: 0,
    headers: headers,
  );

  Map<String, dynamic> _requireBody(Map<String, dynamic>? data) {
    if (data == null) {
      throw const FormatException(
        'Expected a non-null authentication response.',
      );
    }
    return data;
  }
}

final authenticationApiServiceProvider = Provider<AuthenticationApiService>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  return AuthenticationApiService(dio);
});

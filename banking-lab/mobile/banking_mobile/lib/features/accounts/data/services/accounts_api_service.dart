import 'package:banking_mobile/core/api/dio_provider.dart';
import 'package:banking_mobile/core/errors/api_error_mapper.dart';
import 'package:banking_mobile/core/errors/app_failure.dart';
import 'package:banking_mobile/features/accounts/data/models/account_summary.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsApiService {
  AccountsApiService(this._dio);
  final Dio _dio;

  Future<AccountSummary?> read(String token) => _request(token, open: false);
  Future<AccountSummary> open(String token) async {
    final account = await _request(token, open: true);
    if (account == null) throw const InvalidResponseFailure();
    return account;
  }

  Future<AccountSummary?> _request(String token, {required bool open}) async {
    final uri = Uri.tryParse(_dio.options.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const SecureConnectionRequiredFailure();
    }
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        '/api/v1/accounts/me',
        data: open ? <String, dynamic>{} : null,
        options: Options(
          method: open ? 'PUT' : 'GET',
          contentType: open ? Headers.jsonContentType : null,
          followRedirects: false,
          maxRedirects: 0,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (!(open ? [200, 201] : [200]).contains(response.statusCode) ||
          response.data == null) {
        throw const InvalidResponseFailure();
      }
      return AccountSummary.fromJson(response.data!);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (!open &&
          error.response?.statusCode == 404 &&
          data is Map &&
          data['code'] == 'account_not_opened') {
        return null;
      }
      throw mapApiError(error);
    } on FormatException {
      throw const InvalidResponseFailure();
    }
  }
}

final accountsApiServiceProvider = Provider<AccountsApiService>(
  (ref) => AccountsApiService(ref.watch(dioProvider)),
);

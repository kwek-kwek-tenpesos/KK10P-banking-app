import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Start Flutter with '
        '--dart-define=API_BASE_URL=http://YOUR_PC_IP:5255',
      );
    }

    final uri = Uri.tryParse(apiBaseUrl);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError(
        'API_BASE_URL must be a complete URL, such as '
        'http://192.168.1.10:5255',
      );
    }

    return AppConfig(apiBaseUrl: apiBaseUrl);
  }

  final String apiBaseUrl;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('appConfigProvider must be overridden during app startup.');
});

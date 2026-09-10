import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const clientPlatformAndroid = 'ANDROID';
const maximumClientBuild = 999999999;

sealed class ClientBuildMetadata {
  const ClientBuildMetadata();
}

final class ValidClientBuildMetadata extends ClientBuildMetadata {
  const ValidClientBuildMetadata(this.info);

  final ClientBuildInfo info;
}

final class InvalidClientBuildMetadata extends ClientBuildMetadata {
  const InvalidClientBuildMetadata();
}

class ClientBuildInfo {
  const ClientBuildInfo({
    required this.platform,
    required this.build,
    required this.version,
  });

  final String platform;
  final int build;
  final String version;

  static ClientBuildInfo? tryParse({
    required String platform,
    required String build,
    required String version,
  }) {
    if (platform != clientPlatformAndroid ||
        !RegExp(r'^[1-9][0-9]{0,8}$').hasMatch(build)) {
      return null;
    }
    final parsed = int.tryParse(build);
    if (parsed == null || parsed > maximumClientBuild) return null;
    return ClientBuildInfo(
      platform: platform,
      build: parsed,
      version: version.trim(),
    );
  }
}

Future<ClientBuildMetadata> loadClientBuildMetadata() async {
  try {
    final package = await PackageInfo.fromPlatform();
    final parsed = ClientBuildInfo.tryParse(
      platform: clientPlatformAndroid,
      build: package.buildNumber,
      version: package.version,
    );
    return parsed == null
        ? const InvalidClientBuildMetadata()
        : ValidClientBuildMetadata(parsed);
  } catch (_) {
    return const InvalidClientBuildMetadata();
  }
}

final clientBuildMetadataProvider = Provider<ClientBuildMetadata>((ref) {
  return const InvalidClientBuildMetadata();
});

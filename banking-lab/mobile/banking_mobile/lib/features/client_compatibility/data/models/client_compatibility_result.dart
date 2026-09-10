import 'package:banking_mobile/features/client_compatibility/data/models/client_build_info.dart';

class ClientCompatibilityResult {
  const ClientCompatibilityResult({
    required this.currentBuild,
    required this.minimumBuild,
    this.updateUri,
  });

  final int currentBuild;
  final int minimumBuild;
  final Uri? updateUri;

  static ClientCompatibilityResult? tryParse(
    Object? data,
    ClientBuildInfo local,
  ) {
    if (data is! Map ||
        data['platform'] != local.platform ||
        data['currentBuild'] != local.build ||
        data['updateRequired'] != false) {
      return null;
    }
    final minimum = data['minimumBuild'];
    if (minimum is! int || minimum < 1 || minimum > maximumClientBuild) {
      return null;
    }

    final updateText = data['updateUri'];
    Uri? updateUri;
    if (updateText != null) {
      if (updateText is! String || updateText.length > 2048) return null;
      updateUri = Uri.tryParse(updateText);
      if (updateUri == null ||
          updateUri.scheme != 'https' ||
          !updateUri.hasAuthority ||
          updateUri.host.isEmpty ||
          updateUri.userInfo.isNotEmpty) {
        return null;
      }
    }
    return ClientCompatibilityResult(
      currentBuild: local.build,
      minimumBuild: minimum,
      updateUri: updateUri,
    );
  }
}

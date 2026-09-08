class SystemInfo {
  final String environment;
  final String name;
  final String version;

  const SystemInfo({
    required this.name,
    required this.version,
    required this.environment,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final version = json['version'];
    final environment = json['environment'];

    if (name is! String || version is! String || environment is! String) {
      throw const FormatException(
        'System info requires string name, version, and environment fields.',
      );
    }

    return SystemInfo(name: name, version: version, environment: environment);
  }
}

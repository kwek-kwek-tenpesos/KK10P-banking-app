class SystemInfo {
  const SystemInfo({
    required this.name,
    required this.version,
    required this.environment,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      environment: json['environment'] as String,
    );
  }

  final String name;
  final String version;
  final String environment;
}

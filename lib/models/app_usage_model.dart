class AppUsageModel {
  final String packageName;
  final String appName;
  final Duration todayUsage;
  final Duration totalUsage;
  final DateTime lastUsed;

  AppUsageModel({
    required this.packageName,
    required this.appName,
    required this.todayUsage,
    required this.totalUsage,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'todayUsage': todayUsage.inSeconds,
      'totalUsage': totalUsage.inSeconds,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory AppUsageModel.fromJson(Map<String, dynamic> json) {
    return AppUsageModel(
      packageName: json['packageName'] ?? '',
      appName: json['appName'] ?? '',
      todayUsage: Duration(seconds: json['todayUsage'] ?? 0),
      totalUsage: Duration(seconds: json['totalUsage'] ?? 0),
      lastUsed: DateTime.parse(json['lastUsed'] ?? DateTime.now().toIso8601String()),
    );
  }
}

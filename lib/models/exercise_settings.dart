enum ExerciseType {
  squats,
  headNods,
}

class ExerciseSettings {
  final List<String> monitoredApps;
  final int usageTimeLimitMinutes;
  final int rewardTimeMinutes;
  final ExerciseType exerciseType;
  final int repCount;
  final bool isMonitoringEnabled;

  ExerciseSettings({
    required this.monitoredApps,
    required this.usageTimeLimitMinutes,
    required this.rewardTimeMinutes,
    required this.exerciseType,
    required this.repCount,
    required this.isMonitoringEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'monitoredApps': monitoredApps,
      'usageTimeLimitMinutes': usageTimeLimitMinutes,
      'rewardTimeMinutes': rewardTimeMinutes,
      'exerciseType': exerciseType.name,
      'repCount': repCount,
      'isMonitoringEnabled': isMonitoringEnabled,
    };
  }

  factory ExerciseSettings.fromJson(Map<String, dynamic> json) {
    return ExerciseSettings(
      monitoredApps: List<String>.from(json['monitoredApps'] ?? []),
      usageTimeLimitMinutes: json['usageTimeLimitMinutes'] ?? 15,
      rewardTimeMinutes: json['rewardTimeMinutes'] ?? 5,
      exerciseType: ExerciseType.values.firstWhere(
        (e) => e.name == json['exerciseType'],
        orElse: () => ExerciseType.squats,
      ),
      repCount: json['repCount'] ?? 20,
      isMonitoringEnabled: json['isMonitoringEnabled'] ?? false,
    );
  }
}

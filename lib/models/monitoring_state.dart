class MonitoringState {
  final Map<String, Duration> currentSessionUsage;
  final DateTime? rewardTimeExpiry;
  final bool isOverlayActive;
  final String? currentMonitoredApp;

  MonitoringState({
    required this.currentSessionUsage,
    this.rewardTimeExpiry,
    required this.isOverlayActive,
    this.currentMonitoredApp,
  });

  bool isInRewardPeriod() {
    if (rewardTimeExpiry == null) return false;
    return DateTime.now().isBefore(rewardTimeExpiry!);
  }

  bool shouldTriggerIntervention(Duration limit) {
    if (currentMonitoredApp == null) return false;
    if (isInRewardPeriod()) return false;
    
    final usage = currentSessionUsage[currentMonitoredApp] ?? Duration.zero;
    return usage >= limit;
  }

  Map<String, dynamic> toJson() {
    return {
      'currentSessionUsage': currentSessionUsage.map(
        (key, value) => MapEntry(key, value.inSeconds),
      ),
      'rewardTimeExpiry': rewardTimeExpiry?.toIso8601String(),
      'isOverlayActive': isOverlayActive,
      'currentMonitoredApp': currentMonitoredApp,
    };
  }

  factory MonitoringState.fromJson(Map<String, dynamic> json) {
    final usageJson = json['currentSessionUsage'] as Map<String, dynamic>? ?? {};
    final usage = <String, Duration>{};
    
    for (final entry in usageJson.entries) {
      usage[entry.key] = Duration(seconds: entry.value as int);
    }

    return MonitoringState(
      currentSessionUsage: usage,
      rewardTimeExpiry: json['rewardTimeExpiry'] != null
          ? DateTime.parse(json['rewardTimeExpiry'])
          : null,
      isOverlayActive: json['isOverlayActive'] ?? false,
      currentMonitoredApp: json['currentMonitoredApp'],
    );
  }
}

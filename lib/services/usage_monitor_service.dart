import 'package:app_usage/app_usage.dart';
import '../models/monitoring_state.dart';
import '../models/app_usage_model.dart';
import '../utils/storage_helper.dart';

class UsageMonitorService {
  // State variables
  Set<String> monitoredApps = {};
  Map<String, DateTime> usageStartTime = {};
  Map<String, Duration> cumulativeUsage = {};
  DateTime? rewardTimeExpiry;
  Duration usageTimeLimit = const Duration(minutes: 15);
  Duration rewardDuration = const Duration(minutes: 5);
  
  // Track current monitored app
  String? currentMonitoredApp;
  
  // Track last check time to calculate incremental usage
  DateTime? lastCheckTime;
  
  // Singleton pattern
  static final UsageMonitorService _instance = UsageMonitorService._internal();
  factory UsageMonitorService() => _instance;
  UsageMonitorService._internal();

  /// Initialize the service with settings
  Future<void> initialize({
    required Set<String> apps,
    required Duration timeLimit,
    required Duration reward,
  }) async {
    monitoredApps = apps;
    usageTimeLimit = timeLimit;
    rewardDuration = reward;
    
    // Load existing state
    await _loadState();
  }

  /// Load monitoring state from storage
  Future<void> _loadState() async {
    try {
      final state = await StorageHelper.loadState();
      if (state != null) {
        cumulativeUsage = Map.from(state.currentSessionUsage);
        rewardTimeExpiry = state.rewardTimeExpiry;
        currentMonitoredApp = state.currentMonitoredApp;
      }
    } catch (e) {
      print('Error loading monitoring state: $e');
    }
  }

  /// Check the current foreground app using AppUsage
  Future<String?> checkCurrentApp() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(seconds: 10));
      
      final usageList = await AppUsage().getAppUsage(startDate, endDate);
      
      if (usageList.isEmpty) {
        return null;
      }
      
      // Find the most recently used app
      final currentApp = usageList.last.packageName;
      
      // Check if it's a monitored app
      if (monitoredApps.contains(currentApp)) {
        // Update usage time
        await updateUsageTime(currentApp);
        return currentApp;
      }
      
      return null;
    } catch (e) {
      print('Error checking current app: $e');
      return null;
    }
  }

  /// Update cumulative usage time for a specific app
  Future<void> updateUsageTime(String packageName) async {
    final now = DateTime.now();
    
    // Initialize usage start time if this is the first time seeing this app
    if (!usageStartTime.containsKey(packageName)) {
      usageStartTime[packageName] = now;
      currentMonitoredApp = packageName;
    }
    
    // Calculate time elapsed since last check
    if (lastCheckTime != null && currentMonitoredApp == packageName) {
      final elapsed = now.difference(lastCheckTime!);
      
      // Add elapsed time to cumulative usage
      cumulativeUsage[packageName] = 
          (cumulativeUsage[packageName] ?? Duration.zero) + elapsed;
    }
    
    lastCheckTime = now;
    currentMonitoredApp = packageName;
    
    // Persist the updated usage data
    await persistUsageData();
  }

  /// Check if usage limit has been exceeded
  bool isLimitExceeded() {
    // Don't trigger intervention if in reward period
    if (isInRewardPeriod()) {
      return false;
    }
    
    // Check if any monitored app has exceeded the limit
    for (final app in monitoredApps) {
      final usage = cumulativeUsage[app] ?? Duration.zero;
      if (usage >= usageTimeLimit) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if currently in reward period
  bool isInRewardPeriod() {
    if (rewardTimeExpiry == null) return false;
    return DateTime.now().isBefore(rewardTimeExpiry!);
  }

  /// Reset usage timer after exercise completion
  Future<void> resetUsageTimer() async {
    // Clear cumulative usage for all monitored apps
    cumulativeUsage.clear();
    usageStartTime.clear();
    currentMonitoredApp = null;
    lastCheckTime = null;
    
    // Persist the reset state
    await persistUsageData();
  }

  /// Grant reward time after successful exercise completion
  Future<void> grantRewardTime([Duration? customDuration]) async {
    final now = DateTime.now();
    final duration = customDuration ?? rewardDuration;
    rewardTimeExpiry = now.add(duration);
    
    // Reset usage timer when granting reward time
    await resetUsageTimer();
    
    print('Reward time granted until: $rewardTimeExpiry');
  }

  /// Static method to grant reward time (for use from other parts of the app)
  static Future<void> grantRewardTime(Duration duration) async {
    final service = UsageMonitorService();
    await service.grantRewardTime(duration);
  }

  /// Persist usage data to storage
  Future<void> persistUsageData() async {
    try {
      // Create monitoring state
      final state = MonitoringState(
        currentSessionUsage: cumulativeUsage,
        rewardTimeExpiry: rewardTimeExpiry,
        isOverlayActive: false,
        currentMonitoredApp: currentMonitoredApp,
      );
      
      // Save to storage
      await StorageHelper.saveState(state);
      
      // Also update app usage models for dashboard
      await _updateAppUsageModels();
    } catch (e) {
      print('Error persisting usage data: $e');
    }
  }

  /// Update app usage models for statistics tracking
  Future<void> _updateAppUsageModels() async {
    try {
      // Load existing usage data
      final existingUsage = await StorageHelper.loadUsageData();
      final usageMap = <String, AppUsageModel>{};
      
      // Convert list to map for easier lookup
      for (final usage in existingUsage) {
        usageMap[usage.packageName] = usage;
      }
      
      // Update with current session usage
      for (final entry in cumulativeUsage.entries) {
        final packageName = entry.key;
        final sessionUsage = entry.value;
        
        if (usageMap.containsKey(packageName)) {
          // Update existing entry
          final existing = usageMap[packageName]!;
          usageMap[packageName] = AppUsageModel(
            packageName: packageName,
            appName: existing.appName,
            todayUsage: existing.todayUsage + sessionUsage,
            totalUsage: existing.totalUsage + sessionUsage,
            lastUsed: DateTime.now(),
          );
        } else {
          // Create new entry
          usageMap[packageName] = AppUsageModel(
            packageName: packageName,
            appName: _getAppName(packageName),
            todayUsage: sessionUsage,
            totalUsage: sessionUsage,
            lastUsed: DateTime.now(),
          );
        }
      }
      
      // Save updated usage data
      await StorageHelper.saveUsageData(usageMap.values.toList());
    } catch (e) {
      print('Error updating app usage models: $e');
    }
  }

  /// Extract app name from package name
  String _getAppName(String packageName) {
    // Simple extraction - take last part after last dot
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      return parts.last.replaceAll('_', ' ').replaceAllMapped(
        RegExp(r'\b\w'),
        (match) => match.group(0)!.toUpperCase(),
      );
    }
    return packageName;
  }

  /// Get current usage for a specific app
  Duration getUsageForApp(String packageName) {
    return cumulativeUsage[packageName] ?? Duration.zero;
  }

  /// Get total usage across all monitored apps
  Duration getTotalUsage() {
    return cumulativeUsage.values.fold(
      Duration.zero,
      (total, usage) => total + usage,
    );
  }

  /// Check if a specific app should trigger intervention
  bool shouldTriggerInterventionForApp(String packageName) {
    if (isInRewardPeriod()) return false;
    if (!monitoredApps.contains(packageName)) return false;
    
    final usage = cumulativeUsage[packageName] ?? Duration.zero;
    return usage >= usageTimeLimit;
  }

  /// Update settings (called when user changes settings)
  Future<void> updateSettings({
    Set<String>? apps,
    Duration? timeLimit,
    Duration? reward,
  }) async {
    if (apps != null) monitoredApps = apps;
    if (timeLimit != null) usageTimeLimit = timeLimit;
    if (reward != null) rewardDuration = reward;
    
    // Persist updated state
    await persistUsageData();
  }

  /// Reset daily statistics (should be called at midnight)
  Future<void> resetDailyStats() async {
    // This would typically be called by a daily timer
    // For now, just clear cumulative usage
    await resetUsageTimer();
  }

  /// Get remaining time before limit is reached
  Duration getRemainingTime() {
    if (isInRewardPeriod()) {
      return rewardTimeExpiry!.difference(DateTime.now());
    }
    
    // Find the app with most usage
    Duration maxUsage = Duration.zero;
    for (final usage in cumulativeUsage.values) {
      if (usage > maxUsage) {
        maxUsage = usage;
      }
    }
    
    final remaining = usageTimeLimit - maxUsage;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

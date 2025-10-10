import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/material.dart';
import '../models/exercise_settings.dart';
import '../utils/storage_helper.dart';
import 'usage_monitor_service.dart';
import 'overlay_service.dart';

/// Configuration for the foreground service
class ForegroundServiceConfig {
  /// Get the foreground task options
  static AndroidNotificationOptions getAndroidNotificationOptions() {
    return AndroidNotificationOptions(
      channelId: 'fitness_wellbeing_channel',
      channelName: 'Fitness Wellbeing Monitoring',
      channelDescription: 'Monitors app usage and enforces exercise breaks',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    );
  }

  /// Get the foreground task options
  static ForegroundTaskOptions getForegroundTaskOptions() {
    return ForegroundTaskOptions(
      interval: 5000, // 5 seconds
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: false,
    );
  }

  /// Get the notification content
  static NotificationContent getNotificationContent() {
    return const NotificationContent(
      id: 1000,
      channelId: 'fitness_wellbeing_channel',
      title: 'Monitoring Active',
      text: 'Tracking app usage and enforcing exercise breaks',
    );
  }
}

/// TaskHandler for the foreground service
/// Runs continuously to monitor app usage and trigger interventions
@pragma('vm:entry-point')
class MyTaskHandler extends TaskHandler {
  // Service instances
  final UsageMonitorService _usageMonitor = UsageMonitorService();
  final OverlayService _overlayService = OverlayService();
  
  // Settings
  ExerciseSettings? _settings;
  
  // Track if we've triggered overlay to prevent repeated triggers
  bool _overlayTriggered = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground service started at $timestamp');
    
    // Load settings from storage
    await _loadSettings();
    
    // Initialize usage monitor with settings
    if (_settings != null) {
      await _usageMonitor.initialize(
        apps: _settings!.monitoredApps.toSet(),
        timeLimit: Duration(minutes: _settings!.usageTimeLimitMinutes),
        reward: Duration(minutes: _settings!.rewardTimeMinutes),
      );
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This runs every 5 seconds (configured in service options)
    
    // Load settings if not loaded
    if (_settings == null) {
      await _loadSettings();
      if (_settings == null) return;
    }
    
    // Check if monitoring is enabled
    if (!_settings!.isMonitoringEnabled) {
      return;
    }
    
    // Check current app and update usage
    final currentApp = await _usageMonitor.checkCurrentApp();
    
    // Check if overlay should be shown
    if (_usageMonitor.isLimitExceeded() && !_overlayTriggered) {
      // Trigger overlay intervention
      await _overlayService.showExerciseChallenge();
      _overlayTriggered = true;
      print('Overlay triggered for app: $currentApp');
    }
    
    // Check if overlay was dismissed externally and reopen if needed
    if (_overlayTriggered && !await _overlayService.isOverlayActive()) {
      // Overlay was dismissed but limit still exceeded
      if (_usageMonitor.isLimitExceeded()) {
        print('Overlay was dismissed externally, reopening...');
        await _overlayService.showExerciseChallenge();
      } else {
        // Limit no longer exceeded (exercise completed or reward time granted)
        _overlayTriggered = false;
      }
    }
    
    // Reset overlay trigger flag if we're in reward period
    if (_usageMonitor.isInRewardPeriod()) {
      _overlayTriggered = false;
    }
    
    // Send data to main isolate for UI updates if needed
    FlutterForegroundTask.sendDataToMain({
      'timestamp': timestamp.toIso8601String(),
      'currentApp': currentApp,
      'isLimitExceeded': _usageMonitor.isLimitExceeded(),
      'isInRewardPeriod': _usageMonitor.isInRewardPeriod(),
      'remainingTime': _usageMonitor.getRemainingTime().inSeconds,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('Foreground service destroyed at $timestamp');
    
    // Persist final state before cleanup
    await _usageMonitor.persistUsageData();
    
    // Close overlay if it's still open
    if (_overlayService.isOverlayShown) {
      await _overlayService.closeOverlay();
    }
  }

  @override
  void onNotificationPressed() {
    // Open the app when notification is pressed
    print('Notification pressed, opening app');
    FlutterForegroundTask.launchApp('/');
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      _settings = await StorageHelper.loadSettings();
      
      // Update usage monitor if settings loaded
      if (_settings != null) {
        await _usageMonitor.updateSettings(
          apps: _settings!.monitoredApps.toSet(),
          timeLimit: Duration(minutes: _settings!.usageTimeLimitMinutes),
          reward: Duration(minutes: _settings!.rewardTimeMinutes),
        );
      }
    } catch (e) {
      print('Error loading settings in foreground service: $e');
    }
  }
  
  /// Update settings (called when user changes settings)
  Future<void> updateSettings(ExerciseSettings settings) async {
    _settings = settings;
    
    // Update usage monitor
    await _usageMonitor.updateSettings(
      apps: settings.monitoredApps.toSet(),
      timeLimit: Duration(minutes: settings.usageTimeLimitMinutes),
      reward: Duration(minutes: settings.rewardTimeMinutes),
    );
    
    print('Foreground service settings updated');
  }
}


/// Service manager for starting and stopping the foreground service
class ForegroundServiceManager {
  // Singleton pattern
  static final ForegroundServiceManager _instance = ForegroundServiceManager._internal();
  factory ForegroundServiceManager() => _instance;
  ForegroundServiceManager._internal();

  /// Initialize the foreground task
  /// Should be called once in main() before starting the service
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: ForegroundServiceConfig.getAndroidNotificationOptions(),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundServiceConfig.getForegroundTaskOptions(),
    );
  }

  /// Start the monitoring service
  /// Initializes and starts the foreground task
  Future<bool> startMonitoringService() async {
    try {
      // Check if service is already running
      if (await FlutterForegroundTask.isRunningService) {
        print('Foreground service is already running');
        return true;
      }

      // Load settings to verify monitoring is enabled
      final settings = await StorageHelper.loadSettings();
      if (settings == null || !settings.isMonitoringEnabled) {
        print('Monitoring is not enabled in settings');
        return false;
      }

      // Start the foreground service
      final serviceStarted = await FlutterForegroundTask.startService(
        notificationTitle: 'Monitoring Active',
        notificationText: 'Tracking app usage and enforcing exercise breaks',
        notificationIcon: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        callback: startCallback,
      );

      if (serviceStarted) {
        print('Foreground service started successfully');
      } else {
        print('Failed to start foreground service');
      }

      return serviceStarted;
    } catch (e) {
      print('Error starting monitoring service: $e');
      return false;
    }
  }

  /// Stop the monitoring service
  /// Stops the foreground task and clears the notification
  Future<bool> stopMonitoringService() async {
    try {
      // Check if service is running
      if (!await FlutterForegroundTask.isRunningService) {
        print('Foreground service is not running');
        return true;
      }

      // Stop the foreground service
      final serviceStopped = await FlutterForegroundTask.stopService();

      if (serviceStopped) {
        print('Foreground service stopped successfully');
      } else {
        print('Failed to stop foreground service');
      }

      return serviceStopped;
    } catch (e) {
      print('Error stopping monitoring service: $e');
      return false;
    }
  }

  /// Restart the monitoring service
  /// Useful when settings are updated
  Future<bool> restartMonitoringService() async {
    try {
      await stopMonitoringService();
      await Future.delayed(const Duration(milliseconds: 500));
      return await startMonitoringService();
    } catch (e) {
      print('Error restarting monitoring service: $e');
      return false;
    }
  }

  /// Check if the service is currently running
  Future<bool> isServiceRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (e) {
      print('Error checking service status: $e');
      return false;
    }
  }

  /// Update service configuration
  /// Sends updated settings to the running service
  Future<void> updateServiceConfig(ExerciseSettings settings) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        // Send data to the service
        await FlutterForegroundTask.sendDataToTask({
          'action': 'updateSettings',
          'settings': settings.toJson(),
        });
        print('Service configuration updated');
      }
    } catch (e) {
      print('Error updating service config: $e');
    }
  }

  /// Setup data receiver to get updates from the service
  /// Call this in your main widget to receive service updates
  static void setupDataReceiver(Function(dynamic) onData) {
    FlutterForegroundTask.receivePort?.listen((data) {
      if (data != null) {
        onData(data);
      }
    });
  }

  /// Request to ignore battery optimization
  /// Helps prevent the service from being killed
  static Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      return true;
    } catch (e) {
      print('Error requesting battery optimization: $e');
      return false;
    }
  }
}

/// Callback function for the foreground service
/// This is the entry point for the service
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

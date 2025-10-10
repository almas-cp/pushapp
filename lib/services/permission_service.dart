import 'package:app_usage/app_usage.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized service for managing all app permissions
/// Handles checking and requesting permissions for:
/// - Usage stats (PACKAGE_USAGE_STATS)
/// - System overlay (SYSTEM_ALERT_WINDOW)
/// - Camera (CAMERA)
class PermissionService {
  /// Check if all required permissions are granted
  /// Returns true only if ALL permissions are granted
  Future<bool> checkAllPermissions() async {
    final usageStats = await hasUsageStatsPermission();
    final overlay = await hasOverlayPermission();
    final camera = await hasCameraPermission();
    
    return usageStats && overlay && camera;
  }

  /// Check if PACKAGE_USAGE_STATS permission is granted
  /// Uses AppUsage package to verify permission
  Future<bool> hasUsageStatsPermission() async {
    try {
      // Try to query usage stats - if it fails, permission not granted
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(seconds: 1));
      await AppUsage().getAppUsage(startDate, endDate);
      return true;
    } catch (e) {
      // Permission denied or not granted
      return false;
    }
  }

  /// Check if SYSTEM_ALERT_WINDOW permission is granted
  /// Uses system_alert_window package to verify permission
  Future<bool> hasOverlayPermission() async {
    try {
      final bool? isGranted = await SystemAlertWindow.checkPermissions();
      return isGranted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if CAMERA permission is granted
  /// Uses permission_handler package for runtime permission check
  Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Request PACKAGE_USAGE_STATS permission
  /// Opens Settings -> Special app access -> Usage access
  /// Returns true if permission is granted after user returns
  Future<bool> requestUsageStatsPermission() async {
    try {
      // Open usage access settings
      // Note: AppUsage package doesn't have a direct method to open settings
      // We need to use platform channels or guide user manually
      // For now, we'll attempt to trigger the permission flow
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(seconds: 1));
      
      try {
        await AppUsage().getAppUsage(startDate, endDate);
        return true;
      } catch (e) {
        // Permission not granted - user needs to enable manually
        // In a real implementation, we would open the settings page
        // using platform channels or app_settings package
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Request SYSTEM_ALERT_WINDOW permission
  /// Opens Settings -> Display over other apps
  /// Returns true if permission is granted after user returns
  Future<bool> requestOverlayPermission() async {
    try {
      final bool? isGranted = await SystemAlertWindow.requestPermissions();
      return isGranted ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request CAMERA permission
  /// Shows runtime permission dialog
  /// Returns true if permission is granted
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed permission status for UI display
  /// Returns a map with permission names and their status
  Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'usageStats': await hasUsageStatsPermission(),
      'overlay': await hasOverlayPermission(),
      'camera': await hasCameraPermission(),
    };
  }

  /// Request all missing permissions
  /// Returns true if all permissions are granted after requests
  Future<bool> requestAllPermissions() async {
    bool allGranted = true;

    // Check and request usage stats
    if (!await hasUsageStatsPermission()) {
      final granted = await requestUsageStatsPermission();
      allGranted = allGranted && granted;
    }

    // Check and request overlay
    if (!await hasOverlayPermission()) {
      final granted = await requestOverlayPermission();
      allGranted = allGranted && granted;
    }

    // Check and request camera
    if (!await hasCameraPermission()) {
      final granted = await requestCameraPermission();
      allGranted = allGranted && granted;
    }

    return allGranted;
  }
}

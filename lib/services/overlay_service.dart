import 'package:system_alert_window/system_alert_window.dart';
import 'package:flutter/material.dart';

/// Service for managing system alert window overlay
/// Handles showing/hiding full-screen exercise challenge overlay
class OverlayService {
  // Singleton pattern
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  // Track overlay state
  bool _isOverlayShown = false;

  /// Check if overlay is currently shown
  bool get isOverlayShown => _isOverlayShown;

  /// Request SYSTEM_ALERT_WINDOW permission
  /// Opens system settings for user to grant permission
  static Future<bool> requestPermission() async {
    try {
      final bool? result = await SystemAlertWindow.requestPermissions();
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Check if SYSTEM_ALERT_WINDOW permission is granted
  static Future<bool> checkPermission() async {
    try {
      final bool? result = await SystemAlertWindow.checkPermissions();
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Show full-screen exercise challenge overlay
  /// Blocks access to underlying app until exercise is completed
  Future<void> showExerciseChallenge() async {
    try {
      // Check permission first
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('Overlay permission not granted');
        return;
      }

      // Configure overlay as full-screen with OVERLAY prefMode
      await SystemAlertWindow.showSystemWindow(
        height: SystemAlertWindow.fullScreenHeight,
        width: SystemAlertWindow.fullScreenWidth,
        gravity: SystemWindowGravity.CENTER,
        notificationTitle: "Complete Exercise to Continue",
        notificationBody: "Time limit reached. Complete your exercise challenge.",
        prefMode: SystemWindowPrefMode.OVERLAY,
      );

      _isOverlayShown = true;
      debugPrint('Exercise challenge overlay shown');
    } catch (e) {
      debugPrint('Error showing exercise challenge overlay: $e');
      _isOverlayShown = false;
    }
  }

  /// Close the overlay window
  /// Should only be called after exercise is successfully completed
  Future<void> closeOverlay() async {
    try {
      await SystemAlertWindow.closeSystemWindow();
      _isOverlayShown = false;
      debugPrint('Overlay closed');
    } catch (e) {
      debugPrint('Error closing overlay: $e');
    }
  }

  /// Check if overlay is currently shown
  /// Useful for monitoring if user dismissed overlay externally
  Future<bool> isOverlayActive() async {
    try {
      // The package doesn't provide a direct way to check if overlay is shown
      // We rely on our internal state tracking
      return _isOverlayShown;
    } catch (e) {
      debugPrint('Error checking overlay state: $e');
      return false;
    }
  }

  /// Update overlay state manually
  /// Used when overlay is dismissed or closed externally
  void setOverlayState(bool isShown) {
    _isOverlayShown = isShown;
  }
}

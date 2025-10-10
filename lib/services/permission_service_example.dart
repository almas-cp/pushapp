// Example usage of PermissionService
// This file demonstrates how to use the PermissionService in your app

import 'permission_service.dart';

/// Example: Check all permissions before enabling monitoring
Future<void> exampleCheckAllPermissions() async {
  final permissionService = PermissionService();
  
  final allGranted = await permissionService.checkAllPermissions();
  
  if (allGranted) {
    print('All permissions granted - can enable monitoring');
  } else {
    print('Some permissions missing - need to request');
  }
}

/// Example: Request all missing permissions
Future<void> exampleRequestPermissions() async {
  final permissionService = PermissionService();
  
  final allGranted = await permissionService.requestAllPermissions();
  
  if (allGranted) {
    print('All permissions granted successfully');
  } else {
    print('Some permissions were denied');
  }
}

/// Example: Check individual permission status
Future<void> exampleCheckIndividualPermissions() async {
  final permissionService = PermissionService();
  
  final hasUsageStats = await permissionService.hasUsageStatsPermission();
  final hasOverlay = await permissionService.hasOverlayPermission();
  final hasCamera = await permissionService.hasCameraPermission();
  
  print('Usage Stats: $hasUsageStats');
  print('Overlay: $hasOverlay');
  print('Camera: $hasCamera');
}

/// Example: Get detailed permission status for UI
Future<void> exampleGetPermissionStatus() async {
  final permissionService = PermissionService();
  
  final status = await permissionService.getPermissionStatus();
  
  status.forEach((permission, isGranted) {
    print('$permission: ${isGranted ? "✓ Granted" : "✗ Denied"}');
  });
}

/// Example: Request specific permission
Future<void> exampleRequestCameraPermission() async {
  final permissionService = PermissionService();
  
  if (!await permissionService.hasCameraPermission()) {
    final granted = await permissionService.requestCameraPermission();
    
    if (granted) {
      print('Camera permission granted');
    } else {
      print('Camera permission denied');
    }
  }
}

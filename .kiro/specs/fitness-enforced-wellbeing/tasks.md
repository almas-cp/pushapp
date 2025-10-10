# Implementation Plan

- [x] 1. Setup project dependencies and Android configuration





  - Add all required dependencies to pubspec.yaml (google_mlkit_pose_detection, app_usage, system_alert_window, flutter_foreground_task, camera, shared_preferences)
  - Configure AndroidManifest.xml with all required permissions (SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE, FOREGROUND_SERVICE_CAMERA, WAKE_LOCK, CAMERA, PACKAGE_USAGE_STATS, POST_NOTIFICATIONS, USE_FULL_SCREEN_INTENT)
  - Create custom Application.kt class in android/app/src/main/kotlin directory
  - Add foreground service declaration with camera type in AndroidManifest.xml
  - Set android:name=".Application" in application tag
  - Update build.gradle with minSdkVersion 21 and targetSdkVersion 34
  - _Requirements: 10.1, 10.2, 10.6, 10.7_

- [x] 2. Create data models and constants






  - [x] 2.1 Implement ExerciseSettings model with JSON serialization

    - Create lib/models/exercise_settings.dart with ExerciseType enum
    - Add fields: monitoredApps, usageTimeLimitMinutes, rewardTimeMinutes, exerciseType, repCount, isMonitoringEnabled
    - Implement toJson() and fromJson() methods
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6_
  

  - [x] 2.2 Implement AppUsageModel with usage tracking fields

    - Create lib/models/app_usage_model.dart
    - Add fields: packageName, appName, todayUsage, totalUsage, lastUsed
    - Implement JSON serialization methods
    - _Requirements: 3.4, 8.3_
  
  - [x] 2.3 Implement ExerciseStats model for tracking completions


    - Create lib/models/exercise_stats.dart
    - Add fields: todayCompletions, totalCompletions, lastExerciseDate, exerciseBreakdown
    - Implement incrementCompletion() and resetDailyStats() methods
    - Implement JSON serialization
    - _Requirements: 8.1, 8.2, 8.5, 8.6_
  
  - [x] 2.4 Implement MonitoringState model for service state


    - Create lib/models/monitoring_state.dart
    - Add fields: currentSessionUsage, rewardTimeExpiry, isOverlayActive, currentMonitoredApp
    - Implement isInRewardPeriod() and shouldTriggerIntervention() methods
    - Implement JSON serialization
    - _Requirements: 3.4, 7.4, 7.5_
  

  - [x] 2.5 Create constants file with social media package names

    - Create lib/utils/constants.dart
    - Define common social media app package names (Instagram, TikTok, Facebook, Twitter, Snapchat, etc.)
    - Define time limit options, reward time options, rep count options
    - Define angle thresholds for exercises
    - _Requirements: 1.3, 1.4, 1.6_

- [x] 3. Implement storage layer with SharedPreferences





  - Create lib/utils/storage_helper.dart with StorageHelper class
  - Implement loadSettings() and saveSettings() for ExerciseSettings
  - Implement loadStats() and saveStats() for ExerciseStats
  - Implement loadUsageData() and saveUsageData() for app usage
  - Implement loadState() and saveState() for MonitoringState
  - Add error handling for storage failures with in-memory fallback
  - _Requirements: 1.2, 3.9, 8.7, 9.8_

- [x] 4. Create permission service for centralized permission management





  - Create lib/services/permission_service.dart
  - Implement checkAllPermissions() to verify all required permissions
  - Implement hasUsageStatsPermission() using AppUsage package
  - Implement hasOverlayPermission() using system_alert_window package
  - Implement hasCameraPermission() using permission_handler or camera package
  - Implement requestUsageStatsPermission() to open Settings -> Usage access
  - Implement requestOverlayPermission() to open Settings -> Display over other apps
  - Implement requestCameraPermission() for runtime permission
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

- [x] 5. Implement angle calculator utility for pose geometry





  - Create lib/utils/angle_calculator.dart
  - Implement calculateAngle(Point a, Point b, Point c) using arctangent formula
  - Implement calculateDistance(Point a, Point b) for Euclidean distance
  - Implement isAligned(List<Point> points, double threshold) for alignment checking
  - _Requirements: 6.3, 6.4, 6.5, 6.6_

- [x] 6. Build exercise counter implementations




  - [x] 6.1 Create base ExerciseCounter abstract class

    - Create lib/pose_detection/exercise_counter.dart
    - Define abstract interface with currentReps, isInCorrectForm, processPose(), reset()
    - _Requirements: 5.5, 5.6, 5.7, 5.8, 6.7_
  


  - [x] 6.2 Implement JumpingJackCounter with state machine
    - Create lib/pose_detection/jumping_jack_counter.dart extending ExerciseCounter
    - Implement state machine (NEUTRAL, EXTENDED, RETURNING)
    - Implement processPose() to check shoulder Y position vs nose Y position
    - Check ankle distance for legs spread detection
    - Count rep on complete cycle (neutral -> extended -> neutral)
    - _Requirements: 5.5, 6.1, 6.2, 6.7_

  

  - [x] 6.3 Implement SquatCounter with angle calculation
    - Create lib/pose_detection/squat_counter.dart extending ExerciseCounter
    - Implement state machine (STANDING, DESCENDING, BOTTOM, ASCENDING)
    - Calculate hip-knee-ankle angle using AngleCalculator
    - Detect down position when angle < 90°
    - Detect up position when angle > 160°
    - Count rep on complete down->up cycle
    - _Requirements: 5.6, 6.3, 6.4, 6.7_

  

  - [x] 6.4 Implement PushUpCounter with shoulder-elbow-wrist angle
    - Create lib/pose_detection/pushup_counter.dart extending ExerciseCounter
    - Implement state machine similar to SquatCounter
    - Calculate shoulder-elbow-wrist angle
    - Verify horizontal body position
    - Detect down position when angle < 90°
    - Detect up position when angle > 160°
    - Count rep on complete cycle
    - _Requirements: 5.7, 6.5, 6.6, 6.7_

  

  - [x] 6.5 Implement PlankCounter with duration tracking

    - Create lib/pose_detection/plank_counter.dart extending ExerciseCounter
    - Implement validatePlankPosition() to check shoulder-hip-knee alignment
    - Track elapsed time only when position is correct
    - Pause timer if position breaks
    - Complete when target duration reached
    - _Requirements: 5.8, 5.9, 6.8_

- [x] 7. Create pose painter for landmark visualization




  - Create lib/pose_detection/pose_painter.dart extending CustomPainter
  - Implement paint() method to draw landmarks as colored circles
  - Implement drawConnection() to draw skeleton lines between landmarks
  - Add confidence indicators for landmarks
  - Add visual feedback for correct/incorrect form
  - _Requirements: 5.3, 5.11_

- [x] 8. Implement pose detector view with camera integration





  - Create lib/pose_detection/pose_detector_view.dart as StatefulWidget
  - Implement initializeCamera() with front camera and medium resolution
  - Configure ML Kit PoseDetector with stream mode and accurate model
  - Implement startImageStream() to process camera frames
  - Implement processImage() to convert CameraImage to InputImage
  - Implement onPoseDetected() callback to handle pose results
  - Check InFrameLikelihood > 0.5 to ensure user is visible
  - Display warning when user not properly visible
  - Integrate PosePainter to visualize landmarks
  - Implement proper dispose() to cleanup camera and detector
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.10_

- [x] 9. Build settings screen UI and logic




  - [x] 9.1 Create SettingsScreen widget with state management


    - Create lib/screens/settings_screen.dart as StatefulWidget
    - Initialize state variables for all settings (selectedApps, usageTimeLimit, rewardTime, exerciseType, repCount, isMonitoringEnabled)
    - Implement initState() to load settings from storage
    - _Requirements: 1.1, 1.2_
  
  - [x] 9.2 Implement app selector with installed apps detection


    - Implement loadInstalledApps() to query device for installed apps
    - Filter for common social media apps using package name matching
    - Create multi-select list UI with checkboxes
    - Update selectedApps state on selection changes
    - _Requirements: 1.1, 1.2_
  
  - [x] 9.3 Add time limit and reward time selectors


    - Create dropdown or slider for usage time limit (5, 10, 15, 30 minutes)
    - Create dropdown or slider for reward time (2, 5, 10 minutes)
    - Update state on changes
    - _Requirements: 1.3, 1.4_
  
  - [x] 9.4 Add exercise type and rep count selectors


    - Create exercise type picker (Jumping Jacks, Squats, Push-ups, Planks)
    - Create rep count selector (10, 15, 20, 25, 30 for exercises; 30, 60, 90 seconds for planks)
    - Conditionally show rep count vs duration based on exercise type
    - _Requirements: 1.5, 1.6_
  
  - [x] 9.5 Implement permission validation and monitoring toggle


    - Add permission status indicators showing granted/denied state
    - Implement validatePermissions() using PermissionService
    - Add monitoring toggle switch
    - Disable toggle if permissions not granted
    - Show permission request dialogs with clear instructions
    - Implement toggleMonitoring() to start/stop foreground service
    - _Requirements: 1.7, 2.6, 2.7, 2.8_
  
  - [x] 9.6 Implement settings persistence and service updates


    - Implement saveSettings() to persist all settings using StorageHelper
    - Call saveSettings() whenever settings change
    - Implement updateServiceConfig() to send new settings to running foreground service
    - _Requirements: 1.2, 1.8_

- [x] 10. Implement usage monitor service





  - Create lib/services/usage_monitor_service.dart
  - Initialize state variables (monitoredApps, usageStartTime, cumulativeUsage, rewardTimeExpiry, usageTimeLimit, rewardDuration)
  - Implement checkCurrentApp() using AppUsage to query foreground app
  - Implement updateUsageTime() to increment cumulative usage counter
  - Implement isLimitExceeded() to check if intervention needed
  - Implement isInRewardPeriod() to check active reward time
  - Implement resetUsageTimer() to clear usage after exercise
  - Implement grantRewardTime() to set reward period expiry
  - Implement persistUsageData() to save usage to storage
  - Add logic to handle multiple monitored apps
  - _Requirements: 3.3, 3.4, 3.5, 7.2, 7.4, 7.5, 7.6, 7.7, 9.3_

- [x] 11. Implement overlay service for system alert window





  - Create lib/services/overlay_service.dart
  - Implement showExerciseChallenge() using SystemAlertWindow.showSystemWindow()
  - Configure overlay as full-screen with OVERLAY prefMode
  - Set notification title and body for overlay
  - Implement closeOverlay() using SystemAlertWindow.closeSystemWindow()
  - Implement isOverlayShown() to check current overlay state
  - Implement requestPermission() to request SYSTEM_ALERT_WINDOW permission
  - _Requirements: 4.1, 4.2, 4.7_

- [x] 12. Create foreground service with flutter_foreground_task




  - [x] 12.1 Implement TaskHandler for foreground service


    - Create lib/services/foreground_service.dart
    - Create MyTaskHandler extending TaskHandler
    - Implement onStart() to initialize service and load settings
    - Implement onRepeatEvent() to run every 5 seconds
    - In onRepeatEvent(), call UsageMonitorService.checkCurrentApp()
    - Check if overlay should be shown and reopen if dismissed externally
    - Implement onDestroy() for cleanup
    - Implement onNotificationPressed() to open app
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 4.6, 9.4_
  
  - [x] 12.2 Configure foreground service options and notification


    - Configure FlutterForegroundTaskOptions with 5-second interval
    - Set autoRunOnBoot to true for auto-restart
    - Set allowWakeLock to true
    - Create notification with title "Monitoring Active" and appropriate icon
    - _Requirements: 3.1, 3.2, 3.6_
  
  - [x] 12.3 Implement service start/stop methods


    - Implement startMonitoringService() to initialize and start foreground task
    - Implement stopMonitoringService() to stop foreground task and clear notification
    - Add auto-restart logic if service is killed
    - _Requirements: 3.1, 3.7, 3.8, 9.4_

- [x] 13. Build exercise overlay screen







  - Create lib/screens/exercise_overlay_screen.dart as StatefulWidget
  - Initialize state variables (exerciseType, targetReps, currentReps, isExercising, showSuccessAnimation)
  - Load exercise settings from storage in initState()
  - Create UI with exercise name, instructions, and "Start Exercise" button
  - Implement startExercise() to initialize camera and pose detection
  - Integrate PoseDetectorView widget
  - Create appropriate ExerciseCounter based on exerciseType
  - Implement onRepCompleted() callback to update rep counter display
  - Implement onExerciseComplete() to show success animation
  - Implement closeOverlay() to dismiss overlay and call OverlayService.closeOverlay()
  - Update ExerciseStats and grant reward time on completion
  - Display rep counter or timer based on exercise type
  - _Requirements: 4.3, 4.4, 4.5, 4.7, 4.8, 5.1, 5.10, 7.1, 7.3, 8.5_

- [x] 14. Create dashboard screen with statistics





  - Create lib/screens/dashboard_screen.dart as StatefulWidget
  - Initialize state variables (todayExerciseCount, totalExerciseCount, monitoredAppsUsage, timeSaved)
  - Implement loadStatistics() to fetch data from StorageHelper
  - Implement calculateTimeSaved() to compute reduction in social media time
  - Implement refreshData() to update UI with latest statistics
  - Create UI cards for today's exercise completions
  - Create UI cards for all-time exercise completions
  - Display per-app usage breakdown with app names and durations
  - Display time saved metric
  - Add pull-to-refresh functionality
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 15. Implement main app structure and navigation





  - Update lib/main.dart with MaterialApp configuration
  - Create bottom navigation bar with Dashboard and Settings tabs
  - Set up navigation between DashboardScreen and SettingsScreen
  - Initialize FlutterForegroundTask in main()
  - Request initial permissions on first launch
  - Set up app theme and styling
  - _Requirements: 1.1, 2.1_

- [ ] 16. Add error handling and edge case management
  - [ ] 16.1 Implement phone call interruption handling
    - Listen to phone state changes in ExerciseOverlayScreen
    - Pause exercise timer/counter when call received
    - Keep overlay visible but inactive during call
    - Resume exercise when call ends
    - _Requirements: 9.1_
  
  - [ ] 16.2 Implement camera error handling
    - Add try-catch in camera initialization
    - Display error dialog if camera permission denied
    - Show retry button if camera initialization fails
    - Guide user to grant camera permission
    - _Requirements: 5.12, 9.6_
  
  - [ ] 16.3 Implement overlay dismissal prevention
    - Monitor overlay state in foreground service onRepeatEvent()
    - Detect if overlay was dismissed externally
    - Immediately reopen overlay if dismissed without completion
    - _Requirements: 4.4, 4.6, 9.5_
  
  - [ ] 16.4 Implement service crash recovery
    - Configure auto-restart in FlutterForegroundTaskOptions
    - Persist monitoring state before potential crashes
    - Restore state on service restart
    - _Requirements: 3.7, 9.4_
  
  - [ ] 16.5 Handle uninstalled monitored apps
    - Check if monitored apps still installed on service start
    - Remove uninstalled apps from monitoredApps list
    - Update settings in storage
    - _Requirements: 9.2_
  
  - [ ] 16.6 Implement storage error handling
    - Add try-catch in all StorageHelper methods
    - Implement in-memory fallback cache if storage fails
    - Display warning to user if settings cannot be saved
    - _Requirements: 9.8_

- [ ] 17. Add visual feedback and animations
  - Implement success animation in ExerciseOverlayScreen using Lottie or custom animation
  - Add visual feedback for correct/incorrect form in PosePainter
  - Add haptic feedback on rep completion
  - Add sound effects for rep counting (optional)
  - Implement smooth transitions between screens
  - Add loading indicators during camera initialization
  - _Requirements: 5.10, 5.11, 7.3_

- [ ] 18. Optimize performance and battery usage
  - Ensure camera resources are released when not exercising
  - Dispose ML Kit detector properly
  - Limit stored usage history to last 30 days
  - Implement periodic cleanup of old statistics
  - Optimize pose detection frame processing rate
  - Test battery impact and adjust check interval if needed
  - _Requirements: 3.3, 9.7_

- [ ] 19. Final integration and testing
  - Test complete flow: settings -> monitoring -> overlay -> exercise -> reward
  - Test all exercise types (Jumping Jacks, Squats, Push-ups, Planks)
  - Test permission flows for all required permissions
  - Test service restart after device reboot
  - Test with multiple social media apps
  - Test edge cases (phone calls, camera failures, overlay dismissal)
  - Verify statistics tracking accuracy
  - Test on different Android versions (API 21-34)
  - Test on different device sizes and camera qualities
  - _Requirements: All_

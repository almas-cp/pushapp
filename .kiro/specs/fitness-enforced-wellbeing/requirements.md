# Requirements Document

## Introduction

This document outlines the requirements for a Flutter Android application that combines pose detection exercise tracking with social media usage control. The app monitors designated social media applications, enforces time limits, and requires users to complete physical exercises (detected via ML-powered pose recognition) before granting continued access. This creates a fitness-enforced digital wellbeing system that encourages physical activity while managing screen time.

## Requirements

### Requirement 1: App Configuration and Settings Management

**User Story:** As a user, I want to configure which social media apps to monitor and set usage limits, so that I can customize the app's behavior to match my digital wellbeing goals.

#### Acceptance Criteria

1. WHEN the user opens the settings screen THEN the system SHALL display a list of installed social media apps with multi-select capability
2. WHEN the user selects target apps THEN the system SHALL persist the selection using shared_preferences
3. WHEN the user adjusts the usage time limit THEN the system SHALL provide options for 5, 10, 15, or 30 minutes
4. WHEN the user sets the reward time THEN the system SHALL provide options for 2, 5, or 10 minutes
5. WHEN the user selects an exercise type THEN the system SHALL offer Jumping Jacks, Squats, Push-ups, or Planks
6. WHEN the user sets rep count THEN the system SHALL provide options for 10, 15, 20, 25, or 30 reps for exercises, and 30, 60, or 90 seconds for planks
7. WHEN the user enables monitoring THEN the system SHALL validate all required permissions before starting the service
8. WHEN settings are modified THEN the system SHALL immediately update the running foreground service with new parameters

### Requirement 2: Permission Management

**User Story:** As a user, I want clear guidance on granting necessary permissions, so that I understand why each permission is needed and can enable them correctly.

#### Acceptance Criteria

1. WHEN the app first launches THEN the system SHALL check for PACKAGE_USAGE_STATS permission
2. IF PACKAGE_USAGE_STATS is not granted THEN the system SHALL display instructions and open Settings -> Special app access -> Usage access
3. WHEN the app requires overlay capability THEN the system SHALL check for SYSTEM_ALERT_WINDOW permission
4. IF SYSTEM_ALERT_WINDOW is not granted THEN the system SHALL display instructions and open Settings -> Display over other apps
5. WHEN exercise detection is needed THEN the system SHALL request CAMERA permission at runtime
6. IF any required permission is denied THEN the system SHALL prevent service activation and display clear error messages
7. WHEN all permissions are granted THEN the system SHALL enable the monitoring service toggle
8. WHEN the user attempts to enable monitoring without permissions THEN the system SHALL guide them through the permission granting process

### Requirement 3: Background App Usage Monitoring

**User Story:** As a user, I want the app to continuously monitor my social media usage in the background, so that time limits are enforced even when I'm not actively thinking about them.

#### Acceptance Criteria

1. WHEN monitoring is enabled THEN the system SHALL start a persistent foreground service using flutter_foreground_task
2. WHEN the foreground service is running THEN the system SHALL display a persistent notification indicating active monitoring
3. WHEN the service is active THEN the system SHALL check the current foreground app every 5 seconds using app_usage
4. IF a monitored social media app is detected THEN the system SHALL increment the cumulative usage time counter
5. WHEN cumulative usage time exceeds the configured limit THEN the system SHALL trigger the overlay intervention
6. WHEN the device reboots THEN the system SHALL optionally auto-restart the monitoring service
7. IF the service is killed by the system THEN the system SHALL attempt to auto-restart
8. WHEN monitoring is disabled THEN the system SHALL stop the foreground service and clear the notification
9. WHEN usage data is updated THEN the system SHALL persist it using shared_preferences

### Requirement 4: Full-Screen Overlay Intervention

**User Story:** As a user, I want the app to block my access to social media when I exceed my time limit, so that I'm forced to take a break and exercise.

#### Acceptance Criteria

1. WHEN usage limit is exceeded THEN the system SHALL immediately display a full-screen overlay using system_alert_window
2. WHEN the overlay is shown THEN the system SHALL completely block access to the underlying social media app
3. WHEN the overlay appears THEN the system SHALL display the exercise name, target reps/duration, and a "Start Exercise" button
4. IF the user attempts to dismiss the overlay THEN the system SHALL prevent dismissal without exercise completion
5. WHEN the overlay is active THEN the system SHALL show a timer or counter display
6. IF the user closes the overlay externally THEN the system SHALL immediately reopen it
7. WHEN the exercise is completed successfully THEN the system SHALL automatically close the overlay
8. WHEN the overlay closes THEN the system SHALL grant reward time access and reset the usage timer

### Requirement 5: Real-Time Pose Detection and Exercise Tracking

**User Story:** As a user, I want the app to accurately detect and count my exercise repetitions using my phone's camera, so that I can complete the required exercises to regain app access.

#### Acceptance Criteria

1. WHEN the user starts an exercise THEN the system SHALL activate the camera with full-screen view
2. WHEN the camera is active THEN the system SHALL process frames using google_mlkit_pose_detection in stream mode
3. WHEN pose landmarks are detected THEN the system SHALL visualize them as an overlay on the camera feed
4. IF InFrameLikelihood is less than 0.5 THEN the system SHALL display a warning that the user is not properly visible
5. WHEN performing Jumping Jacks THEN the system SHALL count a rep when arms raise above shoulders AND legs spread, then return to neutral
6. WHEN performing Squats THEN the system SHALL count a rep when hip-knee-ankle angle drops below 90° then returns above 160°
7. WHEN performing Push-ups THEN the system SHALL count a rep when shoulder-elbow-wrist angle drops below 90° then returns above 160°
8. WHEN performing Planks THEN the system SHALL verify proper position (shoulders-hips-knees aligned) and count duration only when position is correct
9. IF plank position breaks THEN the system SHALL pause the timer until position is corrected
10. WHEN the target rep count or duration is reached THEN the system SHALL display a success celebration
11. WHEN exercise validation fails (poor form) THEN the system SHALL provide visual/audio feedback
12. IF camera permission is denied during exercise THEN the system SHALL display an error and guide the user to grant permission

### Requirement 6: Exercise-Specific Validation and Counting Logic

**User Story:** As a user, I want the app to ensure I'm performing exercises with proper form, so that I get genuine physical activity rather than gaming the system.

#### Acceptance Criteria

1. WHEN counting Jumping Jacks THEN the system SHALL verify shoulder Y position is above nose Y position for arms up state
2. WHEN counting Jumping Jacks THEN the system SHALL verify ankle distance exceeds threshold for legs spread state
3. WHEN counting Squats THEN the system SHALL calculate hip-knee-ankle angle using arctangent formula
4. WHEN counting Squats THEN the system SHALL require angle below 90° for valid down position
5. WHEN counting Push-ups THEN the system SHALL calculate shoulder-elbow-wrist angle
6. WHEN counting Push-ups THEN the system SHALL require angle below 90° for valid down position
7. WHEN counting any rep-based exercise THEN the system SHALL implement state machine to prevent double counting
8. WHEN validating Planks THEN the system SHALL verify body angle alignment within acceptable range
9. IF form is incorrect THEN the system SHALL not count the repetition
10. WHEN landmarks are not detected THEN the system SHALL pause counting until user is back in frame

### Requirement 7: Access Management and Reward System

**User Story:** As a user, I want to receive temporary access to social media after completing exercises, so that I'm rewarded for my physical activity.

#### Acceptance Criteria

1. WHEN exercise is completed successfully THEN the system SHALL close the overlay within 2 seconds
2. WHEN overlay closes THEN the system SHALL grant the configured reward time (2, 5, or 10 minutes)
3. WHEN reward time is granted THEN the system SHALL display a brief success message or animation
4. WHEN reward time is active THEN the system SHALL start a new usage timer for monitored apps
5. WHEN reward time expires THEN the system SHALL reset to monitoring mode
6. IF the user opens a monitored app during reward time THEN the system SHALL allow access without intervention
7. WHEN reward time ends and user continues using monitored app THEN the system SHALL begin tracking toward next time limit
8. WHEN access is granted THEN the system SHALL return to background monitoring mode

### Requirement 8: Statistics Dashboard and Progress Tracking

**User Story:** As a user, I want to view my exercise completion statistics and usage patterns, so that I can track my progress and understand my digital wellbeing habits.

#### Acceptance Criteria

1. WHEN the user opens the dashboard THEN the system SHALL display today's exercise completion count
2. WHEN the dashboard loads THEN the system SHALL display total all-time exercise completions
3. WHEN the dashboard is visible THEN the system SHALL show usage statistics for each monitored app
4. WHEN displaying statistics THEN the system SHALL calculate and show estimated time saved/reduced from social media
5. WHEN exercises are completed THEN the system SHALL update statistics in real-time
6. WHEN the date changes THEN the system SHALL reset daily counters while preserving all-time totals
7. WHEN statistics are updated THEN the system SHALL persist data using shared_preferences

### Requirement 9: Edge Case Handling and Reliability

**User Story:** As a user, I want the app to handle interruptions and edge cases gracefully, so that the monitoring system remains reliable and doesn't interfere with important phone functions.

#### Acceptance Criteria

1. IF a phone call is received during exercise THEN the system SHALL pause the exercise and resume after the call ends
2. IF the user uninstalls a monitored app THEN the system SHALL remove it from the monitoring list automatically
3. IF multiple monitored apps are opened in quick succession THEN the system SHALL track cumulative time across all of them
4. IF the foreground service is killed by the system THEN the system SHALL auto-restart within 30 seconds
5. WHEN the user force-closes the overlay THEN the system SHALL reopen it immediately
6. IF camera fails during exercise THEN the system SHALL display error message and allow retry
7. WHEN battery saver mode is active THEN the system SHALL continue monitoring with reduced check frequency
8. IF storage is full THEN the system SHALL handle shared_preferences write failures gracefully

### Requirement 10: Android Platform Integration

**User Story:** As a developer, I want the app to properly integrate with Android system services and permissions, so that it functions reliably across different Android versions.

#### Acceptance Criteria

1. WHEN the app is built THEN the system SHALL target Android SDK minimum 21 (Lollipop) and above
2. WHEN running on Android 14+ (API 34) THEN the system SHALL declare foreground service type as "camera"
3. WHEN the foreground service starts THEN the system SHALL display a notification as required by Android
4. WHEN permissions are requested THEN the system SHALL follow Android permission best practices
5. IF running on Android 10+ THEN the system SHALL handle background location restrictions appropriately
6. WHEN the app is installed THEN the system SHALL declare all required permissions in AndroidManifest.xml
7. WHEN the custom Application class is needed THEN the system SHALL be properly registered in AndroidManifest.xml
8. WHEN using system alert window THEN the system SHALL comply with Android overlay restrictions

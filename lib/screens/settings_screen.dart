import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../models/exercise_settings.dart';
import '../utils/storage_helper.dart';
import '../utils/constants.dart';
import '../services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // State variables for all settings
  List<String> selectedApps = [];
  int usageTimeLimit = TimeLimitOptions.defaultValue;
  int rewardTime = RewardTimeOptions.defaultValue;
  ExerciseType exerciseType = ExerciseType.jumpingJacks;
  int repCount = RepCountOptions.defaultReps;
  bool isMonitoringEnabled = false;

  // Loading state
  bool isLoading = true;

  // Available apps (filtered social media apps)
  List<Map<String, String>> availableApps = [];

  // Permission status
  Map<String, bool> permissionStatus = {
    'usageStats': false,
    'overlay': false,
    'camera': false,
  };

  // Permission service
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadInstalledApps();
    _validatePermissions();
  }

  /// Load settings from storage on initialization
  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final settings = await StorageHelper.loadSettings();
      
      if (settings != null) {
        setState(() {
          selectedApps = List<String>.from(settings.monitoredApps);
          usageTimeLimit = settings.usageTimeLimitMinutes;
          rewardTime = settings.rewardTimeMinutes;
          exerciseType = settings.exerciseType;
          repCount = settings.repCount;
          isMonitoringEnabled = settings.isMonitoringEnabled;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Load installed apps and filter for social media apps
  Future<void> _loadInstalledApps() async {
    try {
      // Get all installed apps
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      // Filter for social media apps based on package names
      final filteredApps = apps.where((app) {
        return SocialMediaApps.allPackageNames.contains(app.packageName);
      }).toList();

      setState(() {
        availableApps = filteredApps.map((app) {
          return {
            'packageName': app.packageName,
            'appName': app.appName,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading installed apps: $e');
      // Fallback: show all known social media apps even if not installed
      setState(() {
        availableApps = SocialMediaApps.allPackageNames.map((packageName) {
          return {
            'packageName': packageName,
            'appName': _getAppNameFromPackage(packageName),
          };
        }).toList();
      });
    }
  }

  /// Helper to get app name from package name
  String _getAppNameFromPackage(String packageName) {
    switch (packageName) {
      case SocialMediaApps.instagram:
        return 'Instagram';
      case SocialMediaApps.tiktok:
        return 'TikTok';
      case SocialMediaApps.facebook:
        return 'Facebook';
      case SocialMediaApps.twitter:
        return 'Twitter';
      case SocialMediaApps.snapchat:
        return 'Snapchat';
      case SocialMediaApps.youtube:
        return 'YouTube';
      case SocialMediaApps.reddit:
        return 'Reddit';
      case SocialMediaApps.whatsapp:
        return 'WhatsApp';
      case SocialMediaApps.telegram:
        return 'Telegram';
      case SocialMediaApps.pinterest:
        return 'Pinterest';
      case SocialMediaApps.linkedin:
        return 'LinkedIn';
      case SocialMediaApps.tumblr:
        return 'Tumblr';
      default:
        return packageName;
    }
  }

  /// Toggle app selection
  void _toggleAppSelection(String packageName) {
    setState(() {
      if (selectedApps.contains(packageName)) {
        selectedApps.remove(packageName);
      } else {
        selectedApps.add(packageName);
      }
    });
    _saveSettings();
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      final settings = ExerciseSettings(
        monitoredApps: selectedApps,
        usageTimeLimitMinutes: usageTimeLimit,
        rewardTimeMinutes: rewardTime,
        exerciseType: exerciseType,
        repCount: repCount,
        isMonitoringEnabled: isMonitoringEnabled,
      );

      final success = await StorageHelper.saveSettings(settings);

      if (!success) {
        // Settings saved to in-memory cache but not to persistent storage
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Settings saved to memory only. Changes may be lost.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // Update service configuration if monitoring is active
      if (isMonitoringEnabled) {
        await _updateServiceConfig();
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  /// Update running foreground service with new settings
  Future<void> _updateServiceConfig() async {
    // TODO: Send new settings to foreground service
    // This will be implemented in task 12 when the foreground service is created
    // For now, we just log that the service would be updated
    print('Service config would be updated with new settings');
  }

  /// Validate all required permissions
  Future<void> _validatePermissions() async {
    try {
      final status = await _permissionService.getPermissionStatus();
      setState(() {
        permissionStatus = status;
      });
    } catch (e) {
      print('Error validating permissions: $e');
    }
  }

  /// Check if all permissions are granted
  bool _allPermissionsGranted() {
    return permissionStatus.values.every((granted) => granted);
  }

  /// Toggle monitoring service
  Future<void> _toggleMonitoring(bool value) async {
    if (value) {
      // Check permissions before enabling
      if (!_allPermissionsGranted()) {
        _showPermissionDialog();
        return;
      }

      // Check if at least one app is selected
      if (selectedApps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one app to monitor'),
          ),
        );
        return;
      }

      // TODO: Start foreground service (will be implemented in task 12)
      setState(() {
        isMonitoringEnabled = true;
      });
      await _saveSettings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitoring started')),
      );
    } else {
      // TODO: Stop foreground service (will be implemented in task 12)
      setState(() {
        isMonitoringEnabled = false;
      });
      await _saveSettings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitoring stopped')),
      );
    }
  }

  /// Show permission request dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following permissions are required:'),
            const SizedBox(height: 16),
            _buildPermissionItem(
              'Usage Stats',
              permissionStatus['usageStats'] ?? false,
              'Required to monitor app usage',
            ),
            _buildPermissionItem(
              'Display Over Other Apps',
              permissionStatus['overlay'] ?? false,
              'Required to show exercise overlay',
            ),
            _buildPermissionItem(
              'Camera',
              permissionStatus['camera'] ?? false,
              'Required for pose detection',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermissions();
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  /// Build permission item for dialog
  Widget _buildPermissionItem(String name, bool granted, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Request all missing permissions
  Future<void> _requestPermissions() async {
    // Request usage stats permission
    if (!permissionStatus['usageStats']!) {
      await _permissionService.requestUsageStatsPermission();
    }

    // Request overlay permission
    if (!permissionStatus['overlay']!) {
      await _permissionService.requestOverlayPermission();
    }

    // Request camera permission
    if (!permissionStatus['camera']!) {
      await _permissionService.requestCameraPermission();
    }

    // Revalidate permissions
    await _validatePermissions();

    if (_allPermissionsGranted()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All permissions granted')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some permissions are still missing. Please grant them in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAppSelector(),
          const SizedBox(height: 24),
          _buildTimeLimitSelector(),
          const SizedBox(height: 24),
          _buildRewardTimeSelector(),
          const SizedBox(height: 24),
          _buildExerciseTypeSelector(),
          const SizedBox(height: 24),
          _buildRepCountSelector(),
          const SizedBox(height: 24),
          _buildPermissionStatus(),
          const SizedBox(height: 24),
          _buildMonitoringToggle(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build time limit selector section
  Widget _buildTimeLimitSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Time Limit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Time allowed before exercise is required',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: usageTimeLimit,
              decoration: const InputDecoration(
                labelText: 'Time Limit',
                border: OutlineInputBorder(),
                suffixText: 'minutes',
              ),
              items: TimeLimitOptions.values.map((minutes) {
                return DropdownMenuItem<int>(
                  value: minutes,
                  child: Text('$minutes minutes'),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    usageTimeLimit = value;
                  });
                  _saveSettings();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build reward time selector section
  Widget _buildRewardTimeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reward Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Time granted after completing exercise',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: rewardTime,
              decoration: const InputDecoration(
                labelText: 'Reward Time',
                border: OutlineInputBorder(),
                suffixText: 'minutes',
              ),
              items: RewardTimeOptions.values.map((minutes) {
                return DropdownMenuItem<int>(
                  value: minutes,
                  child: Text('$minutes minutes'),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    rewardTime = value;
                  });
                  _saveSettings();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build exercise type selector section
  Widget _buildExerciseTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the exercise to perform',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ExerciseType>(
              value: exerciseType,
              decoration: const InputDecoration(
                labelText: 'Exercise',
                border: OutlineInputBorder(),
              ),
              items: ExerciseType.values.map((type) {
                return DropdownMenuItem<ExerciseType>(
                  value: type,
                  child: Text(_getExerciseTypeName(type)),
                );
              }).toList(),
              onChanged: (ExerciseType? value) {
                if (value != null) {
                  setState(() {
                    exerciseType = value;
                    // Both exercises are rep-based
                    repCount = RepCountOptions.defaultReps;
                  });
                  _saveSettings();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build rep count selector section
  Widget _buildRepCountSelector() {
    final isPlank = exerciseType == ExerciseType.planks;
    final options = isPlank
        ? RepCountOptions.plankDurations
        : RepCountOptions.repBasedExercises;
    final label = isPlank ? 'Duration' : 'Repetitions';
    final suffix = isPlank ? 'seconds' : 'reps';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isPlank
                  ? 'How long to hold the plank'
                  : 'Number of repetitions required',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: options.contains(repCount) ? repCount : options.first,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixText: suffix,
              ),
              items: options.map((count) {
                return DropdownMenuItem<int>(
                  value: count,
                  child: Text('$count $suffix'),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    repCount = value;
                  });
                  _saveSettings();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to get exercise type display name
  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.squats:
        return 'Squats';
      case ExerciseType.headNods:
        return 'Head Nods';
    }
  }

  /// Build permission status section
  Widget _buildPermissionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _validatePermissions,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'All permissions must be granted to enable monitoring',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            _buildPermissionStatusItem(
              'Usage Stats',
              permissionStatus['usageStats'] ?? false,
              'Monitor which apps are being used',
            ),
            _buildPermissionStatusItem(
              'Display Over Other Apps',
              permissionStatus['overlay'] ?? false,
              'Show exercise overlay when limit reached',
            ),
            _buildPermissionStatusItem(
              'Camera',
              permissionStatus['camera'] ?? false,
              'Detect exercise movements',
            ),
            const SizedBox(height: 16),
            if (!_allPermissionsGranted())
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Permissions'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build individual permission status item
  Widget _buildPermissionStatusItem(String name, bool granted, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build monitoring toggle section
  Widget _buildMonitoringToggle() {
    final canEnable = _allPermissionsGranted() && selectedApps.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monitoring Service',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isMonitoringEnabled
                  ? 'Service is actively monitoring your app usage'
                  : 'Enable to start monitoring',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                isMonitoringEnabled ? 'Monitoring Active' : 'Monitoring Inactive',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                canEnable || isMonitoringEnabled
                    ? 'Toggle to start/stop monitoring'
                    : 'Grant permissions and select apps first',
              ),
              value: isMonitoringEnabled,
              onChanged: canEnable || isMonitoringEnabled
                  ? _toggleMonitoring
                  : null,
            ),
            if (!canEnable && !isMonitoringEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please grant all permissions and select at least one app to enable monitoring',
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build app selector section
  Widget _buildAppSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monitored Apps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Select social media apps to monitor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            if (availableApps.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No social media apps found'),
                ),
              )
            else
              ...availableApps.map((app) {
                final packageName = app['packageName']!;
                final appName = app['appName']!;
                final isSelected = selectedApps.contains(packageName);

                return CheckboxListTile(
                  title: Text(appName),
                  subtitle: Text(
                    packageName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    _toggleAppSelection(packageName);
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

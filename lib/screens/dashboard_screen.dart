import 'package:flutter/material.dart';
import '../models/exercise_stats.dart';
import '../models/app_usage_model.dart';
import '../models/exercise_settings.dart';
import '../utils/storage_helper.dart';
import 'test_exercise_screen.dart';
import 'camera_test_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // State variables
  int todayExerciseCount = 0;
  int totalExerciseCount = 0;
  Map<String, Duration> monitoredAppsUsage = {};
  Duration timeSaved = Duration.zero;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  /// Load statistics from storage
  Future<void> loadStatistics() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load exercise stats
      final stats = await StorageHelper.loadStats();
      if (stats != null) {
        todayExerciseCount = stats.todayCompletions;
        totalExerciseCount = stats.totalCompletions;
      }

      // Load app usage data
      final usageList = await StorageHelper.loadUsageData();
      monitoredAppsUsage = {};
      for (final usage in usageList) {
        monitoredAppsUsage[usage.appName] = usage.todayUsage;
      }

      // Calculate time saved
      timeSaved = await calculateTimeSaved();
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Calculate time saved based on exercise completions and reward time
  Future<Duration> calculateTimeSaved() async {
    try {
      final settings = await StorageHelper.loadSettings();
      final stats = await StorageHelper.loadStats();

      if (settings == null || stats == null) {
        return Duration.zero;
      }

      // Calculate total time that would have been spent without intervention
      // Each exercise completion represents a time limit period that was interrupted
      final timeLimitMinutes = settings.usageTimeLimitMinutes;
      final rewardMinutes = settings.rewardTimeMinutes;

      // Time saved = (time limit - reward time) * number of completions
      final savedPerCompletion = timeLimitMinutes - rewardMinutes;
      final totalSavedMinutes = savedPerCompletion * stats.todayCompletions;

      return Duration(minutes: totalSavedMinutes.clamp(0, double.infinity).toInt());
    } catch (e) {
      print('Error calculating time saved: $e');
      return Duration.zero;
    }
  }

  /// Refresh data with pull-to-refresh
  Future<void> refreshData() async {
    await loadStatistics();
  }

  /// Format duration to readable string
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Test Exercise button
                  _buildTestExerciseButton(),
                  const SizedBox(height: 12),
                  
                  // Camera Test button
                  _buildCameraTestButton(),
                  const SizedBox(height: 16),

                  // Today's exercise completions card
                  _buildStatCard(
                    title: "Today's Exercises",
                    value: todayExerciseCount.toString(),
                    icon: Icons.fitness_center,
                    color: Colors.blue,
                    subtitle: 'Completed today',
                  ),
                  const SizedBox(height: 16),

                  // All-time exercise completions card
                  _buildStatCard(
                    title: 'Total Exercises',
                    value: totalExerciseCount.toString(),
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                    subtitle: 'All-time completions',
                  ),
                  const SizedBox(height: 16),

                  // Time saved card
                  _buildStatCard(
                    title: 'Time Saved Today',
                    value: formatDuration(timeSaved),
                    icon: Icons.timer_off,
                    color: Colors.green,
                    subtitle: 'Reduced social media time',
                  ),
                  const SizedBox(height: 24),

                  // App usage breakdown section
                  if (monitoredAppsUsage.isNotEmpty) ...[
                    const Text(
                      'App Usage Today',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAppUsageList(),
                  ] else ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No app usage data yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start monitoring to see statistics',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  /// Build test exercise button
  Widget _buildTestExerciseButton() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TestExerciseScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade400,
                Colors.purple.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Exercise',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Test camera and pose detection',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build camera test button
  Widget _buildCameraTestButton() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraTestScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400,
                Colors.cyan.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camera Preview Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Compare different rendering options',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a statistics card widget
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the app usage list widget
  Widget _buildAppUsageList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: monitoredAppsUsage.entries.map((entry) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(
                Icons.apps,
                color: Colors.purple,
              ),
            ),
            title: Text(
              entry.key,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              formatDuration(entry.value),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

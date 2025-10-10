import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'services/permission_service.dart';

// TaskHandler callback must be a top-level function
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

// TaskHandler implementation
class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Will be implemented in task 12
    print('Task started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Will be implemented in task 12
    print('Task repeat event at $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Will be implemented in task 12
    print('Task destroyed at $timestamp (timeout: $isTimeout)');
  }
}

void main() {
  // Initialize port for communication between TaskHandler and UI
  FlutterForegroundTask.initCommunicationPort();
  
  // Initialize FlutterForegroundTask
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'fitness_wellbeing_channel',
      channelName: 'Fitness Wellbeing Monitoring',
      channelDescription: 'Monitors app usage and enforces exercise breaks',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Wellbeing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _hasRequestedPermissions = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
  }

  /// Request initial permissions on first launch
  Future<void> _requestInitialPermissions() async {
    // Check if this is the first launch
    if (_hasRequestedPermissions) {
      return;
    }

    // Wait for the first frame to be rendered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final permissionService = PermissionService();
      final status = await permissionService.getPermissionStatus();

      // Check if any permissions are missing
      final hasAllPermissions = status.values.every((granted) => granted);

      if (!hasAllPermissions && mounted) {
        _showInitialPermissionDialog();
      }

      setState(() {
        _hasRequestedPermissions = true;
      });
    });
  }

  /// Show initial permission dialog on first launch
  void _showInitialPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Fitness Wellbeing'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app helps you maintain a healthy balance between social media usage and physical activity.',
            ),
            SizedBox(height: 16),
            Text(
              'To get started, we need to request some permissions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Usage Stats - Monitor app usage'),
            Text('• Display Over Apps - Show exercise overlay'),
            Text('• Camera - Detect exercise movements'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to settings screen to grant permissions
              setState(() {
                _currentIndex = 1;
              });
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

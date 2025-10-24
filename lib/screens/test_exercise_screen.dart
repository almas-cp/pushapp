import 'package:flutter/material.dart';
import '../models/exercise_settings.dart';
import '../utils/storage_helper.dart';
import '../pose_detection/pose_detector_view.dart';
import '../pose_detection/exercise_counter.dart';
import '../pose_detection/squat_counter.dart';
import '../pose_detection/head_nod_counter.dart';
import '../services/permission_service.dart';

/// Test exercise screen for debugging and verifying camera/pose detection
/// 
/// This screen allows users to test exercise detection without triggering
/// the actual monitoring system. Useful for:
/// - Verifying camera works correctly
/// - Testing pose detection accuracy
/// - Debugging exercise counters
/// - Checking camera permissions
class TestExerciseScreen extends StatefulWidget {
  const TestExerciseScreen({Key? key}) : super(key: key);

  @override
  State<TestExerciseScreen> createState() => _TestExerciseScreenState();
}

class _TestExerciseScreenState extends State<TestExerciseScreen> {
  // State variables
  ExerciseType _selectedExerciseType = ExerciseType.pushUps;
  int _targetReps = 10;
  int _currentReps = 0;
  bool _isExercising = false;
  bool _showSuccessMessage = false;
  ExerciseCounter? _exerciseCounter;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasPermissions = false;
  
  // Debug info
  String _debugInfo = 'Waiting for camera...';
  int _framesProcessed = 0;
  int _poseDetections = 0;
  int _errors = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadExerciseSettings();
  }

  /// Check if camera permission is granted
  Future<void> _checkPermissions() async {
    final permissionService = PermissionService();
    final hasCameraPermission = await permissionService.hasCameraPermission();
    
    setState(() {
      _hasPermissions = hasCameraPermission;
    });
  }

  /// Request camera permission
  Future<void> _requestPermission() async {
    final permissionService = PermissionService();
    final granted = await permissionService.requestCameraPermission();
    
    setState(() {
      _hasPermissions = granted;
    });

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to test exercises'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Load exercise settings from storage
  Future<void> _loadExerciseSettings() async {
    try {
      final settings = await StorageHelper.loadSettings();
      
      if (settings != null) {
        setState(() {
          _selectedExerciseType = settings.exerciseType;
          _targetReps = settings.repCount;
          _isLoading = false;
        });
      } else {
        // Use default settings if none found
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load exercise settings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Get exercise name as display string
  String _getExerciseName(ExerciseType type) {
    switch (type) {
      case ExerciseType.squats:
        return 'Squats';
      case ExerciseType.headNods:
        return 'Head Nods';
    }
  }

  /// Get exercise instructions
  String _getExerciseInstructions(ExerciseType type) {
    switch (type) {
      case ExerciseType.squats:
        return 'Stand straight, then lower your body by bending your knees. Stand back up to complete a rep. Your hip movement is tracked vertically.';
      case ExerciseType.headNods:
        return 'Move your head from side to side (left or right) and return to center. Each side movement counts as one rep.';
    }
  }

  /// Check if exercise is duration-based or rep-based (all are rep-based now)
  bool _isDurationBased() {
    return false; // Both exercises are now rep-based
  }

  /// Start the exercise and initialize camera/pose detection
  void _startExercise() {
    if (!_hasPermissions) {
      _requestPermission();
      return;
    }

    setState(() {
      _isExercising = true;
      _currentReps = 0;
      _showSuccessMessage = false;
      
      // Create appropriate exercise counter based on exercise type
      _exerciseCounter = _createExerciseCounter();
    });
  }

  /// Stop the exercise
  void _stopExercise() {
    setState(() {
      _isExercising = false;
      _exerciseCounter = null;
      _currentReps = 0;
    });
  }

  /// Create the appropriate exercise counter for the selected exercise type
  ExerciseCounter _createExerciseCounter() {
    switch (_selectedExerciseType) {
      case ExerciseType.squats:
        return SquatCounter();
      case ExerciseType.headNods:
        return HeadNodCounter();
    }
  }

  /// Callback invoked when a rep is completed
  void _onRepCompleted() {
    if (_exerciseCounter == null) return;
    
    setState(() {
      _currentReps = _exerciseCounter!.currentReps;
    });

    // Check if exercise is complete
    if (_isDurationBased()) {
      // For planks, check if target duration reached
      final plankCounter = _exerciseCounter as PlankCounter;
      if (plankCounter.isComplete) {
        _onExerciseComplete();
      }
    } else {
      // For rep-based exercises, check if target reps reached
      if (_currentReps >= _targetReps) {
        _onExerciseComplete();
      }
    }
  }

  /// Handle exercise completion
  void _onExerciseComplete() {
    setState(() {
      _showSuccessMessage = true;
    });

    // Auto-hide success message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccessMessage = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Exercise'),
        actions: [
          if (_isExercising)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopExercise,
              tooltip: 'Stop Exercise',
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _errorMessage != null
                ? _buildErrorView()
                : !_hasPermissions
                    ? _buildPermissionView()
                    : _isExercising
                        ? _buildExerciseView()
                        : _buildStartView(),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }

  /// Build error view
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _loadExerciseSettings();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build permission request view
  Widget _buildPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To test exercise detection, we need access to your camera to track your movements.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Grant Camera Permission'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build start view (before exercise begins)
  Widget _buildStartView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Test Exercise Detection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Test your camera and pose detection without affecting your stats',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Exercise type selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Exercise Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExerciseType.values.map((type) {
                      return ChoiceChip(
                        label: Text(_getExerciseName(type)),
                        selected: _selectedExerciseType == type,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedExerciseType = type;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Target reps selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDurationBased() ? 'Duration (seconds)' : 'Target Reps',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_targetReps > 5) {
                            setState(() {
                              _targetReps -= 5;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 32,
                      ),
                      Expanded(
                        child: Text(
                          '$_targetReps',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _targetReps += 5;
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 32,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Instructions
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to perform',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getExerciseInstructions(_selectedExerciseType),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Start button
          ElevatedButton(
            onPressed: _startExercise,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, size: 28),
                SizedBox(width: 8),
                Text(
                  'Start Test',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build exercise view (during exercise)
  Widget _buildExerciseView() {
    return Stack(
      children: [
        // Camera and pose detection view
        if (_exerciseCounter != null)
          PoseDetectorView(
            exerciseCounter: _exerciseCounter,
            onPoseDetected: (pose) {
              // Update rep count on each pose detection
              _onRepCompleted();
            },
            onDebugInfo: (info) {
              // Update debug info
              if (mounted) {
                setState(() {
                  _debugInfo = info;
                });
              }
            },
          ),
        
        // Rep counter overlay
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: _buildRepCounter(),
        ),
        
        // Debug overlay at bottom
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: _buildDebugOverlay(),
        ),
        
        // Success message overlay
        if (_showSuccessMessage)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildSuccessMessage(),
          ),
      ],
    );
  }
  
  /// Build debug overlay
  Widget _buildDebugOverlay() {
    // Get state info from exercise counter if available
    String stateInfo = '';
    String thresholdInfo = '';
    
    if (_exerciseCounter != null) {
      final counter = _exerciseCounter as dynamic;
      try {
        if (_selectedExerciseType == ExerciseType.headNods) {
          stateInfo = '\n📍 State: ${counter.currentState}';
          thresholdInfo = '⬅️ Left: -8° | ➡️ Right: +8° | ⬆️ Center: ±4°';
        } else if (_selectedExerciseType == ExerciseType.squats) {
          stateInfo = '\n📍 State: ${counter.currentState} | ${counter.movementInfo}';
          thresholdInfo = '🔽 Down: 80px | 🔼 Up: 40px | Vertical motion tracking';
        }
      } catch (e) {
        // Ignore if getters not available
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔍 ML Kit Debug Info:',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _debugInfo + stateInfo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
          if (thresholdInfo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              thresholdInfo,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build rep counter display
  Widget _buildRepCounter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _exerciseCounter?.isInCorrectForm ?? false
              ? Colors.green
              : Colors.orange,
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TEST MODE',
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getExerciseName(_selectedExerciseType),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Display counter based on exercise type
          if (_isDurationBased())
            _buildDurationCounter()
          else
            _buildRepCountDisplay(),
          
          const SizedBox(height: 8),
          
          // Form indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _exerciseCounter?.isInCorrectForm ?? false
                    ? Icons.check_circle
                    : Icons.warning,
                color: _exerciseCounter?.isInCorrectForm ?? false
                    ? Colors.green
                    : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _exerciseCounter?.isInCorrectForm ?? false
                    ? 'Good Form'
                    : 'Adjust Position',
                style: TextStyle(
                  color: _exerciseCounter?.isInCorrectForm ?? false
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build rep count display for rep-based exercises
  Widget _buildRepCountDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$_currentReps',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          ' / $_targetReps',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 32,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build duration counter for plank exercise
  Widget _buildDurationCounter() {
    final plankCounter = _exerciseCounter as PlankCounter?;
    final remaining = plankCounter?.remainingSeconds ?? _targetReps;
    
    return Column(
      children: [
        Text(
          '$remaining',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'seconds remaining',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Build success message
  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 32,
          ),
          SizedBox(width: 12),
          Text(
            'Target Reached!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


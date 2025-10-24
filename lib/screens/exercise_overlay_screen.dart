import 'package:flutter/material.dart';
import '../models/exercise_settings.dart';
import '../models/exercise_stats.dart';
import '../utils/storage_helper.dart';
import '../services/overlay_service.dart';
import '../pose_detection/pose_detector_view.dart';
import '../pose_detection/exercise_counter.dart';
import '../pose_detection/jumping_jack_counter.dart';
import '../pose_detection/squat_counter.dart';
import '../pose_detection/pushup_counter.dart';
import '../pose_detection/plank_counter.dart';
import '../pose_detection/head_nod_counter.dart';
import '../services/usage_monitor_service.dart';

/// Full-screen exercise overlay screen shown when usage limit is exceeded
/// 
/// This screen:
/// - Displays exercise challenge information
/// - Integrates camera and pose detection
/// - Tracks exercise progress (reps or duration)
/// - Shows success animation on completion
/// - Grants reward time and closes overlay when exercise is complete
class ExerciseOverlayScreen extends StatefulWidget {
  const ExerciseOverlayScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseOverlayScreen> createState() => _ExerciseOverlayScreenState();
}

class _ExerciseOverlayScreenState extends State<ExerciseOverlayScreen>
    with SingleTickerProviderStateMixin {
  // State variables
  ExerciseType _exerciseType = ExerciseType.jumpingJacks;
  int _targetReps = 20;
  int _currentReps = 0;
  bool _isExercising = false;
  bool _showSuccessAnimation = false;
  ExerciseCounter? _exerciseCounter;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Animation controller for success animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadExerciseSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Initialize success animation
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  /// Load exercise settings from storage
  Future<void> _loadExerciseSettings() async {
    try {
      final settings = await StorageHelper.loadSettings();
      
      if (settings != null) {
        setState(() {
          _exerciseType = settings.exerciseType;
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
  String _getExerciseName() {
    switch (_exerciseType) {
      case ExerciseType.jumpingJacks:
        return 'Jumping Jacks';
      case ExerciseType.squats:
        return 'Squats';
      case ExerciseType.pushUps:
        return 'Push-ups';
      case ExerciseType.planks:
        return 'Plank';
      case ExerciseType.headNods:
        return 'Head Nods';
    }
  }

  /// Get exercise instructions
  String _getExerciseInstructions() {
    switch (_exerciseType) {
      case ExerciseType.jumpingJacks:
        return 'Jump with arms up and legs spread, then return to starting position';
      case ExerciseType.squats:
        return 'Lower your body until your thighs are parallel to the ground, then stand back up';
      case ExerciseType.pushUps:
        return 'Lower your body until your chest nearly touches the ground, then push back up';
      case ExerciseType.planks:
        return 'Hold a straight body position with forearms on the ground';
      case ExerciseType.headNods:
        return 'Move your head from side to side (left-center-right) as if saying "no"';
    }
  }

  /// Check if exercise is duration-based (plank) or rep-based
  bool _isDurationBased() {
    return _exerciseType == ExerciseType.planks;
  }

  /// Start the exercise and initialize camera/pose detection
  void _startExercise() {
    setState(() {
      _isExercising = true;
      _currentReps = 0;
      
      // Create appropriate exercise counter based on exercise type
      _exerciseCounter = _createExerciseCounter();
    });
  }

  /// Create the appropriate exercise counter for the selected exercise type
  ExerciseCounter _createExerciseCounter() {
    switch (_exerciseType) {
      case ExerciseType.jumpingJacks:
        return JumpingJackCounter();
      case ExerciseType.squats:
        return SquatCounter();
      case ExerciseType.pushUps:
        return PushUpCounter();
      case ExerciseType.planks:
        return PlankCounter(targetDurationSeconds: _targetReps);
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
  Future<void> _onExerciseComplete() async {
    // Show success animation
    setState(() {
      _showSuccessAnimation = true;
    });
    
    _animationController.forward();

    // Update exercise stats
    await _updateExerciseStats();

    // Grant reward time
    await _grantRewardTime();

    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 2));

    // Close overlay
    await _closeOverlay();
  }

  /// Update exercise statistics
  Future<void> _updateExerciseStats() async {
    try {
      // Load current stats
      ExerciseStats stats = await StorageHelper.loadStats() ?? ExerciseStats(
        todayCompletions: 0,
        totalCompletions: 0,
        lastExerciseDate: DateTime.now(),
        exerciseBreakdown: {},
      );

      // Check if we need to reset daily stats (new day)
      final now = DateTime.now();
      final lastDate = stats.lastExerciseDate;
      if (now.year != lastDate.year || 
          now.month != lastDate.month || 
          now.day != lastDate.day) {
        stats = stats.resetDailyStats();
      }

      // Increment completion for this exercise type
      stats = stats.withIncrementedCompletion(_exerciseType);

      // Save updated stats
      await StorageHelper.saveStats(stats);
    } catch (e) {
      debugPrint('Error updating exercise stats: $e');
    }
  }

  /// Grant reward time to the user
  Future<void> _grantRewardTime() async {
    try {
      // Load settings to get reward time duration
      final settings = await StorageHelper.loadSettings();
      if (settings != null) {
        final rewardMinutes = settings.rewardTimeMinutes;
        
        // Grant reward time through usage monitor service
        await UsageMonitorService.grantRewardTime(Duration(minutes: rewardMinutes));
      }
    } catch (e) {
      debugPrint('Error granting reward time: $e');
    }
  }

  /// Close the overlay and return to monitored app
  Future<void> _closeOverlay() async {
    try {
      await OverlayService().closeOverlay();
      
      // If this screen is in a navigation context, pop it
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error closing overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _errorMessage != null
                ? _buildErrorView()
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
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading exercise...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
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

  /// Build start view (before exercise begins)
  Widget _buildStartView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade900,
            Colors.purple.shade900,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Time Limit Reached!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Exercise name
              Text(
                'Complete ${_targetReps} ${_getExerciseName()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getExerciseInstructions(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Start button
              ElevatedButton(
                onPressed: _startExercise,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'Start Exercise',
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
        ),
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
          ),
        
        // Rep counter overlay
        if (!_showSuccessAnimation)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: _buildRepCounter(),
          ),
        
        // Success animation overlay
        if (_showSuccessAnimation)
          _buildSuccessAnimation(),
      ],
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
          Text(
            _getExerciseName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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

  /// Build success animation
  Widget _buildSuccessAnimation() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Exercise Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enjoy your reward time',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

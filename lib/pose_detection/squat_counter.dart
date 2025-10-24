import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';

/// State machine states for Squat exercises
enum _SquatState {
  standing,   // Legs extended
  bottom,     // Squatting position
}

/// Counter for Squat exercises
/// 
/// Uses a state machine to track the exercise progression based on VERTICAL MOTION:
/// - STANDING: Hip at high position (starting height)
/// - BOTTOM: Hip moved down significantly (squatting)
/// 
/// A rep is counted when the user completes a full cycle: STANDING -> BOTTOM -> STANDING
/// 
/// Detection method:
/// - Tracks the Y coordinate of the hip (lower Y = higher position, higher Y = lower position)
/// - Calibrates starting position on first detection
/// - Detects squat when hip moves down by threshold amount
class SquatCounter extends ExerciseCounter {
  _SquatState _state = _SquatState.standing;
  int _reps = 0;
  bool _correctForm = true; // Start with true to avoid immediate warnings
  
  // Vertical position tracking
  double? _standingHipY; // Reference Y position when standing
  double _currentHipY = 0.0;
  double _minHipY = double.infinity; // Highest position seen
  double _maxHipY = double.negativeInfinity; // Lowest position seen
  
  @override
  int get currentReps => _reps;
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  /// Get current state for debugging
  String get currentState => _state.toString().split('.').last.toUpperCase();
  
  /// Get current hip position for debugging
  double get currentHipY => _currentHipY;
  
  /// Get movement range for debugging
  String get movementInfo {
    if (_standingHipY == null) return 'Calibrating...';
    final movement = _currentHipY - _standingHipY!;
    return 'Movement: ${movement.toStringAsFixed(0)}px';
  }
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get hip landmarks (average of both hips for stability)
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    
    // Check if required landmarks are detected
    if (leftHip == null || rightHip == null) {
      _correctForm = false;
      return;
    }
    
    // Calculate average hip Y position (lower Y = higher in frame, higher Y = lower in frame)
    _currentHipY = (leftHip.y + rightHip.y) / 2;
    
    // Calibrate standing position on first few frames
    if (_standingHipY == null) {
      _standingHipY = _currentHipY;
      _minHipY = _currentHipY;
      _maxHipY = _currentHipY;
      _correctForm = true;
      return;
    }
    
    // Update range tracking
    if (_currentHipY < _minHipY) _minHipY = _currentHipY;
    if (_currentHipY > _maxHipY) _maxHipY = _currentHipY;
    
    // Calculate downward movement from standing position
    // Positive value means hip moved down (squatting)
    final movementDown = _currentHipY - _standingHipY!;
    
    // Threshold for squat detection (adjust based on testing)
    // This is relative to image height, typical squat moves hip ~80-150 pixels
    const double squatDownThreshold = 80.0; // pixels down from standing
    const double squatUpThreshold = 40.0;   // pixels up from bottom to count as standing
    
    // Debug output
    print('Squat Y: ${_currentHipY.toStringAsFixed(0)} | Movement: ${movementDown.toStringAsFixed(0)}px | State: $_state');
    
    // State machine logic based on vertical movement
    switch (_state) {
      case _SquatState.standing:
        if (movementDown > squatDownThreshold) {
          // Hip moved down significantly - transition to bottom
          _state = _SquatState.bottom;
          _correctForm = true;
          print('⬇️ Squatting down...');
        } else {
          // Good form if staying near standing height
          _correctForm = movementDown.abs() < squatUpThreshold;
        }
        break;
        
      case _SquatState.bottom:
        if (movementDown < squatUpThreshold) {
          // Hip returned to standing height - complete rep!
          _reps++;
          _state = _SquatState.standing;
          _correctForm = true;
          print('✅ Squat Rep completed! Total: $_reps');
          
          // Recalibrate standing position for next rep
          _standingHipY = _currentHipY;
        } else {
          // Good form if staying in squat position
          _correctForm = movementDown > squatDownThreshold * 0.7;
        }
        break;
    }
  }
  
  @override
  void reset() {
    _state = _SquatState.standing;
    _reps = 0;
    _correctForm = false;
    _standingHipY = null;
    _currentHipY = 0.0;
    _minHipY = double.infinity;
    _maxHipY = double.negativeInfinity;
  }
}

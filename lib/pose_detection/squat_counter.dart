import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/constants.dart';
import '../utils/angle_calculator.dart';
import 'dart:math';

/// Counter for Squat exercises
/// 
/// Uses a state machine to track the exercise progression:
/// - STANDING: Legs extended, hip-knee-ankle angle > 160°
/// - DESCENDING: Transitioning down (optional state for smoother tracking)
/// - BOTTOM: Squatting position, hip-knee-ankle angle < 90°
/// - ASCENDING: Transitioning up (optional state for smoother tracking)
/// 
/// A rep is counted when the user completes a full cycle: STANDING -> BOTTOM -> STANDING
class SquatCounter extends ExerciseCounter {
  /// State machine states
  enum _State {
    standing,   // Legs extended
    bottom,     // Squatting position
  }
  
  _State _state = _State.standing;
  int _reps = 0;
  bool _correctForm = false;
  
  @override
  int get currentReps => _reps;
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get required landmarks (using left side for consistency)
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    
    // Also get right side for validation
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    
    // Check if all required landmarks are detected
    if (leftHip == null || leftKnee == null || leftAnkle == null ||
        rightHip == null || rightKnee == null || rightAnkle == null) {
      _correctForm = false;
      return;
    }
    
    // Check InFrameLikelihood
    if (pose.likelihood != null && pose.likelihood! < ExerciseThresholds.minInFrameLikelihood) {
      _correctForm = false;
      return;
    }
    
    // Calculate hip-knee-ankle angle for both legs
    final leftAngle = AngleCalculator.calculateAngle(
      Point(leftHip.x, leftHip.y),
      Point(leftKnee.x, leftKnee.y),
      Point(leftAnkle.x, leftAnkle.y),
    );
    
    final rightAngle = AngleCalculator.calculateAngle(
      Point(rightHip.x, rightHip.y),
      Point(rightKnee.x, rightKnee.y),
      Point(rightAnkle.x, rightAnkle.y),
    );
    
    // Use average of both legs for more stable detection
    final avgAngle = (leftAngle + rightAngle) / 2;
    
    // State machine logic
    switch (_state) {
      case _State.standing:
        if (avgAngle < ExerciseThresholds.squatDownAngle) {
          // Transition to bottom position
          _state = _State.bottom;
          _correctForm = true;
        } else {
          // Correct form in standing is legs extended
          _correctForm = avgAngle > ExerciseThresholds.squatUpAngle;
        }
        break;
        
      case _State.bottom:
        if (avgAngle > ExerciseThresholds.squatUpAngle) {
          // Complete rep: returned to standing
          _reps++;
          _state = _State.standing;
          _correctForm = true;
        } else {
          // Correct form in bottom is deep squat
          _correctForm = avgAngle < ExerciseThresholds.squatDownAngle;
        }
        break;
    }
  }
  
  @override
  void reset() {
    _state = _State.standing;
    _reps = 0;
    _correctForm = false;
  }
}

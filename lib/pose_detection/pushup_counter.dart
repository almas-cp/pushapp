import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/constants.dart';
import '../utils/angle_calculator.dart';
import 'dart:math';

/// State machine states for Push-up exercises
enum _PushUpState {
  up,     // Arms extended
  down,   // Bottom of push-up
}

/// Counter for Push-up exercises
/// 
/// Uses a state machine to track the exercise progression:
/// - UP: Arms extended, shoulder-elbow-wrist angle > 160°
/// - DOWN: Push-up bottom position, shoulder-elbow-wrist angle < 90°
/// 
/// A rep is counted when the user completes a full cycle: UP -> DOWN -> UP
/// 
/// Also validates horizontal body position to ensure proper push-up form
class PushUpCounter extends ExerciseCounter {
  _PushUpState _state = _PushUpState.up;
  int _reps = 0;
  bool _correctForm = true; // Start with true to avoid immediate warnings
  
  @override
  int get currentReps => _reps;
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get required landmarks (using left side for consistency)
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    
    // Also get right side for validation
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    
    // Get body landmarks for horizontal position validation
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    
    // Check if all required landmarks are detected
    if (leftShoulder == null || leftElbow == null || leftWrist == null ||
        rightShoulder == null || rightElbow == null || rightWrist == null ||
        leftHip == null || rightHip == null) {
      _correctForm = false;
      return;
    }
    
    // Calculate shoulder-elbow-wrist angle for both arms
    final leftAngle = AngleCalculator.calculateAngle(
      Point(leftShoulder.x, leftShoulder.y),
      Point(leftElbow.x, leftElbow.y),
      Point(leftWrist.x, leftWrist.y),
    );
    
    final rightAngle = AngleCalculator.calculateAngle(
      Point(rightShoulder.x, rightShoulder.y),
      Point(rightElbow.x, rightElbow.y),
      Point(rightWrist.x, rightWrist.y),
    );
    
    // Use average of both arms for more stable detection
    final avgAngle = (leftAngle + rightAngle) / 2;
    
    // Verify horizontal body position (shoulders and hips should be roughly aligned)
    // Calculate the vertical distance between shoulders and hips
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final avgHipY = (leftHip.y + rightHip.y) / 2;
    final bodyVerticalDistance = (avgHipY - avgShoulderY).abs();
    
    // Calculate shoulder width as reference
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    
    // Body should be relatively horizontal (vertical distance less than shoulder width)
    final isHorizontal = bodyVerticalDistance < shoulderWidth * 0.8;
    
    // State machine logic
    switch (_state) {
      case _PushUpState.up:
        if (avgAngle < ExerciseThresholds.pushUpDownAngle && isHorizontal) {
          // Transition to down position
          _state = _PushUpState.down;
          _correctForm = true;
        } else {
          // Correct form in up position is arms extended and horizontal body
          _correctForm = avgAngle > ExerciseThresholds.pushUpUpAngle && isHorizontal;
        }
        break;
        
      case _PushUpState.down:
        if (avgAngle > ExerciseThresholds.pushUpUpAngle && isHorizontal) {
          // Complete rep: returned to up position
          _reps++;
          _state = _PushUpState.up;
          _correctForm = true;
        } else {
          // Correct form in down position is bent arms and horizontal body
          _correctForm = avgAngle < ExerciseThresholds.pushUpDownAngle && isHorizontal;
        }
        break;
    }
  }
  
  @override
  void reset() {
    _state = _PushUpState.up;
    _reps = 0;
    _correctForm = false;
  }
}

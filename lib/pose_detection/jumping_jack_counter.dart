import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/constants.dart';
import '../utils/angle_calculator.dart';
import 'dart:math';

/// State machine states for Jumping Jack exercises
enum _JumpingJackState {
  neutral,    // Arms down, legs together
  extended,   // Arms up, legs spread
}

/// Counter for Jumping Jack exercises
/// 
/// Uses a state machine to track the exercise progression:
/// - NEUTRAL: Arms down, legs together (starting position)
/// - EXTENDED: Arms up above shoulders, legs spread
/// - RETURNING: Transitioning back to neutral (not currently used but reserved for future)
/// 
/// A rep is counted when the user completes a full cycle: NEUTRAL -> EXTENDED -> NEUTRAL
class JumpingJackCounter extends ExerciseCounter {
  _JumpingJackState _state = _JumpingJackState.neutral;
  int _reps = 0;
  bool _correctForm = true; // Start with true to avoid immediate warnings
  
  @override
  int get currentReps => _reps;
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get required landmarks
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final nose = landmarks[PoseLandmarkType.nose];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    
    // Check if all required landmarks are detected with sufficient confidence
    if (leftShoulder == null || rightShoulder == null || nose == null ||
        leftAnkle == null || rightAnkle == null) {
      _correctForm = false;
      return;
    }
    
    // Check if arms are up (shoulders above nose level)
    final armsUp = (leftShoulder.y < nose.y) && (rightShoulder.y < nose.y);
    
    // Calculate ankle distance for legs spread detection
    final ankleDistance = (leftAnkle.x - rightAnkle.x).abs();
    
    // Calculate shoulder width as reference
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    
    // Legs are spread if ankle distance exceeds threshold relative to shoulder width
    final legsSpread = ankleDistance > (shoulderWidth * (1 + ExerciseThresholds.jumpingJackSpreadThreshold));
    
    // State machine logic
    switch (_state) {
      case _JumpingJackState.neutral:
        if (armsUp && legsSpread) {
          // Transition to extended state
          _state = _JumpingJackState.extended;
          _correctForm = true;
        } else {
          _correctForm = !armsUp && !legsSpread; // Correct form in neutral is arms down, legs together
        }
        break;
        
      case _JumpingJackState.extended:
        if (!armsUp && !legsSpread) {
          // Complete rep: returned to neutral
          _reps++;
          _state = _JumpingJackState.neutral;
          _correctForm = true;
        } else {
          _correctForm = armsUp && legsSpread; // Correct form in extended is arms up, legs spread
        }
        break;
    }
  }
  
  @override
  void reset() {
    _state = _JumpingJackState.neutral;
    _reps = 0;
    _correctForm = false;
  }
}

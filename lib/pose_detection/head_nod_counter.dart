import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/constants.dart';
import 'dart:math';

/// State machine states for Head Nod exercises
enum _HeadNodState {
  center,   // Head facing forward/center
  left,     // Head turned to the left
  right,    // Head turned to the right
}

/// Counter for Head Nod exercises
/// 
/// Tracks horizontal head movement (side to side, like saying "no").
/// Uses nose and ear landmarks to detect head rotation.
/// 
/// Detection logic:
/// - Calculates the horizontal distance between left ear and right ear
/// - Compares nose position relative to the midpoint between ears
/// - A rep is counted when: CENTER -> LEFT or CENTER -> RIGHT
/// - Each movement to an extreme counts, even if repeating the same side
/// 
/// This simulates the "head nod" (side to side) movement pattern.
class HeadNodCounter extends ExerciseCounter {
  _HeadNodState _state = _HeadNodState.center;
  int _reps = 0;
  bool _correctForm = true; // Start with true to avoid immediate warnings
  
  @override
  int get currentReps => _reps;
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  /// Get current state for debugging
  String get currentState => _state.toString().split('.').last.toUpperCase();
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get required landmarks for head tracking
    final nose = landmarks[PoseLandmarkType.nose];
    final leftEar = landmarks[PoseLandmarkType.leftEar];
    final rightEar = landmarks[PoseLandmarkType.rightEar];
    final leftEye = landmarks[PoseLandmarkType.leftEye];
    final rightEye = landmarks[PoseLandmarkType.rightEye];
    
    // Check if all required landmarks are detected
    if (nose == null || leftEar == null || rightEar == null ||
        leftEye == null || rightEye == null) {
      _correctForm = false;
      return;
    }
    
    // Calculate head rotation using ear and nose positions
    final headRotation = _calculateHeadRotation(nose, leftEar, rightEar, leftEye, rightEye);
    
    // Debug output
    print('Head rotation: ${headRotation.toStringAsFixed(1)}° State: $_state');
    
    // Determine head position based on rotation
    final isLeft = headRotation < ExerciseThresholds.headNodLeftThreshold;
    final isRight = headRotation > ExerciseThresholds.headNodRightThreshold;
    final isCenter = !isLeft && !isRight;
    
    // State machine logic - counts EVERY movement to an extreme
    switch (_state) {
      case _HeadNodState.center:
        if (isLeft) {
          // Moved to left - count rep!
          _state = _HeadNodState.left;
          _reps++;
          _correctForm = true;
          print('✅ Head Nod Rep completed! (Center→Left) Total: $_reps');
        } else if (isRight) {
          // Moved to right - count rep!
          _state = _HeadNodState.right;
          _reps++;
          _correctForm = true;
          print('✅ Head Nod Rep completed! (Center→Right) Total: $_reps');
        } else {
          _correctForm = isCenter;
        }
        break;
        
      case _HeadNodState.left:
        if (isCenter) {
          // Returned to center from left
          _state = _HeadNodState.center;
          _correctForm = true;
        } else {
          _correctForm = isLeft;
        }
        break;
        
      case _HeadNodState.right:
        if (isCenter) {
          // Returned to center from right
          _state = _HeadNodState.center;
          _correctForm = true;
        } else {
          _correctForm = isRight;
        }
        break;
    }
  }
  
  /// Calculate head rotation angle based on facial landmarks
  /// Returns negative values for left rotation, positive for right rotation
  double _calculateHeadRotation(
    PoseLandmark nose,
    PoseLandmark leftEar,
    PoseLandmark rightEar,
    PoseLandmark leftEye,
    PoseLandmark rightEye,
  ) {
    // Calculate the midpoint between the ears
    final earMidX = (leftEar.x + rightEar.x) / 2;
    
    // Calculate the midpoint between the eyes (more stable reference)
    final eyeMidX = (leftEye.x + rightEye.x) / 2;
    
    // Use eye midpoint as reference for head center
    final headCenterX = eyeMidX;
    
    // Calculate nose offset from head center
    final noseOffset = nose.x - headCenterX;
    
    // Calculate ear distance (head width)
    final earDistance = (leftEar.x - rightEar.x).abs();
    
    // Avoid division by zero
    if (earDistance == 0) {
      return 0.0;
    }
    
    // Calculate rotation as percentage of head width
    // Normalize to degrees (-45 to +45 typical range)
    final rotationPercentage = noseOffset / earDistance;
    final rotationDegrees = rotationPercentage * 45.0;
    
    // Invert the sign because in screen coordinates:
    // - Positive X offset means head turned right (nose to the right of center)
    // - But we want positive degrees to mean right rotation
    return rotationDegrees;
  }
  
  @override
  void reset() {
    _state = _HeadNodState.center;
    _reps = 0;
    _correctForm = false;
  }
}


import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'exercise_counter.dart';
import '../utils/constants.dart';
import '../utils/angle_calculator.dart';
import 'dart:math';

/// Counter for Plank exercises
/// 
/// Unlike rep-based exercises, planks track duration in correct position.
/// The timer only runs when the user maintains proper plank form:
/// - Body alignment: shoulders-hips-knees should form a straight line
/// - Angle between shoulder-hip-knee should be between 160-180°
/// 
/// If form breaks, the timer pauses until proper position is restored.
/// The exercise is complete when target duration is reached.
class PlankCounter extends ExerciseCounter {
  int _targetDurationSeconds;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  bool _isInPosition = false;
  bool _correctForm = false;
  DateTime? _lastUpdateTime;
  
  /// Create a PlankCounter with target duration in seconds
  PlankCounter({required int targetDurationSeconds}) 
      : _targetDurationSeconds = targetDurationSeconds;
  
  @override
  int get currentReps {
    // For planks, we return elapsed seconds instead of reps
    return _elapsedTime.inSeconds;
  }
  
  @override
  bool get isInCorrectForm => _correctForm;
  
  /// Check if the target duration has been reached
  bool get isComplete => _elapsedTime.inSeconds >= _targetDurationSeconds;
  
  /// Get remaining time in seconds
  int get remainingSeconds => (_targetDurationSeconds - _elapsedTime.inSeconds).clamp(0, _targetDurationSeconds);
  
  @override
  void processPose(Pose pose) {
    final landmarks = pose.landmarks;
    
    // Get required landmarks (using left side for consistency)
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    
    // Also get right side for validation
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    
    // Check if all required landmarks are detected
    if (leftShoulder == null || leftHip == null || leftKnee == null ||
        rightShoulder == null || rightHip == null || rightKnee == null) {
      _handlePositionBreak();
      return;
    }
    
    // Check InFrameLikelihood
    if (pose.likelihood != null && pose.likelihood! < ExerciseThresholds.minInFrameLikelihood) {
      _handlePositionBreak();
      return;
    }
    
    // Validate plank position
    final isValidPosition = _validatePlankPosition(
      leftShoulder, leftHip, leftKnee,
      rightShoulder, rightHip, rightKnee,
    );
    
    final now = DateTime.now();
    
    if (isValidPosition) {
      _correctForm = true;
      
      if (!_isInPosition) {
        // Just entered correct position
        _isInPosition = true;
        _startTime = now;
        _lastUpdateTime = now;
      } else {
        // Continue timing
        if (_lastUpdateTime != null) {
          final timeSinceLastUpdate = now.difference(_lastUpdateTime!);
          _elapsedTime += timeSinceLastUpdate;
        }
        _lastUpdateTime = now;
      }
    } else {
      _handlePositionBreak();
    }
  }
  
  /// Validate if the user is in proper plank position
  bool _validatePlankPosition(
    PoseLandmark leftShoulder, PoseLandmark leftHip, PoseLandmark leftKnee,
    PoseLandmark rightShoulder, PoseLandmark rightHip, PoseLandmark rightKnee,
  ) {
    // Calculate shoulder-hip-knee angle for both sides
    final leftAngle = AngleCalculator.calculateAngle(
      Point(leftShoulder.x, leftShoulder.y),
      Point(leftHip.x, leftHip.y),
      Point(leftKnee.x, leftKnee.y),
    );
    
    final rightAngle = AngleCalculator.calculateAngle(
      Point(rightShoulder.x, rightShoulder.y),
      Point(rightHip.x, rightHip.y),
      Point(rightKnee.x, rightKnee.y),
    );
    
    // Use average of both sides
    final avgAngle = (leftAngle + rightAngle) / 2;
    
    // Body should be roughly straight (160-180°)
    final isAligned = avgAngle >= ExerciseThresholds.plankMinAngle && 
                      avgAngle <= ExerciseThresholds.plankMaxAngle;
    
    // Additional check: body should be relatively horizontal
    // Calculate average Y positions
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final avgHipY = (leftHip.y + rightHip.y) / 2;
    final avgKneeY = (leftKnee.y + rightKnee.y) / 2;
    
    // Shoulders should be roughly at same height as hips (within reasonable range)
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final verticalDeviation = (avgShoulderY - avgHipY).abs();
    
    // Allow some vertical deviation (up to 50% of shoulder width)
    final isHorizontal = verticalDeviation < shoulderWidth * 0.5;
    
    return isAligned && isHorizontal;
  }
  
  /// Handle when position breaks
  void _handlePositionBreak() {
    _correctForm = false;
    _isInPosition = false;
    _startTime = null;
    _lastUpdateTime = null;
    // Note: We don't reset _elapsedTime - it accumulates across valid position periods
  }
  
  @override
  void reset() {
    _startTime = null;
    _elapsedTime = Duration.zero;
    _isInPosition = false;
    _correctForm = false;
    _lastUpdateTime = null;
  }
  
  /// Update target duration (useful if user changes settings)
  void setTargetDuration(int seconds) {
    _targetDurationSeconds = seconds;
  }
}

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Abstract base class for exercise-specific rep counting and validation
/// 
/// Each exercise type (Jumping Jacks, Squats, Push-ups, Planks) extends this class
/// and implements its own logic for pose processing and rep counting
abstract class ExerciseCounter {
  /// Current number of repetitions completed
  int get currentReps;
  
  /// Whether the user is currently in correct form for the exercise
  bool get isInCorrectForm;
  
  /// Process a detected pose and update rep count if applicable
  /// 
  /// This method is called for each frame where a pose is detected.
  /// Implementations should:
  /// - Analyze pose landmarks
  /// - Update internal state machine
  /// - Increment rep count when a complete rep is detected
  /// - Validate form and update isInCorrectForm
  /// 
  /// Parameters:
  ///   - pose: The detected pose from ML Kit
  void processPose(Pose pose);
  
  /// Reset the counter to initial state
  /// 
  /// This should:
  /// - Reset rep count to 0
  /// - Reset internal state machine
  /// - Clear any cached values
  void reset();
}

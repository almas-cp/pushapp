// Common social media app package names
class SocialMediaApps {
  static const String instagram = 'com.instagram.android';
  static const String tiktok = 'com.zhiliaoapp.musically';
  static const String facebook = 'com.facebook.katana';
  static const String twitter = 'com.twitter.android';
  static const String snapchat = 'com.snapchat.android';
  static const String youtube = 'com.google.android.youtube';
  static const String reddit = 'com.reddit.frontpage';
  static const String whatsapp = 'com.whatsapp';
  static const String telegram = 'org.telegram.messenger';
  static const String pinterest = 'com.pinterest';
  static const String linkedin = 'com.linkedin.android';
  static const String tumblr = 'com.tumblr';

  static const List<String> allPackageNames = [
    instagram,
    tiktok,
    facebook,
    twitter,
    snapchat,
    youtube,
    reddit,
    whatsapp,
    telegram,
    pinterest,
    linkedin,
    tumblr,
  ];
}

// Time limit options (in minutes)
class TimeLimitOptions {
  static const List<int> values = [5, 10, 15, 30];
  static const int defaultValue = 15;
}

// Reward time options (in minutes)
class RewardTimeOptions {
  static const List<int> values = [2, 5, 10];
  static const int defaultValue = 5;
}

// Rep count options for exercises
class RepCountOptions {
  static const List<int> repBasedExercises = [10, 15, 20, 25, 30];
  static const List<int> plankDurations = [30, 60, 90]; // in seconds
  static const int defaultReps = 20;
  static const int defaultPlankDuration = 60;
}

// Angle thresholds for exercise validation
class ExerciseThresholds {
  // Squat thresholds
  static const double squatDownAngle = 90.0;
  static const double squatUpAngle = 160.0;

  // Push-up thresholds
  static const double pushUpDownAngle = 90.0;
  static const double pushUpUpAngle = 160.0;

  // Plank alignment threshold
  static const double plankMinAngle = 160.0;
  static const double plankMaxAngle = 180.0;

  // Jumping jack thresholds
  static const double jumpingJackSpreadThreshold = 0.3; // Relative to shoulder width
  
  // Head nod thresholds (horizontal movement)
  static const double headNodLeftThreshold = -8.0; // Degrees from center (very sensitive)
  static const double headNodRightThreshold = 8.0; // Degrees from center (very sensitive)
  static const double headNodCenterTolerance = 4.0; // Tolerance for center position
  
  // General pose detection
  static const double minConfidence = 0.5;
  static const double minInFrameLikelihood = 0.5;
}

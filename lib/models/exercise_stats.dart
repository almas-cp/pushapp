import 'exercise_settings.dart';

class ExerciseStats {
  final int todayCompletions;
  final int totalCompletions;
  final DateTime lastExerciseDate;
  final Map<ExerciseType, int> exerciseBreakdown;

  ExerciseStats({
    required this.todayCompletions,
    required this.totalCompletions,
    required this.lastExerciseDate,
    required this.exerciseBreakdown,
  });

  void incrementCompletion(ExerciseType type) {
    // Note: This creates a new instance since fields are final
    // The caller should replace the old instance with the new one
  }

  ExerciseStats withIncrementedCompletion(ExerciseType type) {
    final newBreakdown = Map<ExerciseType, int>.from(exerciseBreakdown);
    newBreakdown[type] = (newBreakdown[type] ?? 0) + 1;

    return ExerciseStats(
      todayCompletions: todayCompletions + 1,
      totalCompletions: totalCompletions + 1,
      lastExerciseDate: DateTime.now(),
      exerciseBreakdown: newBreakdown,
    );
  }

  ExerciseStats resetDailyStats() {
    return ExerciseStats(
      todayCompletions: 0,
      totalCompletions: totalCompletions,
      lastExerciseDate: lastExerciseDate,
      exerciseBreakdown: exerciseBreakdown,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todayCompletions': todayCompletions,
      'totalCompletions': totalCompletions,
      'lastExerciseDate': lastExerciseDate.toIso8601String(),
      'exerciseBreakdown': exerciseBreakdown.map(
        (key, value) => MapEntry(key.name, value),
      ),
    };
  }

  factory ExerciseStats.fromJson(Map<String, dynamic> json) {
    final breakdownJson = json['exerciseBreakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <ExerciseType, int>{};
    
    for (final entry in breakdownJson.entries) {
      final type = ExerciseType.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => ExerciseType.jumpingJacks,
      );
      breakdown[type] = entry.value as int;
    }

    return ExerciseStats(
      todayCompletions: json['todayCompletions'] ?? 0,
      totalCompletions: json['totalCompletions'] ?? 0,
      lastExerciseDate: DateTime.parse(
        json['lastExerciseDate'] ?? DateTime.now().toIso8601String(),
      ),
      exerciseBreakdown: breakdown,
    );
  }
}

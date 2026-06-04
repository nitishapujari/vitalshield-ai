class WellnessScorePoint {
  final DateTime date;
  final double score;

  const WellnessScorePoint({
    required this.date,
    required this.score,
  });

  factory WellnessScorePoint.fromMap(Map<String, dynamic> map) {
    return WellnessScorePoint(
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SleepConsistencyPoint {
  final String dayName;
  final double hours;
  final DateTime date;

  const SleepConsistencyPoint({
    required this.dayName,
    required this.hours,
    required this.date,
  });

  factory SleepConsistencyPoint.fromMap(Map<String, dynamic> map) {
    return SleepConsistencyPoint(
      dayName: map['dayName'] ?? '',
      hours: (map['hours'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}

class ActivityConsistencyPoint {
  final String dayName;
  final int steps;
  final DateTime date;

  const ActivityConsistencyPoint({
    required this.dayName,
    required this.steps,
    required this.date,
  });

  factory ActivityConsistencyPoint.fromMap(Map<String, dynamic> map) {
    return ActivityConsistencyPoint(
      dayName: map['dayName'] ?? '',
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}

class AnalyticsReport {
  final List<WellnessScorePoint> scoreHistory;
  final List<SleepConsistencyPoint> sleepHistory;
  final List<ActivityConsistencyPoint> activityHistory;
  
  final double sleepAverage;
  final int activityAverage;
  
  final int sleepConsistencyPercent;
  final int activityConsistencyPercent;
  
  final String insightText;

  const AnalyticsReport({
    required this.scoreHistory,
    required this.sleepHistory,
    required this.activityHistory,
    required this.sleepAverage,
    required this.activityAverage,
    required this.sleepConsistencyPercent,
    required this.activityConsistencyPercent,
    required this.insightText,
  });

  factory AnalyticsReport.fromMap(Map<String, dynamic> map) {
    return AnalyticsReport(
      scoreHistory: List<WellnessScorePoint>.from(
        (map['scoreHistory'] as List<dynamic>? ?? []).map(
          (x) => WellnessScorePoint.fromMap(x as Map<String, dynamic>),
        ),
      ),
      sleepHistory: List<SleepConsistencyPoint>.from(
        (map['sleepHistory'] as List<dynamic>? ?? []).map(
          (x) => SleepConsistencyPoint.fromMap(x as Map<String, dynamic>),
        ),
      ),
      activityHistory: List<ActivityConsistencyPoint>.from(
        (map['activityHistory'] as List<dynamic>? ?? []).map(
          (x) => ActivityConsistencyPoint.fromMap(x as Map<String, dynamic>),
        ),
      ),
      sleepAverage: (map['sleepAverage'] as num?)?.toDouble() ?? 0.0,
      activityAverage: (map['activityAverage'] as num?)?.toInt() ?? 0,
      sleepConsistencyPercent: (map['sleepConsistencyPercent'] as num?)?.toInt() ?? 0,
      activityConsistencyPercent: (map['activityConsistencyPercent'] as num?)?.toInt() ?? 0,
      insightText: map['insightText'] ?? '',
    );
  }
}

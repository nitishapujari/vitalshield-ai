/// Daily check-in model for VitalShield AI.
/// Stores wellness metrics with separate systolic and diastolic blood pressure fields.
class DailyCheckinModel {
  final String? id;
  final String? userId;
  final int? heartRate;
  final int? systolic;
  final int? diastolic;
  final double? glucose;
  final int? steps;
  final double? sleepHours;
  final DateTime? timestamp;

  const DailyCheckinModel({
    this.id,
    this.userId,
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.glucose,
    this.steps,
    this.sleepHours,
    this.timestamp,
  });

  DailyCheckinModel copyWith({
    String? id,
    String? userId,
    int? heartRate,
    int? systolic,
    int? diastolic,
    double? glucose,
    int? steps,
    double? sleepHours,
    DateTime? timestamp,
  }) {
    return DailyCheckinModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      heartRate: heartRate ?? this.heartRate,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      glucose: glucose ?? this.glucose,
      steps: steps ?? this.steps,
      sleepHours: sleepHours ?? this.sleepHours,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'heart_rate': heartRate,
      'systolic': systolic,
      'diastolic': diastolic,
      'glucose': glucose,
      'steps': steps,
      'sleep_hours': sleepHours,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  factory DailyCheckinModel.fromJson(Map<String, dynamic> json) {
    return DailyCheckinModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      heartRate: json['heart_rate'] as int?,
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      glucose: (json['glucose'] as num?)?.toDouble(),
      steps: json['steps'] as int?,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  /// Combined Blood Pressure display format (e.g. "120/80")
  String get bloodPressureDisplay {
    if (systolic != null && diastolic != null) {
      return '$systolic/$diastolic';
    }
    return '--';
  }
}

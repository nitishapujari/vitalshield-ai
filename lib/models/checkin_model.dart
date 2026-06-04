/// Daily check-in model for VitalShield AI.
class CheckinModel {
  final String? id;
  final String? userId;
  final int? heartRate;
  final String? bloodPressure; // e.g. "120/80"
  final double? glucose;
  final int? steps;
  final double? sleepHours;
  final int? stressLevel; // 1-10
  final DateTime? timestamp;

  const CheckinModel({
    this.id,
    this.userId,
    this.heartRate,
    this.bloodPressure,
    this.glucose,
    this.steps,
    this.sleepHours,
    this.stressLevel,
    this.timestamp,
  });

  CheckinModel copyWith({
    String? id,
    String? userId,
    int? heartRate,
    String? bloodPressure,
    double? glucose,
    int? steps,
    double? sleepHours,
    int? stressLevel,
    DateTime? timestamp,
  }) {
    return CheckinModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      heartRate: heartRate ?? this.heartRate,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      glucose: glucose ?? this.glucose,
      steps: steps ?? this.steps,
      sleepHours: sleepHours ?? this.sleepHours,
      stressLevel: stressLevel ?? this.stressLevel,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'heart_rate': heartRate,
      'blood_pressure': bloodPressure,
      'glucose': glucose,
      'steps': steps,
      'sleep_hours': sleepHours,
      'stress_level': stressLevel,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  factory CheckinModel.fromJson(Map<String, dynamic> json) {
    return CheckinModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      heartRate: json['heart_rate'] as int?,
      bloodPressure: json['blood_pressure'] as String?,
      glucose: (json['glucose'] as num?)?.toDouble(),
      steps: json['steps'] as int?,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      stressLevel: json['stress_level'] as int?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }
}

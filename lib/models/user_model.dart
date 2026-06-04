/// User model for VitalShield AI.
/// Stores profile, onboarding data, and computed fields.
class UserModel {
  final String? id;
  final String name;
  final String email;
  final DateTime? dob;
  final String gender;
  final double? height; // cm
  final double? weight; // kg
  final double? bmi;
  final String? activityLevel;
  final bool wellnessTrackingEnabled;
  final int? age;
  final String? ageCategory;
  final String heightUnit; // 'cm' or 'in'

  const UserModel({
    this.id,
    this.name = '',
    this.email = '',
    this.dob,
    this.gender = '',
    this.height,
    this.weight,
    this.bmi,
    this.activityLevel,
    this.wellnessTrackingEnabled = false,
    this.age,
    this.ageCategory,
    this.heightUnit = 'cm',
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? dob,
    String? gender,
    double? height,
    double? weight,
    double? bmi,
    String? activityLevel,
    bool? wellnessTrackingEnabled,
    int? age,
    String? ageCategory,
    String? heightUnit,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      activityLevel: activityLevel ?? this.activityLevel,
      wellnessTrackingEnabled:
          wellnessTrackingEnabled ?? this.wellnessTrackingEnabled,
      age: age ?? this.age,
      ageCategory: ageCategory ?? this.ageCategory,
      heightUnit: heightUnit ?? this.heightUnit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'dob': dob?.toIso8601String(),
      'gender': gender,
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'activity_level': activityLevel,
      'wellness_tracking_enabled': wellnessTrackingEnabled,
      'age': age,
      'age_category': ageCategory,
      'height_unit': heightUnit,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      gender: json['gender'] as String? ?? '',
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      activityLevel: json['activity_level'] as String?,
      wellnessTrackingEnabled:
          json['wellness_tracking_enabled'] as bool? ?? false,
      age: json['age'] as int?,
      ageCategory: json['age_category'] as String?,
      heightUnit: json['height_unit'] as String? ?? 'cm',
    );
  }
}

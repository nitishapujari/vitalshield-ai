/// Utility for age-related calculations.
/// Supports DOB → age conversion and age category assignment.
class AgeCalculator {
  AgeCalculator._();

  /// Calculate age from date of birth
  static int calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Get age category based on age
  static AgeCategory getCategory(int age) {
    if (age < 13) return AgeCategory.child;
    if (age < 60) return AgeCategory.adult;
    return AgeCategory.seniorCitizen;
  }

  /// Calculate BMI from height (cm) and weight (kg)
  static double calculateBMI(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// Get BMI category label
  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// Get BMI category description (calm, human-friendly)
  static String bmiDescription(double bmi) {
    if (bmi < 18.5) {
      return 'Your BMI suggests you may benefit from a nutrition-focused wellness plan.';
    }
    if (bmi < 25) {
      return 'Your BMI is in a healthy range. Keep up the great work!';
    }
    if (bmi < 30) {
      return 'Your BMI suggests focusing on activity and nutrition could be beneficial.';
    }
    return 'Consider working with a wellness professional for personalized guidance.';
  }
}

/// Age category enum for adaptive UI and wellness logic
enum AgeCategory {
  child,
  adult,
  seniorCitizen;

  String get label {
    switch (this) {
      case AgeCategory.child:
        return 'Child';
      case AgeCategory.adult:
        return 'Adult';
      case AgeCategory.seniorCitizen:
        return 'Senior Citizen';
    }
  }

  /// Whether this category represents a senior citizen (60+).
  /// Used by engines for softer thresholds and gentler language.
  bool get isSenior => this == AgeCategory.seniorCitizen;
}

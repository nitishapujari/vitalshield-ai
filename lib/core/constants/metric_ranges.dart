/// Centralized wellness metric ranges, defaults, and threshold boundaries.
/// Keeps validation rules and mock summaries clean and maintainable.
class MetricRanges {
  // Heart Rate (BPM)
  static const int minHeartRate = 40;
  static const int maxHeartRate = 200;
  static const int normalHeartRateMin = 50;
  static const int normalHeartRateMax = 100;

  // Blood Pressure (mmHg)
  static const int minSystolic = 70;
  static const int maxSystolic = 190;
  static const int normalSystolicMin = 90;
  static const int normalSystolicMax = 120;

  static const int minDiastolic = 40;
  static const int maxDiastolic = 120;
  static const int normalDiastolicMin = 60;
  static const int normalDiastolicMax = 80;

  // Glucose (mg/dL)
  static const double minGlucose = 40.0;
  static const double maxGlucose = 300.0;
  static const double normalGlucoseMin = 70.0;
  static const double normalGlucoseMax = 100.0;

  // Steps
  static const int minSteps = 0;
  static const int maxSteps = 30000;
  static const int targetStepsThreshold = 5000; // Step count active boundary

  // Sleep Hours
  static const double minSleep = 0.0;
  static const double maxSleep = 24.0;
  static const double targetSleepThreshold = 7.0; // Rested sleep hours boundary
}

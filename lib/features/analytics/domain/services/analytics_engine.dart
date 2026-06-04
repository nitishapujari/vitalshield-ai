import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../../../predictions/domain/models/prediction_model.dart';
import '../../../predictions/domain/services/insight_builder.dart';
import '../models/trend_data_model.dart';

class AnalyticsEngine {
  /// Generate a complete AnalyticsReport from raw historical records.
  /// Optionally accepts user demographics for personalized insight language.
  static AnalyticsReport generateReport({
    required List<DailyCheckinModel> checkins,
    required List<PredictionSnapshotModel> predictions,
    String? ageCategory,
    String? gender,
  }) {
    // Sort chronologically (oldest to newest) to draw charts correctly
    final sortedCheckins = List<DailyCheckinModel>.from(checkins)
      ..sort((a, b) => (a.timestamp ?? DateTime.now()).compareTo(b.timestamp ?? DateTime.now()));

    final sortedPredictions = List<PredictionSnapshotModel>.from(predictions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 1. Build Wellness Score History
    final scoreHistory = sortedPredictions.map((pred) {
      return WellnessScorePoint(
        date: pred.timestamp,
        score: pred.overallWellnessScore.toDouble(),
      );
    }).toList();

    // 2. Build Sleep Consistency List (Last 7 check-ins)
    final recentCheckinsForSleep = sortedCheckins.length > 7
        ? sortedCheckins.sublist(sortedCheckins.length - 7)
        : sortedCheckins;

    final sleepHistory = recentCheckinsForSleep.map((c) {
      final date = c.timestamp ?? DateTime.now();
      final dayName = DateFormat('E').format(date);
      return SleepConsistencyPoint(
        dayName: dayName,
        hours: (c.sleepHours ?? 0).toDouble(),
        date: date,
      );
    }).toList();

    // 3. Build Activity Consistency List (Last 7 check-ins)
    final activityHistory = recentCheckinsForSleep.map((c) {
      final date = c.timestamp ?? DateTime.now();
      final dayName = DateFormat('E').format(date);
      return ActivityConsistencyPoint(
        dayName: dayName,
        steps: c.steps ?? 0,
        date: date,
      );
    }).toList();

    // 4. Calculate Averages
    final validSleeps = sortedCheckins
        .where((c) => c.sleepHours != null)
        .map((c) => c.sleepHours!.toDouble())
        .toList();
    final sleepAverage = validSleeps.isEmpty
        ? 0.0
        : validSleeps.reduce((a, b) => a + b) / validSleeps.length;

    final validSteps = sortedCheckins
        .where((c) => c.steps != null)
        .map((c) => c.steps!.toDouble())
        .toList();
    final activityAverage = validSteps.isEmpty
        ? 0
        : (validSteps.reduce((a, b) => a + b) / validSteps.length).round();

    // 5. Calculate Consistency Percentages (0 - 100)
    final sleepConsistency = _calculateSleepConsistency(validSleeps);
    final activityConsistency = _calculateActivityConsistency(validSteps);

    // 6. Generate Contextual Insight with age awareness
    bool hasCriticalEmergency = false;
    if (sortedCheckins.isNotEmpty) {
      final latestC = sortedCheckins.last;
      final sys = latestC.systolic;
      final dia = latestC.diastolic;
      final glucose = latestC.glucose;
      if ((sys != null && sys >= 180) || (dia != null && dia >= 120)) {
        hasCriticalEmergency = true;
      } else if (glucose != null && (glucose < 55.0 || glucose > 300.0)) {
        hasCriticalEmergency = true;
      }
    }

    final insight = hasCriticalEmergency
        ? '🚨 CRITICAL ALERT: Your latest readings indicate a medical emergency. Please seek immediate medical care. Wellness tracking should resume once your vitals are stable.'
        : _generateTrendInsight(
            sleepAverage: sleepAverage,
            sleepConsistency: sleepConsistency,
            activityAverage: activityAverage,
            activityConsistency: activityConsistency,
            ageCategory: ageCategory,
          );

    return AnalyticsReport(
      scoreHistory: scoreHistory,
      sleepHistory: sleepHistory,
      activityHistory: activityHistory,
      sleepAverage: sleepAverage,
      activityAverage: activityAverage,
      sleepConsistencyPercent: sleepConsistency,
      activityConsistencyPercent: activityConsistency,
      insightText: insight,
    );
  }

  /// Calculates sleep consistency based on deviation from average sleep.
  static int _calculateSleepConsistency(List<double> sleeps) {
    if (sleeps.length < 2) return 100;
    
    final mean = sleeps.reduce((a, b) => a + b) / sleeps.length;
    final variance = sleeps.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / sleeps.length;
    final stdDev = math.sqrt(variance);

    // 0 std deviation means 100% consistency. Each 1 hour of stdDev reduces consistency by 15%.
    final score = (100 - (stdDev * 15)).round();
    return math.max(30, math.min(100, score));
  }

  /// Calculates activity consistency based on coefficient of variation.
  static int _calculateActivityConsistency(List<double> steps) {
    if (steps.length < 2) return 100;

    // Cap steps at a target threshold of 5000 to avoid penalizing high variance from extra activity
    final cappedSteps = steps.map((s) => math.min(s, 5000.0)).toList();
    final mean = cappedSteps.reduce((a, b) => a + b) / cappedSteps.length;
    if (mean == 0) return 100;

    final variance = cappedSteps.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / cappedSteps.length;
    final stdDev = math.sqrt(variance);

    // Using coefficient of variation (stdDev / mean)
    final cv = stdDev / mean;
    final score = (100 - (cv * 100)).round();
    return math.max(30, math.min(100, score));
  }

  /// Formulates a single supportive, short insight explaining the trends.
  /// Subtly adapts language based on age context without explicit references.
  static String _generateTrendInsight({
    required double sleepAverage,
    required int sleepConsistency,
    required int activityAverage,
    required int activityConsistency,
    String? ageCategory,
  }) {
    final isSenior = ageCategory == 'Senior' || ageCategory == 'Senior Citizen';
    return InsightBuilder.generateAnalyticsInsight(
      sleepAverage: sleepAverage,
      sleepConsistency: sleepConsistency,
      activityAverage: activityAverage,
      activityConsistency: activityConsistency,
      isSenior: isSenior,
    );
  }
}

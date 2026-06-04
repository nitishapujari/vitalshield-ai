import 'dart:math';
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../models/prediction_model.dart';
import '../models/explanation_model.dart';

/// Engine to generate human-readable explanations (XAI) for wellness predictions.
class ExplanationEngine {
  /// Generates a list of contributing factors for a given prediction category.
  static PredictionExplanation explain(
    PredictionCategoryModel category,
    DailyCheckinModel? latest,
    List<DailyCheckinModel> history, {
    bool isSenior = false,
  }) {
    final factors = <ContributingFactor>[];

    if (latest == null) {
      return const PredictionExplanation(factors: []);
    }

    final categoryTitle = category.categoryTitle.toLowerCase();

    if (categoryTitle.contains('sleep')) {
      _explainSleep(factors, latest, history, isSenior);
    } else if (categoryTitle.contains('heart')) {
      _explainHeart(factors, latest, history, isSenior);
    } else if (categoryTitle.contains('pressure')) {
      _explainBloodPressure(factors, latest, history, isSenior);
    } else if (categoryTitle.contains('glucose')) {
      _explainGlucose(factors, latest, history, isSenior);
    } else if (categoryTitle.contains('activity')) {
      _explainActivity(factors, latest, history, isSenior);
    } else {
      // Default fallback
      factors.add(ContributingFactor(
        label: 'Historical Consistency',
        impact: FactorImpact.positive,
        contributionPercent: 100.0,
        description: category.insight,
      ));
    }

    return PredictionExplanation(factors: factors);
  }

  static void _explainSleep(
    List<ContributingFactor> factors,
    DailyCheckinModel latest,
    List<DailyCheckinModel> history,
    bool isSenior,
  ) {
    final sleep = latest.sleepHours ?? 7.0;
    final sleepThreshold = isSenior ? 6.5 : 7.0;

    // 1. Duration factor
    if (sleep >= sleepThreshold && sleep <= 9.0) {
      factors.add(ContributingFactor(
        label: 'Sleep Duration',
        impact: FactorImpact.positive,
        contributionPercent: 60.0,
        description: 'Your sleep duration ($sleep hrs) is within the recommended restful window.',
      ));
    } else if (sleep > 9.0) {
      factors.add(ContributingFactor(
        label: 'Sleep Duration',
        impact: FactorImpact.neutral,
        contributionPercent: 50.0,
        description: 'Sleep duration was slightly longer than average, which may indicate extra recovery needs.',
      ));
    } else {
      factors.add(ContributingFactor(
        label: 'Sleep Duration',
        impact: FactorImpact.negative,
        contributionPercent: 65.0,
        description: 'Your sleep duration was slightly below your recommended restful target ($sleepThreshold hrs).',
      ));
    }

    // 2. Consistency factor
    final sleepList = history.map((e) => e.sleepHours).where((e) => e != null).cast<double>().toList();
    if (sleepList.length > 2) {
      final mean = sleepList.reduce((a, b) => a + b) / sleepList.length;
      final variance = sleepList.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / sleepList.length;
      final stdDev = sqrt(variance);

      if (stdDev < 1.0) {
        factors.add(const ContributingFactor(
          label: 'Sleep Consistency',
          impact: FactorImpact.positive,
          contributionPercent: 40.0,
          description: 'Consistent sleep timing supports your body\'s natural daily rhythms.',
        ));
      } else {
        factors.add(const ContributingFactor(
          label: 'Sleep Consistency',
          impact: FactorImpact.neutral,
          contributionPercent: 35.0,
          description: 'Minor sleep timing variations can temporarily affect your body\'s recovery rhythm.',
        ));
      }
    } else {
      factors.add(const ContributingFactor(
        label: 'Baseline Stability',
        impact: FactorImpact.neutral,
        contributionPercent: 40.0,
        description: 'Establishing a multi-day sleep pattern will help refine your personalized insights.',
      ));
    }
  }

  static void _explainHeart(
    List<ContributingFactor> factors,
    DailyCheckinModel latest,
    List<DailyCheckinModel> history,
    bool isSenior,
  ) {
    final hr = latest.heartRate ?? 72;
    final minHr = isSenior ? 55 : 60;
    final maxHr = isSenior ? 105 : 100;

    if (hr >= minHr && hr <= maxHr) {
      factors.add(ContributingFactor(
        label: 'Resting Heart Rate',
        impact: FactorImpact.positive,
        contributionPercent: 70.0,
        description: 'Your resting heart rate ($hr BPM) remains steady and within your balanced window.',
      ));
      factors.add(const ContributingFactor(
        label: 'Circulation Rhythm',
        impact: FactorImpact.positive,
        contributionPercent: 30.0,
        description: 'Your activity levels support steady circulation and comfortable recovery.',
      ));
    } else {
      factors.add(ContributingFactor(
        label: 'Resting Heart Rate',
        impact: FactorImpact.negative,
        contributionPercent: 60.0,
        description: 'Your resting heart rate reading ($hr BPM) is slightly outside your typical resting range.',
      ));
      factors.add(const ContributingFactor(
        label: 'Internal Calm',
        impact: FactorImpact.neutral,
        contributionPercent: 40.0,
        description: 'This mild variation may suggest a little extra rest or simple hydration.',
      ));
    }
  }

  static void _explainBloodPressure(
    List<ContributingFactor> factors,
    DailyCheckinModel latest,
    List<DailyCheckinModel> history,
    bool isSenior,
  ) {
    final sys = latest.systolic ?? 120;
    final dia = latest.diastolic ?? 80;

    if (sys <= 120 && dia <= 80) {
      factors.add(ContributingFactor(
        label: 'Vascular Balance',
        impact: FactorImpact.positive,
        contributionPercent: 65.0,
        description: 'Your circulation readings ($sys/$dia mmHg) show a steady, comfortable flow.',
      ));
      factors.add(const ContributingFactor(
        label: 'Circulatory Ease',
        impact: FactorImpact.positive,
        contributionPercent: 35.0,
        description: 'Your heart is working comfortably, supporting gentle circulation.',
      ));
    } else {
      factors.add(ContributingFactor(
        label: 'Circulatory Pace',
        impact: FactorImpact.negative,
        contributionPercent: 55.0,
        description: 'Your reading ($sys/$dia mmHg) indicates a temporary shift. Mindful breathing or a brief rest can gently support circulation.',
      ));
      factors.add(const ContributingFactor(
        label: 'Hydration & Balance',
        impact: FactorImpact.neutral,
        contributionPercent: 45.0,
        description: 'Daily shifts are natural and often reflect hydration levels or your daily pace.',
      ));
    }
  }

  static void _explainGlucose(
    List<ContributingFactor> factors,
    DailyCheckinModel latest,
    List<DailyCheckinModel> history,
    bool isSenior,
  ) {
    final glucose = latest.glucose ?? 90.0;

    if (glucose >= 70.0 && glucose <= 100.0) {
      factors.add(ContributingFactor(
        label: 'Fasting Glucose Balance',
        impact: FactorImpact.positive,
        contributionPercent: 75.0,
        description: 'Your energy balance ($glucose mg/dL) shows steady stability.',
      ));
      factors.add(const ContributingFactor(
        label: 'Energy Rhythm',
        impact: FactorImpact.positive,
        contributionPercent: 25.0,
        description: 'Your body is processing energy efficiently, supporting steady vitality.',
      ));
    } else if (glucose > 100.0) {
      factors.add(ContributingFactor(
        label: 'Energy Fueling',
        impact: FactorImpact.negative,
        contributionPercent: 60.0,
        description: 'Recent energy readings ($glucose mg/dL) are slightly higher, which is a natural response.',
      ));
      factors.add(const ContributingFactor(
        label: 'Energy Absorption',
        impact: FactorImpact.neutral,
        contributionPercent: 40.0,
        description: 'Subtle shifts are natural and can stem from recent meals, your body\'s morning cycle, or recovery.',
      ));
    } else {
      factors.add(ContributingFactor(
        label: 'Energy Baseline',
        impact: FactorImpact.negative,
        contributionPercent: 60.0,
        description: 'Energy readings ($glucose mg/dL) are slightly lower than your typical baseline.',
      ));
    }
  }

  static void _explainActivity(
    List<ContributingFactor> factors,
    DailyCheckinModel latest,
    List<DailyCheckinModel> history,
    bool isSenior,
  ) {
    final steps = latest.steps ?? 5000;
    final stepThreshold = isSenior ? 4000 : 5000;

    if (steps >= stepThreshold) {
      factors.add(ContributingFactor(
        label: 'Daily Movement Volume',
        impact: FactorImpact.positive,
        contributionPercent: 60.0,
        description: 'Daily steps ($steps) reached your gentle movement goal.',
      ));
      factors.add(const ContributingFactor(
        label: 'Movement Energy',
        impact: FactorImpact.positive,
        contributionPercent: 40.0,
        description: 'Regular movement supports your body\'s vitality and overall physical well-being.',
      ));
    } else {
      factors.add(ContributingFactor(
        label: 'Daily Movement Volume',
        impact: FactorImpact.negative,
        contributionPercent: 70.0,
        description: 'Your step count ($steps) was slightly below your standard daily movement.',
      ));
      factors.add(const ContributingFactor(
        label: 'Quiet Rest',
        impact: FactorImpact.neutral,
        contributionPercent: 30.0,
        description: 'Quieter days support recovery; a gentle stretch is a great way to stay limber when you feel ready.',
      ));
    }
  }
}

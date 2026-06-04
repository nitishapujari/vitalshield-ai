import 'package:flutter_test/flutter_test.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/explanation_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/services/explanation_engine.dart';

void main() {
  group('ExplanationEngine Tests', () {
    late DailyCheckinModel latest;
    late List<DailyCheckinModel> history;

    setUp(() {
      latest = DailyCheckinModel(
        timestamp: DateTime.now(),
        sleepHours: 8.0,
        steps: 8000,
        heartRate: 70,
        systolic: 115,
        diastolic: 75,
        glucose: 90,
      );
      history = [latest];
    });

    test('explain sleep wellness generates correct factors', () {
      final category = PredictionCategoryModel(
        categoryTitle: 'Sleep Wellness',
        score: 85,
        status: 'Optimal',
        trendDirection: TrendDirection.stable,
        insight: 'Your sleep was good.',
        recommendation: 'Maintain consistency.',
      );

      final explanation = ExplanationEngine.explain(category, latest, history);

      expect(explanation.factors, isNotEmpty);
      
      final durationFactor = explanation.factors.firstWhere((f) => f.label == 'Sleep Duration');
      expect(durationFactor.impact, FactorImpact.positive);
      expect(durationFactor.description, contains('recommended restful window'));
      
      // Verify labels are human-friendly
      for (final factor in explanation.factors) {
        expect(factor.label, isNot(contains('sleepHours')));
        expect(factor.label, isNot(contains('steps')));
      }
    });

    test('explain heart wellness generates correct factors', () {
      final category = PredictionCategoryModel(
        categoryTitle: 'Heart Rate Wellness',
        score: 85,
        status: 'Stable',
        trendDirection: TrendDirection.stable,
        insight: 'Your heart rate was steady.',
        recommendation: 'Maintain gentle exercise.',
      );

      final explanation = ExplanationEngine.explain(category, latest, history);

      expect(explanation.factors.length, 2);
      expect(explanation.factors[0].label, 'Resting Heart Rate');
      expect(explanation.factors[0].impact, FactorImpact.positive);
      expect(explanation.factors[1].label, 'Circulation Rhythm');
    });

    test('explain blood pressure wellness handles elevations', () {
      final elevatedLatest = DailyCheckinModel(
        timestamp: DateTime.now(),
        sleepHours: 8.0,
        steps: 8000,
        heartRate: 70,
        systolic: 135, // elevated
        diastolic: 85, // elevated
        glucose: 90,
      );

      final category = PredictionCategoryModel(
        categoryTitle: 'Blood Pressure Wellness',
        score: 60,
        status: 'Elevated',
        trendDirection: TrendDirection.needsAttention,
        insight: 'Elevated blood pressure.',
        recommendation: 'Rest and hydrate.',
      );

      final explanation = ExplanationEngine.explain(category, elevatedLatest, [elevatedLatest]);

      expect(explanation.factors, isNotEmpty);
      final tensionFactor = explanation.factors.firstWhere((f) => f.label == 'Circulatory Pace');
      expect(tensionFactor.impact, FactorImpact.negative);
      expect(tensionFactor.description, contains('indicates a temporary shift'));
    });

    test('explain glucose wellness handles high values', () {
      final highGlucoseLatest = DailyCheckinModel(
        timestamp: DateTime.now(),
        sleepHours: 8.0,
        steps: 8000,
        heartRate: 70,
        systolic: 120,
        diastolic: 80,
        glucose: 110.0, // elevated
      );

      final category = PredictionCategoryModel(
        categoryTitle: 'Glucose Wellness',
        score: 60,
        status: 'Elevated',
        trendDirection: TrendDirection.needsAttention,
        insight: 'Elevated glucose.',
        recommendation: 'Monitor morning readings.',
      );

      final explanation = ExplanationEngine.explain(category, highGlucoseLatest, [highGlucoseLatest]);

      expect(explanation.factors, isNotEmpty);
      final nutrientFactor = explanation.factors.firstWhere((f) => f.label == 'Energy Fueling');
      expect(nutrientFactor.impact, FactorImpact.negative);
    });

    test('explain activity wellness handles low steps', () {
      final lowStepsLatest = DailyCheckinModel(
        timestamp: DateTime.now(),
        sleepHours: 8.0,
        steps: 2000, // low
        heartRate: 70,
        systolic: 120,
        diastolic: 80,
        glucose: 90,
      );

      final category = PredictionCategoryModel(
        categoryTitle: 'Activity Wellness',
        score: 55,
        status: 'Low Activity',
        trendDirection: TrendDirection.needsAttention,
        insight: 'Low physical activity.',
        recommendation: 'Try taking a short walk.',
      );

      final explanation = ExplanationEngine.explain(category, lowStepsLatest, [lowStepsLatest]);

      expect(explanation.factors, isNotEmpty);
      final movementFactor = explanation.factors.firstWhere((f) => f.label == 'Daily Movement Volume');
      expect(movementFactor.impact, FactorImpact.negative);
      expect(movementFactor.description, contains('slightly below your standard daily movement'));
    });
  });
}

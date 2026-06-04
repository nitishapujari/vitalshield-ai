import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/services/prediction_engine_service.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PredictionEngineService Tests', () {
    late PredictionEngineService engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = PredictionEngineService();
    });

    test('generatePrediction handles empty history gracefully', () async {
      final snapshot = await engine.generatePrediction([]);

      expect(snapshot.categories, isEmpty);
      expect(snapshot.overallWellnessScore, 70);
      expect(snapshot.primaryInsight, 'Complete more daily check-ins to unlock wellness predictions.');
    });

    test('generatePrediction generates correct trends for healthy data', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 8.0,
          steps: 8000,
          heartRate: 70,
          systolic: 110,
          diastolic: 70,
          glucose: 90,
        ),
      ];

      final snapshot = await engine.generatePrediction(history);

      expect(snapshot.categories.length, 5);
      
      // Verify Overall Score
      expect(snapshot.overallWellnessScore, greaterThan(80));

      // Verify Sleep Trend
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');
      expect(sleepCat.score, 90);
      expect(sleepCat.trendDirection, TrendDirection.stable);

      // Verify Activity Trend
      final activityCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');
      expect(activityCat.score, 85);
      expect(activityCat.trendDirection, TrendDirection.stable);
    });

    test('generatePrediction detects Needs Attention trends', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 4.0, // Needs attention
          steps: 2000,     // Needs attention
          heartRate: 110,  // Needs attention
          systolic: 140,   // Needs attention
          diastolic: 90,   // Needs attention
          glucose: 120,    // Needs attention
        ),
      ];

      final snapshot = await engine.generatePrediction(history);

      expect(snapshot.overallWellnessScore, lessThan(70));

      // Verify Sleep Trend
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');
      expect(sleepCat.score, 50);
      expect(sleepCat.trendDirection, TrendDirection.needsAttention);
      
      // Verify the primary insight surfaces a Needs Attention item
      expect(snapshot.primaryInsight, isNotEmpty);
    });

    test('senior citizen is evaluated under standard activity threshold', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 7.0,
          steps: 4500, // Below standard threshold (5000)
          heartRate: 72,
          systolic: 118,
          diastolic: 75,
          glucose: 90,
        ),
      ];

      // Without senior context — flags activity as needs attention
      final adultSnapshot = await engine.generatePrediction(
        history,
        ageCategory: 'Adult',
      );
      final adultActivity = adultSnapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');
      expect(adultActivity.trendDirection, TrendDirection.needsAttention);

      // With senior citizen context — ALSO flags activity as needs attention (demographics consistency)
      final seniorSnapshot = await engine.generatePrediction(
        history,
        ageCategory: 'Senior Citizen',
      );
      final seniorActivity = seniorSnapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');
      expect(seniorActivity.trendDirection, TrendDirection.needsAttention);
      expect(seniorActivity.score, 55);
    });

    test('senior citizen gets standard recommendations (demographics consistency)', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 8.0,
          steps: 3000, // Below standard threshold
          heartRate: 72,
          systolic: 118,
          diastolic: 75,
          glucose: 90,
        ),
      ];

      final seniorSnapshot = await engine.generatePrediction(
        history,
        ageCategory: 'Senior Citizen',
      );
      final seniorActivity = seniorSnapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');
      expect(seniorActivity.recommendation, contains('15-minute walk'));
    });
  });
}

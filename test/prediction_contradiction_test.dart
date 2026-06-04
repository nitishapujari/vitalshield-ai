import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/services/prediction_engine_service.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/assistant/domain/services/response_generator.dart';
import 'package:vitalshield_ai/features/analytics/domain/services/analytics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prediction Contradiction and Priority Tests', () {
    late PredictionEngineService engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = PredictionEngineService();
    });

    test('vitals critical BP crisis suppresses lower priority recommendations', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 5.0, // Sleep Warning
          steps: 1000,     // Activity Warning
          heartRate: 72,
          systolic: 185,   // BP Crisis (Critical)
          diastolic: 125,  // BP Crisis (Critical)
          glucose: 90,
        ),
      ];

      final snapshot = await engine.generatePrediction(history, isOffline: true);
      final bpCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Blood Pressure Wellness');
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');
      final activityCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');

      expect(bpCat.recommendationPriority, equals('Critical'));
      expect(bpCat.recommendation.toLowerCase(), contains('emergency'));
      
      // Other recommendations must be suppressed
      expect(sleepCat.recommendation, equals(''));
      expect(activityCat.recommendation, equals(''));
    });

    test('vitals severe hypoglycemia suppresses lower priority recommendations', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 5.0, // Sleep Warning
          steps: 1000,     // Activity Warning
          heartRate: 72,
          systolic: 120,
          diastolic: 80,
          glucose: 45,     // Severe Hypoglycemia (Critical)
        ),
      ];

      final snapshot = await engine.generatePrediction(history, isOffline: true);
      final glucoseCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Glucose Wellness');
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');

      expect(glucoseCat.recommendationPriority, equals('Critical'));
      expect(glucoseCat.recommendation, contains('fast-acting carbohydrates'));
      expect(sleepCat.recommendation, equals(''));
    });

    test('mixed emergency deterministic ordering (Hypoglycemia -> BP Crisis -> Hyperglycemia)', () async {
      final historyHypoBp = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 8.0,
          steps: 5000,
          heartRate: 72,
          systolic: 185,   // BP Crisis (Critical)
          diastolic: 125,  // BP Crisis (Critical)
          glucose: 45,     // Hypoglycemia (Critical)
        ),
      ];

      final snapshot = await engine.generatePrediction(historyHypoBp, isOffline: true);
      
      // Order must be: 1. Glucose Wellness (Hypoglycemia), 2. Blood Pressure Wellness (BP Crisis)
      expect(snapshot.categories[0].categoryTitle, equals('Glucose Wellness'));
      expect(snapshot.categories[1].categoryTitle, equals('Blood Pressure Wellness'));
      expect(snapshot.categories[0].recommendationPriority, equals('Critical'));
      expect(snapshot.categories[1].recommendationPriority, equals('Critical'));
      
      // Warnings/Info suppressed
      expect(snapshot.categories[2].recommendation, equals(''));
    });

    test('warning level low BP suppresses activity suggestions', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 8.0,
          steps: 1000,     // Activity Warning
          heartRate: 72,
          systolic: 85,    // Low BP Warning
          diastolic: 55,   // Low BP Warning
          glucose: 90,
        ),
      ];

      final snapshot = await engine.generatePrediction(history, isOffline: true);
      final activityCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Activity Wellness');
      final bpCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Blood Pressure Wellness');

      expect(bpCat.recommendationPriority, equals('Warning'));
      expect(activityCat.recommendation, equals(''));
    });

    test('deduplication merging merges Sleep + low HR Warnings', () async {
      // Sleep Wellness score < 85 & Heart Wellness lower HR warning
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 5.0, // Sleep Warning
          steps: 5000,
          heartRate: 45,   // Heart Warning (low HR)
          systolic: 120,
          diastolic: 80,
          glucose: 90,
        ),
      ];

      final snapshot = await engine.generatePrediction(history, isOffline: true);
      final heartCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Heart Wellness');
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');

      expect(heartCat.recommendation, contains('resting heart rate'));
      expect(heartCat.recommendation, contains('sleep'));
      expect(sleepCat.recommendation, equals(''));
    });
  });

  group('Assistant Emergency Interception Tests', () {
    final generator = ResponseGenerator();

    test('intercepts exercise optimization query during hypertensive crisis', () {
      final context = {
        'checkin': {
          'systolic': 185,
          'diastolic': 125,
          'glucose': 90.0,
        },
        'prediction': null,
        'userProfile': {'name': 'Sarah'},
      };

      final reply = generator.generate('should I do workouts today?', context);
      expect(reply, contains('SAFETY INTERCEPTION'));
    });

    test('does not intercept explanation queries during emergency', () {
      final context = {
        'checkin': {
          'systolic': 185,
          'diastolic': 125,
          'glucose': 90.0,
        },
        'prediction': null,
        'userProfile': {'name': 'Sarah'},
      };

      final reply = generator.generate('what is hypertensive crisis?', context);
      expect(reply, isNot(contains('SAFETY INTERCEPTION')));
    });
  });

  group('Analytics Trend Insight Override Tests', () {
    test('overrides analytics report insight with critical alert during emergency', () {
      final checkins = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 8.0,
          steps: 2000,
          heartRate: 72,
          systolic: 185, // Hypertensive Crisis
          diastolic: 125,
          glucose: 90.0,
        ),
      ];

      final report = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: [],
      );

      expect(report.insightText, contains('CRITICAL ALERT'));
    });
  });
}

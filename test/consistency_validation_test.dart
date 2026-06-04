import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/services/prediction_engine_service.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/services/insight_builder.dart';
import 'package:vitalshield_ai/features/assistant/domain/services/response_generator.dart';
import 'package:vitalshield_ai/features/analytics/domain/services/analytics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Frontend Explanation and Insight Consistency Tests', () {
    late PredictionEngineService engine;
    late ResponseGenerator generator;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = PredictionEngineService();
      generator = ResponseGenerator();
    });

    test('generatePrediction offline matches InsightBuilder opportunities and is consistent with assistant and analytics', () async {
      final history = [
        DailyCheckinModel(
          timestamp: DateTime.now(),
          sleepHours: 5.5,  // Sleep Warning
          steps: 3000,       // Activity Warning
          heartRate: 72,
          systolic: 120,     // BP Optimal
          diastolic: 80,     // BP Optimal
          glucose: 90.0      // Glucose Optimal
        ),
      ];

      // 1. Generate prediction offline
      final snapshot = await engine.generatePrediction(history, isOffline: true);

      expect(snapshot.highestImpactOpportunity, isNotNull);
      expect(snapshot.highestImpactOpportunity!.categoryTitle, equals('Sleep Wellness'));
      expect(snapshot.secondaryOpportunity, isNotNull);
      expect(snapshot.secondaryOpportunity!.categoryTitle, equals('Activity Wellness'));

      // 2. Dashboard primaryInsight matches highest impact opportunity insight
      expect(snapshot.primaryInsight, equals(snapshot.highestImpactOpportunity!.insight));

      // 3. Stable metrics contains BP, glucose, heart
      expect(snapshot.stableMetrics, contains('Blood Pressure Wellness'));
      expect(snapshot.stableMetrics, contains('Glucose Wellness'));
      expect(snapshot.stableMetrics, contains('Heart Wellness'));

      // 4. Analytics insight matches InsightBuilder analytics insight
      final report = AnalyticsEngine.generateReport(
        checkins: history,
        predictions: [snapshot],
        ageCategory: 'Adult',
      );
      final expectedAnalytics = InsightBuilder.generateAnalyticsInsight(
        sleepAverage: 5.5,
        sleepConsistency: 100,
        activityAverage: 3000,
        activityConsistency: 100,
        isSenior: false,
      );
      expect(report.insightText, equals(expectedAnalytics));
      expect(report.insightText, contains('below the target baseline of 7.0'));

      // 5. Assistant consistency
      final context = {
        'prediction': snapshot.toMap(),
        'userProfile': {
          'name': 'Sarah',
          'ageCategory': 'Adult',
          'gender': 'female',
        },
      };

      // Coaching improvement query
      final replyImprove = generator.generate('how can I improve?', context);
      expect(replyImprove, contains('sleep'));
      expect(replyImprove, contains('Physical activity'));
      expect(replyImprove, contains(snapshot.highestImpactOpportunity!.insight));
      expect(replyImprove, contains(snapshot.highestImpactOpportunity!.recommendation));
      expect(replyImprove, contains(snapshot.secondaryOpportunity!.insight));
      expect(replyImprove, contains(snapshot.secondaryOpportunity!.recommendation));

      // Specific sleep query matches the sleep category data
      final replySleep = generator.generate('tell me about my sleep', context);
      final sleepCat = snapshot.categories.firstWhere((c) => c.categoryTitle == 'Sleep Wellness');
      expect(replySleep, contains(sleepCat.insight));
      expect(replySleep, contains(sleepCat.recommendation));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/analytics/domain/services/analytics_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnalyticsEngine Tests', () {
    test('generateReport correctly calculates averages and consistencies for high sleep and steps', () {
      final now = DateTime.now();
      
      final checkins = [
        DailyCheckinModel(
          id: '1',
          sleepHours: 8.0,
          steps: 10000,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        DailyCheckinModel(
          id: '2',
          sleepHours: 8.0,
          steps: 10000,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        DailyCheckinModel(
          id: '3',
          sleepHours: 8.0,
          steps: 10000,
          timestamp: now,
        ),
      ];

      final predictions = [
        PredictionSnapshotModel(
          id: 'p1',
          timestamp: now.subtract(const Duration(days: 2)),
          overallWellnessScore: 85,
          categories: const [],
          primaryInsight: 'Test 1',
        ),
        PredictionSnapshotModel(
          id: 'p2',
          timestamp: now,
          overallWellnessScore: 90,
          categories: const [],
          primaryInsight: 'Test 2',
        ),
      ];

      final report = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: predictions,
      );

      expect(report.sleepAverage, 8.0);
      expect(report.activityAverage, 10000);
      expect(report.sleepConsistencyPercent, 100);
      expect(report.activityConsistencyPercent, 100);
      expect(report.insightText, contains('steady sleep average'));
      expect(report.scoreHistory.length, 2);
      expect(report.scoreHistory.first.score, 85.0);
    });

    test('generateReport detects low sleep consistency and flags variable schedule', () {
      final now = DateTime.now();

      final checkins = [
        DailyCheckinModel(
          id: '1',
          sleepHours: 5.0,
          steps: 6000,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        DailyCheckinModel(
          id: '2',
          sleepHours: 9.5,
          steps: 7000,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        DailyCheckinModel(
          id: '3',
          sleepHours: 6.0,
          steps: 6500,
          timestamp: now,
        ),
      ];

      final report = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: const [],
      );

      // Average sleep: (5 + 9.5 + 6) / 3 = 6.83 hours
      expect(report.sleepAverage, closeTo(6.83, 0.05));
      expect(report.sleepConsistencyPercent, lessThan(80));
      expect(report.insightText, contains('below the target baseline'));
    });

    test('generateReport flags low step count with suggestion to walk', () {
      final now = DateTime.now();

      final checkins = [
        DailyCheckinModel(
          id: '1',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        DailyCheckinModel(
          id: '2',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        DailyCheckinModel(
          id: '3',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now,
        ),
      ];

      final report = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: const [],
      );

      expect(report.activityAverage, 3000);
      expect(report.sleepConsistencyPercent, 100);
      expect(report.insightText, contains('below the recommended 5000 steps'));
    });

    test('senior citizen gets age-adapted insight language', () {
      final now = DateTime.now();

      final checkins = [
        DailyCheckinModel(
          id: '1',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        DailyCheckinModel(
          id: '2',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        DailyCheckinModel(
          id: '3',
          sleepHours: 8.0,
          steps: 3000,
          timestamp: now,
        ),
      ];

      // Adult insight
      final adultReport = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: const [],
        ageCategory: 'Adult',
      );
      expect(adultReport.insightText, contains('below the recommended 5000 steps'));

      // Senior insight — same data, but adapted threshold in text
      final seniorReport = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: const [],
        ageCategory: 'Senior Citizen',
      );
      expect(seniorReport.insightText, contains('below the recommended 4000 steps'));
    });
  });
}

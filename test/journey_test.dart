import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/journey/presentation/providers/journey_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'current_profile_id': 'profile_journey_test',
        'profile_journey_test_daily_checkins_history': [
          jsonEncode({
            'id': 'chk_may27',
            'heart_rate': 72,
            'systolic': 118,
            'diastolic': 78,
            'glucose': 92.0,
            'steps': 8500,
            'sleep_hours': 7.5,
            'timestamp': '2026-05-27T13:49:36.641000',
          }),
          jsonEncode({
            'id': 'chk_may28',
            'heart_rate': 110,
            'systolic': 150,
            'diastolic': 95,
            'glucose': 160.0,
            'steps': 1500,
            'sleep_hours': 4.5,
            'timestamp': '2026-05-28T16:03:54.838000',
          }),
        ],
        'profile_journey_test_prediction_snapshot_history': [
          jsonEncode({
            'id': 'pred_1',
            'timestamp': '2026-05-28T16:03:54.838000',
            'overallWellnessScore': 18,
            'categories': [],
            'primaryInsight': 'Elevated metrics detected.',
          })
        ],
      });
    });

    test('initializes and loads namespaced checkins and predictions', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify loading state is initially true, then transitions to false
      expect(container.read(journeyProvider).isLoading, isTrue);

      // Wait for notifier initialization
      await container.read(journeyProvider.notifier).loadJourneyData();

      final state = container.read(journeyProvider);
      expect(state.isLoading, isFalse);
      expect(state.checkins.length, equals(2));
      expect(state.checkins.first.id, equals('chk_may27'));
      expect(state.checkins.last.id, equals('chk_may28'));
      expect(state.predictions.length, equals(1));
      expect(state.predictions.first.overallWellnessScore, equals(18));
    });
  });
}

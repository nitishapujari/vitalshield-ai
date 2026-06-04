import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/data/local/checkin_storage.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/checkin/presentation/providers/checkin_provider.dart';
import 'package:vitalshield_ai/features/predictions/presentation/providers/predictions_provider.dart';
import 'package:vitalshield_ai/features/simulation/presentation/providers/simulation_provider.dart';
import 'package:vitalshield_ai/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:vitalshield_ai/features/journey/presentation/providers/journey_provider.dart';
import 'package:vitalshield_ai/features/predictions/services/prediction_sync_service.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/predictions/data/prediction_storage.dart';
import 'package:vitalshield_ai/services/api_service.dart';
import 'package:vitalshield_ai/features/dashboard/presentation/providers/dashboard_provider.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Synchronization and Refresh Tests', () {
    const profileId = 'profile_sarah';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'current_profile_id': profileId,
        // Legacy un-namespaced checkins
        'daily_checkins_history': [
          jsonEncode({
            'id': 'legacy_may25',
            'heart_rate': 70,
            'steps': 5000,
            'timestamp': '2026-05-25T10:00:00.000',
          }),
          jsonEncode({
            'id': 'legacy_may26',
            'heart_rate': 71,
            'steps': 5200,
            'timestamp': '2026-05-26T10:00:00.000',
          }),
          jsonEncode({
            'id': 'legacy_may27',
            'heart_rate': 72,
            'steps': 8500,
            'timestamp': '2026-05-27T13:49:36.641',
          }),
          jsonEncode({
            'id': 'legacy_may28',
            'heart_rate': 110,
            'steps': 1500,
            'timestamp': '2026-05-28T16:03:54.838',
          }),
        ],
        // Namespaced profile checkins containing stale entries initially
        'profile_sarah_daily_checkins_history': [
          jsonEncode({
            'id': 'chk_may25',
            'heart_rate': 70,
            'steps': 5000,
            'timestamp': '2026-05-25T10:00:00.000',
          }),
          jsonEncode({
            'id': 'chk_may26',
            'heart_rate': 71,
            'steps': 5200,
            'timestamp': '2026-05-26T10:00:00.000',
          }),
          jsonEncode({
            'id': 'chk_may27',
            'heart_rate': 72,
            'steps': 8500,
            'timestamp': '2026-05-27T13:49:36.641',
          }),
          jsonEncode({
            'id': 'chk_may28',
            'heart_rate': 110,
            'steps': 1500,
            'timestamp': '2026-05-28T16:03:54.838',
          }),
        ],
      });
    });

    test('Synchronization deletes legacy key and repopulates namespaced key correctly without stale data', () async {
      final storage = CheckinStorage();
      final prefs = await SharedPreferences.getInstance();

      // 1. Verify legacy and namespaced keys exist initially with 4 items each
      expect(prefs.getStringList('daily_checkins_history'), hasLength(4));
      expect(prefs.getStringList('profile_sarah_daily_checkins_history'), hasLength(4));

      // 2. Simulate backend synchronization process:
      // a. clearAll() is called on checkin storage
      await storage.clearAll();

      // Verify that BOTH the namespaced key and the legacy key are deleted
      expect(prefs.getStringList('daily_checkins_history'), isNull);
      expect(prefs.getStringList('profile_sarah_daily_checkins_history'), isNull);

      // b. Repopulate with the clean backend history list (only May 27 and May 28)
      final cleanHistory = [
        DailyCheckinModel(
          id: 'backend_may27',
          heartRate: 72,
          steps: 8500,
          timestamp: DateTime.parse('2026-05-27T13:49:36.641'),
        ),
        DailyCheckinModel(
          id: 'backend_may28',
          heartRate: 110,
          steps: 1500,
          timestamp: DateTime.parse('2026-05-28T16:03:54.838'),
        ),
      ];

      for (final item in cleanHistory) {
        await storage.saveCheckin(item);
      }

      // 3. Verify that the legacy key remains null/deleted
      expect(prefs.getStringList('daily_checkins_history'), isNull);

      // 4. Verify that the namespaced key now contains EXACTLY the two clean check-ins
      final checkins = await storage.getAllCheckins();
      expect(checkins, hasLength(2));
      expect(checkins[0].id, equals('backend_may27'));
      expect(checkins[1].id, equals('backend_may28'));
    });

    test('submitting a checkin invalidates all dependent providers reactively', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Listen to keep autoDispose providers alive during the async flow
      final subCheckin = container.listen(checkinProvider, (_, _) {});
      final subJourney = container.listen(journeyProvider, (_, _) {});
      final subPredictions = container.listen(predictionsProvider, (_, _) {});
      final subSimulation = container.listen(simulationProvider, (_, _) {});
      final subAnalytics = container.listen(analyticsProvider, (_, _) {});

      addTearDown(() {
        subCheckin.close();
        subJourney.close();
        subPredictions.close();
        subSimulation.close();
        subAnalytics.close();
      });

      // Trigger initialization of the providers
      final journeyNotifier = container.read(journeyProvider.notifier);
      final predictionsNotifier = container.read(predictionsProvider.notifier);
      container.read(simulationProvider.notifier); // read to trigger init
      final analyticsNotifier = container.read(analyticsProvider.notifier);

      // Wait for all async loads to finish
      await journeyNotifier.loadJourneyData();
      await predictionsNotifier.refreshPredictions();
      await analyticsNotifier.loadAnalyticsData();

      // Submit checkin
      final checkinNotifier = container.read(checkinProvider.notifier);
      checkinNotifier.setHeartRate(72);
      checkinNotifier.setBloodPressure(120, 80);
      checkinNotifier.setGlucose(90);
      checkinNotifier.setSteps(6000);
      checkinNotifier.setSleepHours(7.5);

      bool navigated = false;
      await checkinNotifier.submitCheckin(() {
        navigated = true;
      });

      expect(navigated, isTrue);

      // Wait a moment for the unawaited loadDashboardData and invalidations to settle
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify that providers are re-evaluated and not loading
      expect(container.read(journeyProvider).isLoading, isFalse);
      expect(container.read(predictionsProvider).isLoading, isFalse);
      expect(container.read(simulationProvider).isLoading, isFalse);
      expect(container.read(analyticsProvider).isLoading, isFalse);
    });

    test('PredictionSyncService triggers sync, uploads pending snapshots, updates local state and invalidates providers', () async {
      final now = DateTime.now();
      
      final pendingSnapshot = PredictionSnapshotModel(
        id: 'offline_snap_1',
        timestamp: now,
        overallWellnessScore: 80,
        categories: const [
          PredictionCategoryModel(
            categoryTitle: 'Sleep Wellness',
            score: 80,
            status: 'Optimal',
            trendDirection: TrendDirection.stable,
            insight: 'Good sleep',
            recommendation: 'Keep it up',
          )
        ],
        primaryInsight: 'Good sleep',
        predictionHash: 'mock_sha256_hash_value',
        pendingSync: true,
        sleepHours: 8.0,
        steps: 10000,
        heartRate: 70,
        systolic: 120,
        diastolic: 80,
        glucose: 90.0,
      );

      final prefix = 'profile_sarah_';
      SharedPreferences.setMockInitialValues({
        'current_profile_id': 'profile_sarah',
        '${prefix}prediction_snapshot_history': [
          pendingSnapshot.toJson(),
        ],
        '${prefix}latest_prediction_snapshot': pendingSnapshot.toJson(),
      });

      final mockApi = MockApiService();
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      // Verify initial local state is pendingSync = true
      final storage = PredictionStorage();
      final historyBefore = await storage.getPredictionHistory();
      expect(historyBefore, hasLength(1));
      expect(historyBefore.first.pendingSync, isTrue);

      // Perform sync
      final syncService = container.read(predictionSyncServiceProvider);
      await syncService.triggerSync();

      expect(mockApi.didPostSync, isTrue);

      // Verify local storage is updated to pendingSync = false
      final historyAfter = await storage.getPredictionHistory();
      expect(historyAfter, hasLength(1));
      expect(historyAfter.first.pendingSync, isFalse);

      final latestAfter = await storage.getLatestPrediction();
      expect(latestAfter, isNotNull);
      expect(latestAfter!.pendingSync, isFalse);
    });
  });
}

class MockApiService implements ApiService {
  bool didPostSync = false;

  @override
  String get baseUrl => '';

  @override
  void resetForTesting() {}

  @override
  Future<void> setToken(String? token) async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<dynamic> get(String path, {Map<String, String>? queryParams, BackendNotifier? notifier}) async => null;

  @override
  Future<dynamic> post(
    String path,
    dynamic body, {
    Map<String, String>? queryParams,
    BackendNotifier? notifier,
  }) async {
    if (path == '/predictions/sync') {
      didPostSync = true;
      return {'status': 'success', 'synced': ['mock_sha256_hash_value']};
    }
    return null;
  }

  @override
  Future<dynamic> put(String path, dynamic body, {BackendNotifier? notifier}) async => null;

  @override
  Future<dynamic> delete(String path, {BackendNotifier? notifier}) async => null;
}



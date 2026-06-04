import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/user_model.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../../../checkin/data/local/checkin_storage.dart';
import '../../../predictions/data/prediction_storage.dart';
import '../../../predictions/domain/models/prediction_model.dart';
import '../../../predictions/services/prediction_engine_service.dart';


/// State representing Dashboard contents.
class DashboardState {
  final UserModel? user;
  final DailyCheckinModel? latestCheckin;
  final int healthScore;
  final String primaryInsight;
  final bool hasCheckedInToday;
  final bool isLoading;

  const DashboardState({
    this.user,
    this.latestCheckin,
    this.healthScore = 70, // Base default score
    this.primaryInsight = 'Complete a check-in to generate wellness insights.',
    this.hasCheckedInToday = false,
    this.isLoading = true,
  });

  DashboardState copyWith({
    UserModel? user,
    DailyCheckinModel? latestCheckin,
    int? healthScore,
    String? primaryInsight,
    bool? hasCheckedInToday,
    bool? isLoading,
  }) {
    return DashboardState(
      user: user ?? this.user,
      latestCheckin: latestCheckin ?? this.latestCheckin,
      healthScore: healthScore ?? this.healthScore,
      primaryInsight: primaryInsight ?? this.primaryInsight,
      hasCheckedInToday: hasCheckedInToday ?? this.hasCheckedInToday,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// State notifier managing dashboard updates, reading from both CheckinStorage and PredictionStorage.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;
  final StorageService _userService = StorageService();
  final CheckinStorage _checkinStorage = CheckinStorage();
  final PredictionStorage _predictionStorage = PredictionStorage();

  DashboardNotifier(this._ref) : super(const DashboardState()) {
    loadDashboardData();
  }

  /// Reload all stored parameters and pull the latest Prediction Engine insights.
  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final user = await _userService.loadUser();
      final activeId = await _userService.getCurrentProfileId();
      final isOffline = _ref.read(backendProvider).isOffline;

      // Lazy-load/sync check-in history for this specific profile if online
      if (activeId != null && !isOffline) {
        try {
          final apiService = ApiService();
          final List<dynamic>? historyList = await apiService.get(
            '/checkins/history',
            queryParams: {'profile_id': activeId},
          );

          if (historyList != null) {
            // Re-populate local scoped storage with backend check-in history
            await _checkinStorage.clearAll();
            for (final item in historyList) {
              final cMap = item as Map<String, dynamic>;
              // Construct DailyCheckinModel from backend response
              final checkinModel = DailyCheckinModel(
                id: cMap['id'].toString(),
                heartRate: cMap['heart_rate'],
                systolic: cMap['systolic'],
                diastolic: cMap['diastolic'],
                glucose: (cMap['glucose'] as num?)?.toDouble(),
                steps: cMap['steps'],
                sleepHours: (cMap['sleep_hours'] as num?)?.toDouble(),
                timestamp: cMap['timestamp'] != null ? DateTime.parse(cMap['timestamp']) : null,
              );
              await _checkinStorage.saveCheckin(checkinModel);
            }
          }
        } catch (syncErr) {
          debugPrint('Error lazy-syncing check-in history for profile $activeId: $syncErr');
        }
      }

      final latestCheckin = await _checkinStorage.getLatestCheckin();
      final hasCheckedIn = await _checkinStorage.hasCheckedInToday();
      final history = await _checkinStorage.getAllCheckins();
      
      if (latestCheckin != null && history.isNotEmpty) {
        final engine = PredictionEngineService();
        final prediction = await engine.generatePrediction(
          history,
          age: user?.age,
          ageCategory: user?.ageCategory,
          gender: user?.gender,
          isOffline: isOffline,
        );
        await _predictionStorage.savePredictionSnapshot(prediction);
        
        if (mounted) {
          state = DashboardState(
            user: user,
            latestCheckin: latestCheckin,
            healthScore: prediction.overallWellnessScore,
            primaryInsight: prediction.primaryInsight,
            hasCheckedInToday: hasCheckedIn,
            isLoading: false,
          );
        }
      } else {
        if (mounted) {
          state = DashboardState(
            user: user,
            latestCheckin: null,
            healthScore: 70,
            primaryInsight: 'Complete your first daily check-in to unlock dynamic insights.',
            hasCheckedInToday: hasCheckedIn,
            isLoading: false,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Error in loadDashboardData: $e\n$stack');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          primaryInsight: 'Temporary connection issue. Re-try check-in or reconnect to backend.',
        );
      }
    }
  }

  /// Helper to manually clear history for testing/resetting
  Future<void> clearHistory() async {
    await _checkinStorage.clearAll();
    await _predictionStorage.clearAll();
    await loadDashboardData();
  }

  /// Inject high-quality realistic seed data to make local QA/testing seamless.
  Future<void> injectTestData() async {
    state = state.copyWith(isLoading: true);
    final now = DateTime.now();
    await _checkinStorage.clearAll();
    await _predictionStorage.clearAll();
    
    final checkins = [
      DailyCheckinModel(
        id: 'chk_1',
        heartRate: 74,
        systolic: 121,
        diastolic: 81,
        glucose: 89.2,
        steps: 6200,
        sleepHours: 6.8,
        timestamp: now.subtract(const Duration(days: 4)),
      ),
      DailyCheckinModel(
        id: 'chk_2',
        heartRate: 71,
        systolic: 119,
        diastolic: 79,
        glucose: 87.5,
        steps: 8400,
        sleepHours: 7.2,
        timestamp: now.subtract(const Duration(days: 3)),
      ),
      DailyCheckinModel(
        id: 'chk_3',
        heartRate: 68,
        systolic: 118,
        diastolic: 78,
        glucose: 86.0,
        steps: 9500,
        sleepHours: 7.8,
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      DailyCheckinModel(
        id: 'chk_4',
        heartRate: 72,
        systolic: 120,
        diastolic: 80,
        glucose: 88.0,
        steps: 8100,
        sleepHours: 7.5,
        timestamp: now.subtract(const Duration(days: 1)),
      ),
      DailyCheckinModel(
        id: 'chk_5',
        heartRate: 69,
        systolic: 117,
        diastolic: 77,
        glucose: 84.5,
        steps: 10200,
        sleepHours: 8.0,
        timestamp: now,
      ),
    ];
    
    for (final c in checkins) {
      await _checkinStorage.saveCheckin(c);
    }
    
    final prediction = PredictionSnapshotModel(
      id: 'pred_demo',
      timestamp: now,
      overallWellnessScore: 88,
      categories: const [
        PredictionCategoryModel(
          categoryTitle: 'Sleep Wellness',
          score: 92,
          status: 'Optimal',
          trendDirection: TrendDirection.improving,
          insight: 'Your sleep duration averaged 8 hours last night and shows a very consistent schedule.',
          recommendation: 'Keep maintaining your current wind-down routine.',
        ),
        PredictionCategoryModel(
          categoryTitle: 'Activity Wellness',
          score: 85,
          status: 'Consistent',
          trendDirection: TrendDirection.improving,
          insight: 'Step count exceeded 10,000 steps today, trending upward over the past week.',
          recommendation: 'Maintain a baseline of 8,000 steps daily.',
        ),
        PredictionCategoryModel(
          categoryTitle: 'Heart Wellness',
          score: 89,
          status: 'Optimal',
          trendDirection: TrendDirection.stable,
          insight: 'Resting heart rate remains stable around 69 BPM.',
          recommendation: 'Continue aerobic exercises twice a week.',
        ),
        PredictionCategoryModel(
          categoryTitle: 'Blood Pressure Wellness',
          score: 87,
          status: 'Consistent',
          trendDirection: TrendDirection.stable,
          insight: 'Blood pressure is stable at 117/77 mmHg.',
          recommendation: 'Continue regular checks and low-sodium choices.',
        ),
        PredictionCategoryModel(
          categoryTitle: 'Glucose Wellness',
          score: 90,
          status: 'Optimal',
          trendDirection: TrendDirection.stable,
          insight: 'Fasting glucose is optimal at 84.5 mg/dL.',
          recommendation: 'Maintain current complex carbohydrate balance.',
        ),
      ],
      primaryInsight: 'Overall wellness is high. Your consistent rest schedule and increased step count are driving positive trends in blood pressure and heart rate recovery.',
    );
    
    await _predictionStorage.savePredictionSnapshot(prediction);
    await loadDashboardData();
  }
}

/// Riverpod provider for DashboardState
final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});

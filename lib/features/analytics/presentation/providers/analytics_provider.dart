import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../checkin/data/local/checkin_storage.dart';
import '../../../predictions/data/prediction_storage.dart';
import '../../domain/models/trend_data_model.dart';
import '../../domain/services/analytics_engine.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';

class AnalyticsState {
  final bool isLoading;
  final bool hasEnoughData;
  final AnalyticsReport? report;

  const AnalyticsState({
    this.isLoading = true,
    this.hasEnoughData = false,
    this.report,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    bool? hasEnoughData,
    AnalyticsReport? report,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      hasEnoughData: hasEnoughData ?? this.hasEnoughData,
      report: report ?? this.report,
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final CheckinStorage _checkinStorage = CheckinStorage();
  final PredictionStorage _predictionStorage = PredictionStorage();
  final StorageService _storageService = StorageService();

  AnalyticsNotifier() : super(const AnalyticsState()) {
    loadAnalyticsData();
  }

  /// Fetch check-ins and predictions to build the report
  Future<void> loadAnalyticsData() async {
    state = state.copyWith(isLoading: true);

    // Try fetching from the backend first
    final profileId = await _storageService.getCurrentProfileId();
    if (profileId != null) {
      try {
        final api = ApiService();
        final response = await api.get(
          '/analytics/report',
          queryParams: {'profile_id': profileId},
        );
        if (response != null && response is Map<String, dynamic>) {
          final hasEnoughData = response['hasEnoughData'] as bool? ?? false;
          if (hasEnoughData && response['report'] != null) {
            final report = AnalyticsReport.fromMap(response['report'] as Map<String, dynamic>);
            if (mounted) {
              state = AnalyticsState(
                isLoading: false,
                hasEnoughData: true,
                report: report,
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to load analytics from backend: $e. Falling back to local analytics generation.');
      }
    }
    
    final checkins = await _checkinStorage.getAllCheckins();
    final predictions = await _predictionStorage.getPredictionHistory();

    // Load user profile for personalized insight language
    final user = await _storageService.loadUser();

    // Require at least 1 check-in to begin analytics and trend reporting
    final hasEnough = checkins.isNotEmpty;

    if (hasEnough) {
      final report = AnalyticsEngine.generateReport(
        checkins: checkins,
        predictions: predictions,
        ageCategory: user?.ageCategory,
        gender: user?.gender,
      );
      if (mounted) {
        state = AnalyticsState(
          isLoading: false,
          hasEnoughData: true,
          report: report,
        );
      }
    } else {
      if (mounted) {
        state = const AnalyticsState(
          isLoading: false,
          hasEnoughData: false,
          report: null,
        );
      }
    }
  }
}

final analyticsProvider = StateNotifierProvider.autoDispose<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier();
});

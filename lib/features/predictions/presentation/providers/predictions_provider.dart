import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/prediction_storage.dart';
import '../../domain/models/prediction_model.dart';
import '../../services/prediction_engine_service.dart';
import '../../../checkin/data/local/checkin_storage.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';

class PredictionsState {
  final PredictionSnapshotModel? latestSnapshot;
  final bool isLoading;
  final bool hasInsufficientData;
  final bool isBackendOffline;

  const PredictionsState({
    this.latestSnapshot,
    this.isLoading = true,
    this.hasInsufficientData = false,
    this.isBackendOffline = false,
  });

  PredictionsState copyWith({
    PredictionSnapshotModel? latestSnapshot,
    bool? isLoading,
    bool? hasInsufficientData,
    bool? isBackendOffline,
  }) {
    return PredictionsState(
      latestSnapshot: latestSnapshot ?? this.latestSnapshot,
      isLoading: isLoading ?? this.isLoading,
      hasInsufficientData: hasInsufficientData ?? this.hasInsufficientData,
      isBackendOffline: isBackendOffline ?? this.isBackendOffline,
    );
  }
}

class PredictionsNotifier extends StateNotifier<PredictionsState> {
  final Ref _ref;
  final CheckinStorage _checkinStorage = CheckinStorage();
  final PredictionStorage _predictionStorage = PredictionStorage();
  final PredictionEngineService _engineService = PredictionEngineService();
  final StorageService _storageService = StorageService();

  PredictionsNotifier(this._ref) : super(const PredictionsState()) {
    _initEngine();
  }

  Future<void> _initEngine() async {
    if (mounted) state = state.copyWith(isLoading: true);

    try {
      // 1. Pull latest check-in history
      final history = await _checkinStorage.getAllCheckins();

      // 2. Handle empty state gracefully
      if (history.isEmpty) {
        if (mounted) {
          state = state.copyWith(
            latestSnapshot: null,
            isLoading: false,
            hasInsufficientData: true,
            isBackendOffline: false,
          );
        }
        return;
      }

      // 3. Load user profile for personalized prediction context
      final user = await _storageService.loadUser();

      // 4. Process prediction logic via the Engine with user demographics
      final isOffline = _ref.read(backendProvider).isOffline;
      final snapshot = await _engineService.generatePrediction(
        history,
        age: user?.age,
        ageCategory: user?.ageCategory,
        gender: user?.gender,
        isOffline: isOffline,
      );

      // 5. Save prediction snapshots locally
      await _predictionStorage.savePredictionSnapshot(snapshot);

      // 6. Update state with backend status
      if (mounted) {
        state = state.copyWith(
           latestSnapshot: snapshot,
           isLoading: false,
           hasInsufficientData: false,
           isBackendOffline: _engineService.isBackendOffline,
        );
      }
    } catch (e, stack) {
      debugPrint('Error in PredictionsNotifier._initEngine: $e\n$stack');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isBackendOffline: true,
        );
      }
    }
  }

  /// Manually triggers a re-run of the prediction engine.
  Future<void> refreshPredictions() async {
    await _initEngine();
  }
}

final predictionsProvider = StateNotifierProvider.autoDispose<PredictionsNotifier, PredictionsState>((ref) {
  return PredictionsNotifier(ref);
});

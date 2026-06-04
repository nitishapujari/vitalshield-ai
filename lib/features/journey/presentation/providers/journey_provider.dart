import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../checkin/data/local/checkin_storage.dart';
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../../../predictions/data/prediction_storage.dart';
import '../../../predictions/domain/models/prediction_model.dart';

class JourneyState {
  final List<DailyCheckinModel> checkins;
  final List<PredictionSnapshotModel> predictions;
  final bool isLoading;

  const JourneyState({
    this.checkins = const [],
    this.predictions = const [],
    this.isLoading = true,
  });

  JourneyState copyWith({
    List<DailyCheckinModel>? checkins,
    List<PredictionSnapshotModel>? predictions,
    bool? isLoading,
  }) {
    return JourneyState(
      checkins: checkins ?? this.checkins,
      predictions: predictions ?? this.predictions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class JourneyNotifier extends StateNotifier<JourneyState> {
  final CheckinStorage _checkinStorage = CheckinStorage();
  final PredictionStorage _predictionStorage = PredictionStorage();

  JourneyNotifier() : super(const JourneyState()) {
    loadJourneyData();
  }

  Future<void> loadJourneyData() async {
    state = state.copyWith(isLoading: true);
    try {
      final checkins = await _checkinStorage.getAllCheckins();
      final predictions = await _predictionStorage.getPredictionHistory();
      if (mounted) {
        state = JourneyState(
          checkins: checkins,
          predictions: predictions,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          checkins: const [],
          predictions: const [],
        );
      }
    }
  }
}

final journeyProvider = StateNotifierProvider.autoDispose<JourneyNotifier, JourneyState>((ref) {
  return JourneyNotifier();
});

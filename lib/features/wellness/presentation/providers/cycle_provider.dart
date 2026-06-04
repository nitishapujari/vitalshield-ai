import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/cycle_storage.dart';
import '../../domain/models/cycle_model.dart';

class CycleState {
  final CycleData data;
  final bool isLoading;

  const CycleState({
    this.data = const CycleData(),
    this.isLoading = false,
  });

  CycleState copyWith({
    CycleData? data,
    bool? isLoading,
  }) {
    return CycleState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CycleNotifier extends StateNotifier<CycleState> {
  final CycleStorage _storage = CycleStorage();

  CycleNotifier() : super(const CycleState()) {
    _loadData();
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoading: true);
    final data = await _storage.loadCycleData();
    state = state.copyWith(data: data, isLoading: false);
  }

  Future<void> toggleTracking(bool enabled) async {
    final updated = state.data.copyWith(
      isTrackingEnabled: enabled,
      // If toggling on, set start date to today as default if none set yet
      lastCycleStart: enabled && state.data.lastCycleStart == null
          ? DateTime.now()
          : state.data.lastCycleStart,
    );
    state = state.copyWith(data: updated);
    await _storage.saveCycleData(updated);
  }

  Future<void> updateStartDate(DateTime date) async {
    final updated = state.data.copyWith(lastCycleStart: date);
    state = state.copyWith(data: updated);
    await _storage.saveCycleData(updated);
  }

  Future<void> updateLength(int length) async {
    final updated = state.data.copyWith(averageCycleLength: length);
    state = state.copyWith(data: updated);
    await _storage.saveCycleData(updated);
  }
}

final cycleProvider = StateNotifierProvider<CycleNotifier, CycleState>((ref) {
  return CycleNotifier();
});

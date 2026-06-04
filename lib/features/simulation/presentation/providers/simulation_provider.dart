import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../checkin/data/local/checkin_storage.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/simulation_model.dart';
import '../../domain/services/simulation_engine.dart';

class SimulationState {
  final SimulationInput input;
  final SimulationResult? result;
  final bool isLoading;
  final bool isBackendOffline;

  const SimulationState({
    this.input = const SimulationInput(),
    this.result,
    this.isLoading = false,
    this.isBackendOffline = false,
  });

  SimulationState copyWith({
    SimulationInput? input,
    SimulationResult? result,
    bool? isLoading,
    bool? isBackendOffline,
  }) {
    return SimulationState(
      input: input ?? this.input,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      isBackendOffline: isBackendOffline ?? this.isBackendOffline,
    );
  }
}

class SimulationNotifier extends StateNotifier<SimulationState> {
  final SimulationEngine _engine = SimulationEngine();
  final CheckinStorage _checkinStorage = CheckinStorage();
  final StorageService _storageService = StorageService();

  SimulationNotifier() : super(const SimulationState()) {
    _initInputAndRun();
  }

  Future<void> _initInputAndRun() async {
    state = state.copyWith(isLoading: true);
    final latest = await _checkinStorage.getLatestCheckin();
    final initialInput = SimulationInput(
      sleepHours: latest?.sleepHours ?? 7.0,
      steps: latest?.steps ?? 5000,
      consistencyLevel: 50.0,
      routineQuality: 50.0,
    );
    state = state.copyWith(input: initialInput);
    await runSimulation(initialInput);
  }

  Future<void> runSimulation(SimulationInput input) async {
    state = state.copyWith(input: input, isLoading: true);

    final history = await _checkinStorage.getAllCheckins();
    final user = await _storageService.loadUser();

    final result = await _engine.simulate(
      input,
      history: history,
      ageCategory: user?.ageCategory,
    );

    state = state.copyWith(
      result: result,
      isLoading: false,
      isBackendOffline: _engine.isBackendOffline,
    );
  }

  void updateInput({
    double? sleepHours,
    int? steps,
    double? consistencyLevel,
    double? routineQuality,
  }) {
    final newInput = state.input.copyWith(
      sleepHours: sleepHours,
      steps: steps,
      consistencyLevel: consistencyLevel,
      routineQuality: routineQuality,
    );
    runSimulation(newInput);
  }
}

final simulationProvider =
    StateNotifierProvider.autoDispose<SimulationNotifier, SimulationState>((ref) {
  return SimulationNotifier();
});

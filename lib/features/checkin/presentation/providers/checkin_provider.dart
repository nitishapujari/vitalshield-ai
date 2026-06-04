import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/daily_checkin_model.dart';
import '../../data/local/checkin_storage.dart';
import '../../../../core/constants/metric_ranges.dart';
import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../predictions/presentation/providers/predictions_provider.dart';
import '../../../simulation/presentation/providers/simulation_provider.dart';
import '../../../analytics/presentation/providers/analytics_provider.dart';
import '../../../journey/presentation/providers/journey_provider.dart';

/// State of the daily check-in flow.
class CheckinState {
  final int currentStep;
  final int? heartRate;
  final int? systolic;
  final int? diastolic;
  final double? glucose;
  final int? steps;
  final double? sleepHours;
  final bool isAnalyzing;
  final bool isCompleted;
  final String? validationError;
  final bool syncFailed;

  const CheckinState({
    this.currentStep = 0,
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.glucose,
    this.steps = 8000, // initialized to a standard starting step count
    this.sleepHours = 7.0, // initialized to a standard sleep hour
    this.isAnalyzing = false,
    this.isCompleted = false,
    this.validationError,
    this.syncFailed = false,
  });

  CheckinState copyWith({
    int? currentStep,
    int? heartRate,
    int? systolic,
    int? diastolic,
    double? glucose,
    int? steps,
    double? sleepHours,
    bool? isAnalyzing,
    bool? isCompleted,
    String? validationError,
    bool? syncFailed,
  }) {
    return CheckinState(
      currentStep: currentStep ?? this.currentStep,
      heartRate: heartRate ?? this.heartRate,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      glucose: glucose ?? this.glucose,
      steps: steps ?? this.steps,
      sleepHours: sleepHours ?? this.sleepHours,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isCompleted: isCompleted ?? this.isCompleted,
      validationError: validationError, // allows setting to null
      syncFailed: syncFailed ?? this.syncFailed,
    );
  }
}

/// State notifier for the Daily Check-In flow.
class CheckinNotifier extends StateNotifier<CheckinState> {
  final Ref? _ref;
  final CheckinStorage _storage = CheckinStorage();

  CheckinNotifier([this._ref]) : super(const CheckinState());

  void setHeartRate(int? val) {
    state = state.copyWith(heartRate: val, validationError: null);
  }

  void setBloodPressure(int? sys, int? dia) {
    state = state.copyWith(systolic: sys, diastolic: dia, validationError: null);
  }

  void setGlucose(double? val) {
    state = state.copyWith(glucose: val, validationError: null);
  }

  void setSteps(int? val) {
    state = state.copyWith(steps: val, validationError: null);
  }

  void setSleepHours(double? val) {
    state = state.copyWith(sleepHours: val, validationError: null);
  }

  /// Soft validation for the current step's input
  bool validateCurrentStep() {
    switch (state.currentStep) {
      case 0:
        final hr = state.heartRate;
        if (hr == null || hr < MetricRanges.minHeartRate || hr > MetricRanges.maxHeartRate) {
          state = state.copyWith(validationError: 'Please enter a valid value');
          return false;
        }
        break;
      case 1:
        final sys = state.systolic;
        final dia = state.diastolic;
        if (sys == null || sys < MetricRanges.minSystolic || sys > MetricRanges.maxSystolic ||
            dia == null || dia < MetricRanges.minDiastolic || dia > MetricRanges.maxDiastolic) {
          state = state.copyWith(validationError: 'Please enter a valid value');
          return false;
        }
        break;
      case 2:
        final glu = state.glucose;
        if (glu == null || glu < MetricRanges.minGlucose || glu > MetricRanges.maxGlucose) {
          state = state.copyWith(validationError: 'Please enter a valid value');
          return false;
        }
        break;
      case 3:
        final st = state.steps;
        if (st == null || st < MetricRanges.minSteps || st > MetricRanges.maxSteps) {
          state = state.copyWith(validationError: 'Please enter a valid value');
          return false;
        }
        break;
      case 4:
        final sl = state.sleepHours;
        if (sl == null || sl < MetricRanges.minSleep || sl > MetricRanges.maxSleep) {
          state = state.copyWith(validationError: 'Please enter a valid value');
          return false;
        }
        break;
    }
    state = state.copyWith(validationError: null);
    return true;
  }

  /// Go to next step or submit if it's the last step
  Future<void> nextStep(Function() onCompleteNavigation) async {
    if (state.isAnalyzing || state.isCompleted) return;
    if (!validateCurrentStep()) return;

    if (state.currentStep < 4) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    } else {
      await submitCheckin(onCompleteNavigation);
    }
  }

  /// Go to previous step
  void previousStep() {
    if (state.isAnalyzing || state.isCompleted) return;
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        validationError: null,
      );
    }
  }

  /// Save check-in details and trigger mock analysis transition
  Future<void> submitCheckin(Function() onCompleteNavigation) async {
    if (state.isAnalyzing || state.isCompleted) return;
    state = state.copyWith(isAnalyzing: true);

    // Subtle breathing transition delay
    await Future.delayed(const Duration(milliseconds: 2500));

    final now = DateTime.now();

    final checkin = DailyCheckinModel(
      id: now.millisecondsSinceEpoch.toString(),
      heartRate: state.heartRate,
      systolic: state.systolic,
      diastolic: state.diastolic,
      glucose: state.glucose,
      steps: state.steps,
      sleepHours: state.sleepHours,
      timestamp: now,
    );

    // Save to SharedPreferences
    await _storage.saveCheckin(checkin);

    // Sync to backend DB if online
    bool syncFailed = false;
    if (_ref != null) {
      try {
        final apiService = _ref.read(apiServiceProvider);
        final profileId = await StorageService().getCurrentProfileId();
        if (profileId != null) {
          await apiService.post(
            '/checkins/create',
            {
              'sleep_hours': checkin.sleepHours,
              'steps': checkin.steps,
              'heart_rate': checkin.heartRate,
              'systolic': checkin.systolic,
              'diastolic': checkin.diastolic,
              'glucose': checkin.glucose,
              'timestamp': checkin.timestamp?.toIso8601String(),
            },
            queryParams: {'profile_id': profileId},
            notifier: _ref.read(backendProvider.notifier),
          );
        }
      } catch (e) {
        // Fallback silently if offline
        // ApiService will automatically mark backend as offline
        debugPrint('Check-in remote sync failed, using offline fallback: $e');
        syncFailed = true;
      }
    }

    // Move to completed feedback screen
    state = state.copyWith(isAnalyzing: false, isCompleted: true, syncFailed: syncFailed);

    // Show emotional completion state for ~1 second
    await Future.delayed(const Duration(milliseconds: 1200));

    // Force dashboard, predictions, simulation, analytics, and journey data refresh
    if (_ref != null) {
      _ref.read(dashboardProvider.notifier).loadDashboardData();
      _ref.invalidate(predictionsProvider);
      _ref.invalidate(simulationProvider);
      _ref.invalidate(analyticsProvider);
      _ref.invalidate(journeyProvider);
    }

    // Call navigation callback first
    onCompleteNavigation();

    // Reset flow state if still active
    if (mounted) {
      state = const CheckinState();
    }
  }

  /// Resets state (e.g. when exiting checkin)
  void reset() {
    state = const CheckinState();
  }
}

/// Riverpod provider for check-in state
final checkinProvider = StateNotifierProvider.autoDispose<CheckinNotifier, CheckinState>((ref) {
  return CheckinNotifier(ref);
});

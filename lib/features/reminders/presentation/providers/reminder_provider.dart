import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reminder_storage.dart';
import '../../domain/models/reminder_model.dart';
import '../../domain/services/reminder_service.dart';

class ReminderState {
  final ReminderSettings settings;
  final bool isLoading;

  const ReminderState({
    this.settings = const ReminderSettings(),
    this.isLoading = false,
  });

  ReminderState copyWith({
    ReminderSettings? settings,
    bool? isLoading,
  }) {
    return ReminderState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ReminderNotifier extends StateNotifier<ReminderState> {
  final ReminderStorage _storage = ReminderStorage();
  final ReminderService _service = ReminderService();

  ReminderNotifier() : super(const ReminderState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    final settings = await _storage.loadSettings();
    state = state.copyWith(settings: settings, isLoading: false);
    await _service.syncReminders(settings);
  }

  Future<void> _saveAndSync(ReminderSettings updated) async {
    state = state.copyWith(settings: updated);
    await _storage.saveSettings(updated);
    await _service.syncReminders(updated);
  }

  Future<void> toggleMute(bool val) async {
    final updated = state.settings.copyWith(isMuted: val);
    await _saveAndSync(updated);
  }

  Future<void> toggleCheckIn(bool val) async {
    final updated = state.settings.copyWith(checkInEnabled: val);
    await _saveAndSync(updated);
  }

  Future<void> updateCheckInTime(int hour, int minute) async {
    final updated = state.settings.copyWith(checkInHour: hour, checkInMinute: minute);
    await _saveAndSync(updated);
  }

  Future<void> toggleHydration(bool val) async {
    final updated = state.settings.copyWith(hydrationEnabled: val);
    await _saveAndSync(updated);
  }

  Future<void> updateHydrationInterval(int hours) async {
    final updated = state.settings.copyWith(hydrationIntervalHours: hours);
    await _saveAndSync(updated);
  }

  Future<void> toggleSleep(bool val) async {
    final updated = state.settings.copyWith(sleepEnabled: val);
    await _saveAndSync(updated);
  }

  Future<void> updateSleepTime(int hour, int minute) async {
    final updated = state.settings.copyWith(sleepHour: hour, sleepMinute: minute);
    await _saveAndSync(updated);
  }

  Future<void> toggleRhythm(bool val) async {
    final updated = state.settings.copyWith(rhythmEnabled: val);
    await _saveAndSync(updated);
  }

  Future<void> updateRhythmTime(int hour, int minute) async {
    final updated = state.settings.copyWith(rhythmHour: hour, rhythmMinute: minute);
    await _saveAndSync(updated);
  }

  Future<void> toggleMovement(bool val) async {
    final updated = state.settings.copyWith(movementEnabled: val);
    await _saveAndSync(updated);
  }

  Future<void> updateMovementInterval(int hours) async {
    final updated = state.settings.copyWith(movementIntervalHours: hours);
    await _saveAndSync(updated);
  }
}

final reminderProvider = StateNotifierProvider<ReminderNotifier, ReminderState>((ref) {
  return ReminderNotifier();
});

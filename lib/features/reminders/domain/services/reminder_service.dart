import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reminder_model.dart';

/// Handles background notification scheduling logic.
/// For cross-platform stability (Windows/Android/Web), this logs scheduling
/// details and serves as a direct integration point for local OS notifications.
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;

  ReminderService._internal();

  final List<String> _scheduledTasks = [];

  List<String> get scheduledTasks => List.unmodifiable(_scheduledTasks);

  /// Synchronizes scheduled timers with the active settings.
  Future<void> syncReminders(ReminderSettings settings) async {
    _scheduledTasks.clear();

    if (settings.isMuted) {
      if (kDebugMode) {
        print('[ReminderService] All wellness reminders muted.');
      }
      return;
    }

    if (settings.checkInEnabled) {
      final timeStr = _formatTime(settings.checkInHour, settings.checkInMinute);
      _scheduledTasks.add('Check-in Reminder ($timeStr)');
      _scheduleMockNotification(
        'Daily Check-in',
        'Take a quiet moment to record your wellness metrics today.',
        settings.checkInHour,
        settings.checkInMinute,
      );
    }

    if (settings.hydrationEnabled) {
      _scheduledTasks.add('Hydration Reminder (Every ${settings.hydrationIntervalHours}h)');
      _scheduleMockIntervalNotification(
        'Hydration Pause',
        'Enjoy a cool glass of water to support metabolic clarity.',
        settings.hydrationIntervalHours,
      );
    }

    if (settings.sleepEnabled) {
      final timeStr = _formatTime(settings.sleepHour, settings.sleepMinute);
      _scheduledTasks.add('Sleep Wind-down ($timeStr)');
      _scheduleMockNotification(
        'Evening Wind-down',
        'Time to set aside screens and begin a calming resting routine.',
        settings.sleepHour,
        settings.sleepMinute,
      );
    }

    if (settings.rhythmEnabled) {
      final timeStr = _formatTime(settings.rhythmHour, settings.rhythmMinute);
      _scheduledTasks.add('Wellness Rhythm ($timeStr)');
      _scheduleMockNotification(
        'Wellness Rhythm Update',
        'Check your custom energetic phase guidance for the day.',
        settings.rhythmHour,
        settings.rhythmMinute,
      );
    }

    if (settings.movementEnabled) {
      _scheduledTasks.add('Movement Reminder (Every ${settings.movementIntervalHours}h)');
      _scheduleMockIntervalNotification(
        'Gentle Stretch',
        'Stand up and take a brief 2-minute walk to release tension.',
        settings.movementIntervalHours,
      );
    }

    if (kDebugMode) {
      print('[ReminderService] Reminders synced: $_scheduledTasks');
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scheduleMockNotification(String title, String body, int hour, int minute) {
    if (kDebugMode) {
      print('[ReminderService] Scheduled notification: "$title" at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} daily. Body: $body');
    }
  }

  void _scheduleMockIntervalNotification(String title, String body, int intervalHours) {
    if (kDebugMode) {
      print('[ReminderService] Scheduled interval notification: "$title" every $intervalHours hours. Body: $body');
    }
  }
}

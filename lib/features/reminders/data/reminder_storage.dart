import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/reminder_model.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';

class ReminderStorage {
  static const String _key = 'user_reminder_settings';
  final StorageService _storage = StorageService();

  Future<String> _getKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_key';
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final settingsJson = jsonEncode(settings.toJson());
    await prefs.setString(key, settingsJson);

    // Sync to backend DB
    try {
      final profileId = await _storage.getCurrentProfileId();
      if (profileId != null) {
        final apiService = ApiService();
        await apiService.post(
          '/preferences/reminders',
          {
            'settings_json': settingsJson,
          },
          queryParams: {'profile_id': profileId},
        );
      }
    } catch (e) {
      // Fallback silently if offline
      debugPrint('Reminder sync to backend failed, using offline fallback: $e');
    }
  }

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();

    // First try fetching from backend if possible
    try {
      final profileId = await _storage.getCurrentProfileId();
      if (profileId != null) {
        final apiService = ApiService();
        final response = await apiService.get(
          '/preferences/reminders',
          queryParams: {'profile_id': profileId},
        );
        if (response != null && response['settings_json'] != null) {
          final settingsJson = response['settings_json'] as String;
          if (settingsJson.isNotEmpty && settingsJson != '{}') {
            // Update local storage so they match
            await prefs.setString(key, settingsJson);
            final decoded = jsonDecode(settingsJson);
            if (decoded is Map<String, dynamic>) {
              return ReminderSettings.fromJson(decoded);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Reminder load from backend failed, using offline fallback: $e');
    }

    final data = prefs.getString(key);
    if (data == null) {
      return const ReminderSettings();
    }
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return ReminderSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const ReminderSettings();
  }
}


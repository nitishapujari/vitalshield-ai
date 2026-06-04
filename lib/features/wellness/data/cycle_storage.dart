import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/cycle_model.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';

class CycleStorage {
  static const String _cycleKey = 'user_cycle_wellness_data';
  final StorageService _storage = StorageService();

  Future<String> _getKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_cycleKey';
  }

  /// Save cycle rhythm details
  Future<void> saveCycleData(CycleData data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    final dataJson = jsonEncode(data.toJson());
    await prefs.setString(key, dataJson);

    // Sync to backend DB
    try {
      final profileId = await _storage.getCurrentProfileId();
      if (profileId != null) {
        final apiService = ApiService();
        await apiService.post(
          '/preferences/cycle',
          {
            'settings_json': dataJson,
          },
          queryParams: {'profile_id': profileId},
        );
      }
    } catch (e) {
      // Fallback silently if offline
      debugPrint('Cycle sync to backend failed, using offline fallback: $e');
    }
  }

  /// Load cycle rhythm details
  Future<CycleData> loadCycleData() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();

    // First try fetching from backend if possible
    try {
      final profileId = await _storage.getCurrentProfileId();
      if (profileId != null) {
        final apiService = ApiService();
        final response = await apiService.get(
          '/preferences/cycle',
          queryParams: {'profile_id': profileId},
        );
        if (response != null && response['settings_json'] != null) {
          final settingsJson = response['settings_json'] as String;
          if (settingsJson.isNotEmpty && settingsJson != '{}') {
            // Update local storage so they match
            await prefs.setString(key, settingsJson);
            final jsonMap = jsonDecode(settingsJson);
            if (jsonMap is Map<String, dynamic>) {
              return CycleData.fromJson(jsonMap);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Cycle load from backend failed, using offline fallback: $e');
    }

    final stringData = prefs.getString(key);
    if (stringData == null) {
      return const CycleData();
    }
    try {
      final jsonMap = jsonDecode(stringData);
      if (jsonMap is Map<String, dynamic>) {
        return CycleData.fromJson(jsonMap);
      }
    } catch (_) {}
    return const CycleData();
  }

  /// Clear cycle data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    await prefs.remove(key);
  }
}


import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/daily_checkin_model.dart';
import '../../../../services/storage_service.dart';

/// Local storage service for daily check-ins using SharedPreferences.
class CheckinStorage {
  static const String _checkinsKey = 'daily_checkins_history';
  final StorageService _storage = StorageService();

  Future<String> _getKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_checkinsKey';
  }

  /// Save a check-in record
  Future<void> saveCheckin(DailyCheckinModel checkin) async {
    final prefs = await SharedPreferences.getInstance();
    // Ensure any legacy, un-namespaced data is migrated to the profile-scoped key
    final key = await _getKey();
    final legacyList = prefs.getStringList(_checkinsKey);
    final existingList = prefs.getStringList(key) ?? [];

    // If legacy list exists and scoped list is empty, migrate it
    final merged = <String>[];
    if (existingList.isEmpty && legacyList != null && legacyList.isNotEmpty) {
      merged.addAll(legacyList);
      await prefs.remove(_checkinsKey); // Purge stale unprefixed records to prevent re-migration
    } else {
      merged.addAll(existingList);
    }

    final incomingDate = checkin.timestamp ?? DateTime.now();
    int existingIndex = -1;

    for (int i = 0; i < merged.length; i++) {
      try {
        final decoded = jsonDecode(merged[i]);
        if (decoded is Map<String, dynamic>) {
          final existingCheckin = DailyCheckinModel.fromJson(decoded);
          if (existingCheckin.timestamp != null) {
            final t = existingCheckin.timestamp!;
            if (t.year == incomingDate.year &&
                t.month == incomingDate.month &&
                t.day == incomingDate.day) {
              existingIndex = i;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (existingIndex != -1) {
      merged[existingIndex] = jsonEncode(checkin.toJson());
    } else {
      merged.add(jsonEncode(checkin.toJson()));
    }
    await prefs.setStringList(key, merged);
  }

  /// Load all check-in records
  Future<List<DailyCheckinModel>> getAllCheckins() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();

    // Try namespaced (profile) key first
    var jsonList = prefs.getStringList(key);

    // If no namespaced data, but legacy unprefixed data exists, migrate it
    if ((jsonList == null || jsonList.isEmpty)) {
      final legacy = prefs.getStringList(_checkinsKey);
      if (legacy != null && legacy.isNotEmpty) {
        // Migrate legacy into profile key for consistency
        await prefs.setStringList(key, legacy);
        jsonList = legacy;
        await prefs.remove(_checkinsKey); // Purge stale unprefixed records to prevent re-migration
      }
    }

    if (jsonList == null) return [];
    
    final List<DailyCheckinModel> checkins = [];
    for (final item in jsonList) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          checkins.add(DailyCheckinModel.fromJson(decoded));
        }
      } catch (_) {
        // Skip corrupted entry gracefully to preserve remaining history
      }
    }
    return checkins;
  }

  /// Get the latest check-in record
  Future<DailyCheckinModel?> getLatestCheckin() async {
    final list = await getAllCheckins();
    if (list.isEmpty) return null;
    
    // Sort by timestamp descending
    list.sort((a, b) {
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });
    
    return list.first;
  }

  /// Check if the user has completed a check-in today
  Future<bool> hasCheckedInToday() async {
    final latest = await getLatestCheckin();
    if (latest == null || latest.timestamp == null) return false;
    
    final now = DateTime.now();
    final latestDate = latest.timestamp!;
    return latestDate.year == now.year &&
        latestDate.month == now.month &&
        latestDate.day == now.day;
  }

  /// Clear check-in history
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getKey();
    await prefs.remove(key);
    await prefs.remove(_checkinsKey); // Also clear legacy key to ensure no stale data is re-migrated
  }
}

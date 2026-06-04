import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/data/local/checkin_storage.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';

void main() {
  test('migrates legacy unprefixed checkins into profile namespaced key', () async {
    // Prepare a legacy check-in JSON
    final legacy = [
      jsonEncode({
        'id': 'legacy_1',
        'user_id': 'u1',
        'heart_rate': 70,
        'systolic': 120,
        'diastolic': 80,
        'glucose': 90.0,
        'steps': 5000,
        'sleep_hours': 7.0,
        'timestamp': DateTime.now().toIso8601String(),
      })
    ];

    // Mock SharedPreferences initial values. current profile id will be 'profile_test'
    SharedPreferences.setMockInitialValues({
      'daily_checkins_history': legacy,
      'current_profile_id': 'profile_test',
    });

    final storage = CheckinStorage();

    // getAllCheckins should migrate legacy into namespaced key and return the item
    final all = await storage.getAllCheckins();
    expect(all, isNotEmpty);
    expect(all.first.id, equals('legacy_1'));

    // Now saving a new checkin should append to the profile-scoped list
    final newCheckin = DailyCheckinModel(
      id: 'new_1',
      heartRate: 68,
      systolic: 118,
      diastolic: 78,
      glucose: 88.5,
      steps: 7200,
      sleepHours: 7.5,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    );

    await storage.saveCheckin(newCheckin);

    final updated = await storage.getAllCheckins();
    expect(updated.length, equals(2));
    expect(updated.any((c) => c.id == 'new_1'), isTrue);
  });
}

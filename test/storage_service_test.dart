import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/models/user_model.dart';
import 'package:vitalshield_ai/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService Profile Management Tests', () {
    late StorageService storageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
    });

    test('getAllProfiles returns empty list initially', () async {
      final profiles = await storageService.getAllProfiles();
      expect(profiles, isEmpty);
    });

    test('addProfile adds a profile and sets it as active', () async {
      final user = const UserModel(
        name: 'John Doe',
        email: 'john@example.com',
        gender: 'Male',
      );

      await storageService.addProfile(user);

      final profiles = await storageService.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'John Doe');
      expect(profiles.first.id, isNotEmpty);

      final activeId = await storageService.getCurrentProfileId();
      expect(activeId, profiles.first.id);
    });

    test('heightUnit is persisted and defaults to cm', () async {
      final user = const UserModel(
        name: 'Height User',
        heightUnit: 'in',
      );

      await storageService.addProfile(user);

      final profiles = await storageService.getAllProfiles();
      final loadedHeightUser = profiles.firstWhere((p) => p.name == 'Height User');
      expect(loadedHeightUser.heightUnit, 'in');

      final defaultUser = const UserModel(name: 'Default User');
      await storageService.addProfile(defaultUser);
      final allProfiles = await storageService.getAllProfiles();
      final loadedDefault = allProfiles.firstWhere((p) => p.name == 'Default User');
      expect(loadedDefault.heightUnit, 'cm');
    });

    test('updateProfile updates profile info correctly', () async {
      final user = const UserModel(
        id: 'profile_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        gender: 'Female',
      );

      await storageService.addProfile(user);
      
      final updatedUser = user.copyWith(name: 'Jane Smith');
      await storageService.updateProfile(updatedUser);

      final profiles = await storageService.getAllProfiles();
      expect(profiles.first.name, 'Jane Smith');
    });

    test('deleteProfile removes profile, falls back to first remaining, and cleans up namespace', () async {
      final prefs = await SharedPreferences.getInstance();
      
      final user1 = const UserModel(
        id: 'profile_1',
        name: 'User One',
        gender: 'Male',
      );
      final user2 = const UserModel(
        id: 'profile_2',
        name: 'User Two',
        gender: 'Female',
      );

      await storageService.addProfile(user1);
      await storageService.addProfile(user2);

      // Save some namespaced data
      await prefs.setString('profile_1_some_data', 'value1');
      await prefs.setString('profile_2_some_data', 'value2');

      // Verify active is profile_2 (added last)
      expect(await storageService.getCurrentProfileId(), 'profile_2');

      // Delete active profile_2
      await storageService.deleteProfile('profile_2');

      final profiles = await storageService.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.id, 'profile_1');

      // Verify active falls back to profile_1
      expect(await storageService.getCurrentProfileId(), 'profile_1');

      // Verify prefix namespaces are cleaned up
      expect(prefs.containsKey('profile_2_some_data'), isFalse);
      expect(prefs.containsKey('profile_1_some_data'), isTrue);
    });

    test('migrateIfNeeded successfully migrates legacy user data', () async {
      final prefs = await SharedPreferences.getInstance();
      
      final legacyUser = const UserModel(
        name: 'Legacy User',
        email: 'legacy@example.com',
        gender: 'Other',
      );
      
      await prefs.setString('user_data', jsonEncode(legacyUser.toJson()));

      // Trigger migration
      await storageService.migrateIfNeeded();

      final profiles = await storageService.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'Legacy User');
      expect(profiles.first.id, startsWith('profile_'));

      final activeId = await storageService.getCurrentProfileId();
      expect(activeId, profiles.first.id);
    });

    test('last selected profile ID and clearing session helpers work correctly', () async {
      final user = const UserModel(
        id: 'profile_sarah',
        name: 'Sarah',
        gender: 'Female',
      );

      await storageService.addProfile(user);

      // Verify addProfile set both keys
      expect(await storageService.getCurrentProfileId(), 'profile_sarah');
      expect(await storageService.getLastSelectedProfileId(), 'profile_sarah');

      // Test manually setting last selected profile ID
      await storageService.setLastSelectedProfileId('profile_ria');
      expect(await storageService.getLastSelectedProfileId(), 'profile_ria');

      // Test clearing current active session ID
      await storageService.clearCurrentProfileId();
      expect(await storageService.getCurrentProfileId(), isNull);
      // Last selected should NOT be cleared
      expect(await storageService.getLastSelectedProfileId(), 'profile_ria');
    });

    test('getProfileCreationDate parses creation date correctly from profile ID', () {
      final now = DateTime.now();
      final id = 'profile_${now.millisecondsSinceEpoch}';
      
      final date = storageService.getProfileCreationDate(id);
      expect(date, isNotNull);
      expect(date!.year, now.year);
      expect(date.month, now.month);
      expect(date.day, now.day);
      expect(date.hour, 0);
      expect(date.minute, 0);

      expect(storageService.getProfileCreationDate('sarah_id'), isNull);
    });
  });
}

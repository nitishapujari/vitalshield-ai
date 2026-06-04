import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:vitalshield_ai/services/auth_service.dart';
import 'package:vitalshield_ai/services/storage_service.dart';
import 'package:vitalshield_ai/services/api_service.dart';
import 'package:vitalshield_ai/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Tests', () {
    late AuthService authService;
    late StorageService storageService;
    final Map<String, String> secureStorageData = {};

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      secureStorageData.clear();

      // Mock FlutterSecureStorage method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'read') {
            return secureStorageData[methodCall.arguments['key']];
          } else if (methodCall.method == 'write') {
            secureStorageData[methodCall.arguments['key']] = methodCall.arguments['value'] as String;
            return null;
          } else if (methodCall.method == 'delete') {
            secureStorageData.remove(methodCall.arguments['key']);
            return null;
          } else if (methodCall.method == 'deleteAll') {
            secureStorageData.clear();
            return null;
          } else if (methodCall.method == 'containsKey') {
            return secureStorageData.containsKey(methodCall.arguments['key']);
          }
          return null;
        },
      );

      authService = AuthService();
      storageService = StorageService();
    });

    test('signOut clears token, authenticated status, logged_in_email, and current active profile ID', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate logged in state
      secureStorageData['auth_token'] = 'mock_token';
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('current_profile_id', 'profile_123');
      await prefs.setString('last_selected_profile_id', 'profile_123');
      await prefs.setString('logged_in_email', 'test@example.com');

      // Trigger sign out
      await authService.signOut();

      // Verify states cleared
      expect(secureStorageData['auth_token'], isNull);
      expect(prefs.getBool('is_authenticated'), isFalse);
      expect(prefs.getString('current_profile_id'), isNull);
      expect(prefs.getString('logged_in_email'), isNull);
      // last_selected_profile_id should be preserved
      expect(prefs.getString('last_selected_profile_id'), 'profile_123');
    });

    test('legacy token in SharedPreferences is migrated to secure storage on load', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Simulate legacy token inside SharedPreferences
      await prefs.setString('auth_token', 'legacy_token_456');

      // Reset ApiService state for unit test isolation
      ApiService().resetForTesting();

      // 2. Fetching token should trigger load, migration, and SharedPreferences clearance
      final token = await ApiService().getToken();
      
      expect(token, 'legacy_token_456');
      expect(secureStorageData['auth_token'], 'legacy_token_456');
      expect(prefs.getString('auth_token'), isNull); // Removed from insecure storage
    });

    test('signIn and signUp save the logged in email', () async {
      await authService.signIn(email: 'user@example.com', password: 'Password123');
      expect(await storageService.getLoggedInEmail(), 'user@example.com');

      await authService.signOut();
      expect(await storageService.getLoggedInEmail(), isNull);

      await authService.signUp(name: 'New User', email: 'new@example.com', password: 'Password123');
      expect(await storageService.getLoggedInEmail(), 'new@example.com');
    });

    test('signUp validates password complexity and throws ArgumentError for weak passwords', () async {
      final weakPasswords = ['a', '1234', 'password', 'qwerty', 'abc123', 'Password', 'password123'];
      for (final pwd in weakPasswords) {
        expect(
          () => authService.signUp(name: 'New User', email: 'new@example.com', password: pwd),
          throwsA(isA<ArgumentError>()),
          reason: 'Password "$pwd" should be rejected as weak.',
        );
      }
    });

    test('Multi-account profile isolation and switching works correctly', () async {
      final userA = const UserModel(
        id: 'profile_a',
        name: 'Alice',
        email: 'alice@example.com',
      );
      final userB = const UserModel(
        id: 'profile_b',
        name: 'Bob',
        email: 'bob@example.com',
      );

      // Log in as Alice
      await authService.signIn(email: 'alice@example.com', password: 'Password123');
      await storageService.addProfile(userA);

      // Verify Alice has 1 profile
      var aliceProfiles = await storageService.getAllProfiles();
      expect(aliceProfiles, hasLength(1));
      expect(aliceProfiles.first.name, 'Alice');

      // Log out
      await authService.signOut();

      // Log in as Bob
      await authService.signIn(email: 'bob@example.com', password: 'Password123');
      
      // Initially Bob should have 0 profiles (data isolation)
      var bobProfilesInitial = await storageService.getAllProfiles();
      expect(bobProfilesInitial, isEmpty);

      // Add Bob's profile
      await storageService.addProfile(userB);

      // Verify Bob has 1 profile
      var bobProfiles = await storageService.getAllProfiles();
      expect(bobProfiles, hasLength(1));
      expect(bobProfiles.first.name, 'Bob');

      // Log out
      await authService.signOut();

      // Log back in as Alice
      await authService.signIn(email: 'alice@example.com', password: 'Password123');

      // Verify Alice's profile is restored and Bob's profile is NOT visible
      var aliceProfilesRestored = await storageService.getAllProfiles();
      expect(aliceProfilesRestored, hasLength(1));
      expect(aliceProfilesRestored.first.name, 'Alice');
      expect(aliceProfilesRestored.first.id, 'profile_a');
    });
  });
}

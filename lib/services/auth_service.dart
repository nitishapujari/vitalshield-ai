import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

/// Authentication service connecting Flutter frontend to FastAPI backend.
class AuthService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  /// Sign in using email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response != null && response['access_token'] != null) {
        final token = response['access_token'] as String;
        await _apiService.setToken(token);
        await _storageService.setAuthenticated(true);
        await _storageService.setLoggedInEmail(email);
        _isLoggedIn = true;

        // Fetch profiles for this user from backend and sync them locally
        try {
          final List<dynamic>? backendProfiles = await _apiService.get('/profiles');
          if (backendProfiles != null && backendProfiles.isNotEmpty) {
            // Load and clear existing profiles to replace with synced ones
            final currentProfiles = await _storageService.getAllProfiles();
            for (final p in currentProfiles) {
              if (p.id != null && p.email.toLowerCase() == email.toLowerCase()) {
                await _storageService.deleteProfile(p.id!);
              }
            }

            // Add back backend profiles
            // We need to parse each profile from JSON and add it
            for (final bp in backendProfiles) {
              // Map backend ProfileResponse fields back to UserModel
              // Backend Profile response uses user_id, dob, height, weight, activity_level, height_unit, age_category, wellness_tracking_enabled
              final map = bp as Map<String, dynamic>;
              
              // We reconstruct the user profile JSON structure for UserModel.fromJson
              final profileJson = {
                'id': map['id'],
                'name': map['name'],
                'email': email,
                'dob': map['dob'],
                'gender': map['gender'],
                'height': map['height'],
                'weight': map['weight'],
                'bmi': map['bmi'],
                'activity_level': map['activity_level'],
                'wellness_tracking_enabled': map['wellness_tracking_enabled'],
                'age': map['age'],
                'age_category': map['age_category'],
                'height_unit': map['height_unit'] ?? 'cm',
              };
              
              // Add to local StorageService
              final userModel = UserModel.fromJson(profileJson);
              await _storageService.addProfile(userModel);
            }
          }
        } catch (e) {
          debugPrint('Error syncing profiles during login: $e');
        }

        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        debugPrint('Backend sign in rejected: $e');
        return false;
      }
      debugPrint('Backend sign in failed, falling back to local simulation: $e');
      // Graceful offline fallback
      await _storageService.setAuthenticated(true);
      await _storageService.setLoggedInEmail(email);
      _isLoggedIn = true;
      return true;
    }
  }

  /// Sign up using name, email, and password
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (password.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ArgumentError('Password does not meet complexity requirements.');
    }
    try {
      final response = await _apiService.post('/auth/signup', {
        'email': email,
        'password': password,
        'name': name,
      });

      if (response != null && response['token'] != null) {
        final token = response['token'] as String;
        await _apiService.setToken(token);
        await _storageService.setAuthenticated(true);
        await _storageService.setLoggedInEmail(email);
        _isLoggedIn = true;
        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        debugPrint('Backend signup rejected: $e');
        return false;
      }
      debugPrint('Backend signup failed, falling back to local simulation: $e');
      // Graceful offline fallback
      await _storageService.setAuthenticated(true);
      await _storageService.setLoggedInEmail(email);
      _isLoggedIn = true;
      return true;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _apiService.setToken(null);
    await _storageService.setAuthenticated(false);
    await _storageService.clearCurrentProfileId();
    await _storageService.clearLoggedInEmail();
    _isLoggedIn = false;
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/utils/age_calculator.dart';


/// Storage service for persisting data locally.
/// Supports multi-profile management with namespaced keys.
class StorageService {
  static const String _userKey = 'user_data';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _authKey = 'is_authenticated';
  static const String _loggedInEmailKey = 'logged_in_email';
  
  static const String _profilesKey = 'local_profiles';
  static const String _currentProfileIdKey = 'current_profile_id';
  static const String _lastSelectedProfileIdKey = 'last_selected_profile_id';

  /// Get currently logged-in account email
  Future<String?> getLoggedInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loggedInEmailKey);
  }

  /// Set currently logged-in account email
  Future<void> setLoggedInEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loggedInEmailKey, email);
  }

  /// Clear currently logged-in account email
  Future<void> clearLoggedInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInEmailKey);
  }

  /// Migrate legacy single-user data into a profile if local_profiles doesn't exist
  Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_profilesKey)) {
      return; // Already migrated or profiles exist
    }

    final legacyData = prefs.getString(_userKey);
    if (legacyData != null) {
      try {
        final legacyUserJson = jsonDecode(legacyData) as Map<String, dynamic>;
        final legacyUser = UserModel.fromJson(legacyUserJson);
        
        // Generate new ID for legacy user
        final newId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
        final migratedUser = legacyUser.copyWith(id: newId);
        
        // Save as local profiles list
        await prefs.setString(_profilesKey, jsonEncode([migratedUser.toJson()]));
        await prefs.setString(_currentProfileIdKey, newId);
        
        // Migrate onboarding and auth keys if appropriate, or keep them
      } catch (e) {
        // Fallback or ignore malformed legacy data
      }
    }
  }

  /// Load all local profiles from disk (unfiltered raw list)
  Future<List<UserModel>> getAllProfilesRaw() async {
    await migrateIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_profilesKey);
    if (data != null) {
      try {
        final List<dynamic> list = jsonDecode(data) as List<dynamic>;
        final profiles = list.map((item) => UserModel.fromJson(item as Map<String, dynamic>)).toList();
        
        bool updated = false;
        final updatedProfiles = <UserModel>[];
        
        for (final profile in profiles) {
          if (profile.dob != null) {
            final calculatedAge = AgeCalculator.calculateAge(profile.dob!);
            final calculatedCategory = AgeCalculator.getCategory(calculatedAge).label;
            
            if (profile.age != calculatedAge || profile.ageCategory != calculatedCategory) {
              updatedProfiles.add(profile.copyWith(
                age: calculatedAge,
                ageCategory: calculatedCategory,
              ));
              updated = true;
            } else {
              updatedProfiles.add(profile);
            }
          } else {
            updatedProfiles.add(profile);
          }
        }
        
        if (updated) {
          await prefs.setString(_profilesKey, jsonEncode(updatedProfiles.map((p) => p.toJson()).toList()));
          return updatedProfiles;
        }
        
        return profiles;
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Load profiles associated with the logged-in email
  Future<List<UserModel>> getAllProfiles() async {
    final rawProfiles = await getAllProfilesRaw();
    final email = await getLoggedInEmail();
    if (email == null) return rawProfiles;
    return rawProfiles.where((p) => p.email.toLowerCase() == email.toLowerCase()).toList();
  }

  /// Get current active profile ID
  Future<String?> getCurrentProfileId() async {
    await migrateIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentProfileIdKey);
  }

  /// Set active profile ID
  Future<void> setCurrentProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileIdKey, id);
  }

  /// Clear active profile ID
  Future<void> clearCurrentProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentProfileIdKey);
  }

  /// Get last selected profile ID
  Future<String?> getLastSelectedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSelectedProfileIdKey);
  }

  /// Set last selected profile ID
  Future<void> setLastSelectedProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedProfileIdKey, id);
  }

  /// Add a new profile and make it the current active one
  Future<void> addProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfilesRaw();
    
    // Ensure profile has a valid ID and email
    UserModel userWithId = user;
    final email = await getLoggedInEmail();
    if (user.id == null || user.id!.isEmpty) {
      final newId = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      userWithId = user.copyWith(id: newId, email: email ?? user.email);
    } else {
      userWithId = user.copyWith(email: email ?? user.email);
    }
    
    profiles.add(userWithId);
    
    // Save updated profiles list
    await prefs.setString(_profilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    await prefs.setString(_currentProfileIdKey, userWithId.id!);
    await prefs.setString(_lastSelectedProfileIdKey, userWithId.id!);
  }

  /// Update an existing profile
  Future<void> updateProfile(UserModel user) async {
    if (user.id == null || user.id!.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfilesRaw();
    
    final index = profiles.indexWhere((p) => p.id == user.id);
    if (index != -1) {
      profiles[index] = user;
      await prefs.setString(_profilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    }
  }

  /// Remove a profile and clean up all its namespaced storage keys
  Future<void> deleteProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getAllProfilesRaw();
    
    profiles.removeWhere((p) => p.id == profileId);
    await prefs.setString(_profilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
    
    // Auto-switch to first remaining profile if deleting active one
    final currentId = prefs.getString(_currentProfileIdKey);
    if (currentId == profileId) {
      final activeProfiles = await getAllProfiles();
      if (activeProfiles.isNotEmpty) {
        await prefs.setString(_currentProfileIdKey, activeProfiles.first.id!);
      } else {
        await prefs.remove(_currentProfileIdKey);
      }
    }
    
    // Namespace cleanup
    final prefix = profileId.startsWith('profile_') ? '${profileId}_' : 'profile_${profileId}_';
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Load current active profile's user data (backward compatibility)
  Future<UserModel?> loadUser() async {
    final currentId = await getCurrentProfileId();
    if (currentId == null) return null;
    
    final profiles = await getAllProfilesRaw();
    final index = profiles.indexWhere((p) => p.id == currentId);
    if (index != -1) {
      return profiles[index];
    }
    return null;
  }

  /// Save to current active profile (backward compatibility)
  Future<void> saveUser(UserModel user) async {
    final currentId = await getCurrentProfileId();
    if (currentId != null) {
      final updatedUser = user.copyWith(id: currentId);
      await updateProfile(updatedUser);
    } else {
      await addProfile(user);
    }
  }

  /// Returns 'profile_{id}_' for namespacing, or '' if none active
  Future<String> getProfilePrefix() async {
    final id = await getCurrentProfileId();
    if (id == null || id.isEmpty) return '';
    if (id.startsWith('profile_')) {
      return '${id}_';
    }
    return 'profile_${id}_';
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    // A user has completed onboarding if they have at least one profile
    final profiles = await getAllProfiles();
    if (profiles.isNotEmpty) return true;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as complete
  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Check if user is authenticated (mock)
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  /// Set auth state
  Future<void> setAuthenticated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, value);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

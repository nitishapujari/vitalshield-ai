import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// State of the backend connectivity
class BackendState {
  final bool isOffline;
  final bool isCheckingHealth;

  const BackendState({
    this.isOffline = false,
    this.isCheckingHealth = false,
  });

  BackendState copyWith({
    bool? isOffline,
    bool? isCheckingHealth,
  }) {
    return BackendState(
      isOffline: isOffline ?? this.isOffline,
      isCheckingHealth: isCheckingHealth ?? this.isCheckingHealth,
    );
  }
}

class BackendNotifier extends StateNotifier<BackendState> {
  final ApiService _apiService;

  BackendNotifier(this._apiService) : super(const BackendState()) {
    // Perform initial health check
    checkHealth();
  }

  Future<void> checkHealth() async {
    state = state.copyWith(isCheckingHealth: true);
    final healthy = await _apiService.checkHealth();
    state = BackendState(isOffline: !healthy, isCheckingHealth: false);
  }

  void setOffline(bool offline) {
    if (state.isOffline != offline) {
      state = state.copyWith(isOffline: offline);
    }
  }
}

final backendProvider = StateNotifierProvider<BackendNotifier, BackendState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return BackendNotifier(api);
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class ApiService {
  // Singleton pattern: all ApiService() calls return the same instance,
  // ensuring the auth token is shared across the entire app.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() : _secureStorage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  final FlutterSecureStorage _secureStorage;
  String? _cachedToken;
  bool _initialized = false;

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _cachedToken = null;
  }

  /// Returns the correct API base URL for the current platform.
  /// Android emulators cannot reach the host via localhost; they must
  /// use the special alias 10.0.2.2 which maps to the host loopback.
  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    final url = (envUrl != null && envUrl.isNotEmpty)
        ? envUrl
        : 'http://localhost:8000';

    // On Android, rewrite localhost / 127.0.0.1 to the emulator host alias
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return url
              .replaceFirst('://localhost', '://10.0.2.2')
              .replaceFirst('://127.0.0.1', '://10.0.2.2');
        }
      } catch (_) {
        // Platform not available (e.g. in tests); fall through
      }
    }
    return url;
  }

  Future<void> _ensureTokenLoaded() async {
    if (_initialized && _cachedToken != null) return;
    
    // 1. Try reading from secure storage first
    try {
      _cachedToken = await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Failed to read auth token from secure storage: $e');
    }

    // 2. Backward compatibility migration: If not in secure storage, check SharedPreferences
    if (_cachedToken == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString(_tokenKey);
        if (legacyToken != null) {
          debugPrint('Migrating legacy auth token from SharedPreferences to Secure Storage.');
          // Move to secure storage
          await _secureStorage.write(key: _tokenKey, value: legacyToken);
          _cachedToken = legacyToken;
          // Delete from insecure SharedPreferences
          await prefs.remove(_tokenKey);
        }
      } catch (e) {
        debugPrint('Failed to migrate legacy auth token: $e');
      }
    }
    
    _initialized = true;
  }

  Future<Map<String, String>> _getHeaders() async {
    await _ensureTokenLoaded();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_cachedToken != null) {
      headers['Authorization'] = 'Bearer $_cachedToken';
    }
    return headers;
  }

  Future<void> setToken(String? token) async {
    _cachedToken = token;
    try {
      if (token != null) {
        await _secureStorage.write(key: _tokenKey, value: token);
      } else {
        await _secureStorage.delete(key: _tokenKey);
      }
    } catch (e) {
      debugPrint('Failed to write/delete auth token in secure storage: $e');
    }

    // Ensure we delete from SharedPreferences too if it was there
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    await _ensureTokenLoaded();
    return _cachedToken;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a GET request to the API
  Future<dynamic> get(String path, {Map<String, String>? queryParams, BackendNotifier? notifier}) async {
    try {
      final headers = await _getHeaders();
      var uri = Uri.parse('$baseUrl$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 3));
      
      notifier?.setOffline(false);
      return _processResponse(response);
    } catch (e) {
      debugPrint('ApiService GET error on $path: $e');
      notifier?.setOffline(true);
      rethrow;
    }
  }

  /// Send a POST request to the API
  Future<dynamic> post(String path, dynamic body, {Map<String, String>? queryParams, BackendNotifier? notifier}) async {
    try {
      final headers = await _getHeaders();
      var uri = Uri.parse('$baseUrl$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 4));

      notifier?.setOffline(false);
      return _processResponse(response);
    } catch (e) {
      debugPrint('ApiService POST error on $path: $e');
      notifier?.setOffline(true);
      rethrow;
    }
  }

  /// Send a PUT request to the API
  Future<dynamic> put(String path, dynamic body, {BackendNotifier? notifier}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl$path');

      final response = await http
          .put(
            uri,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 3));

      notifier?.setOffline(false);
      return _processResponse(response);
    } catch (e) {
      debugPrint('ApiService PUT error on $path: $e');
      notifier?.setOffline(true);
      rethrow;
    }
  }

  /// Send a DELETE request to the API
  Future<dynamic> delete(String path, {BackendNotifier? notifier}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl$path');

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 3));

      notifier?.setOffline(false);
      return _processResponse(response);
    } catch (e) {
      debugPrint('ApiService DELETE error on $path: $e');
      notifier?.setOffline(true);
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response) {
    final int statusCode = response.statusCode;
    final String responseBody = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      if (responseBody.isEmpty) return null;
      return json.decode(responseBody);
    } else {
      String message = 'API request failed';
      try {
        final errJson = json.decode(responseBody);
        message = errJson['detail'] ?? message;
      } catch (_) {}
      throw ApiException(message, statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

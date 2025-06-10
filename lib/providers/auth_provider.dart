import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flex_reminder/services/api_functions/api_config.dart';

enum AuthStatus {
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiConfig _apiConfig = ApiConfig();

  String? _token;
  AuthStatus _status = AuthStatus.loading;

  AuthProvider() {
    _initializeAuth();
  }

  // Getters
  String? get token => _token;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Initialize authentication state
  Future<void> _initializeAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'auth_token');
      if (_token != null) {
        final isValid = await _apiConfig.checkTokenValidity();
        _status =
            isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      print('Error initializing auth: $e');
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // Public method to initialize authentication
  Future<void> initializeAuthentication() async {
    await _initializeAuth();
  }

  // Set token after successful login
  Future<void> setToken(String token) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
      _token = token;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      print('Error setting token: $e');
      throw Exception('Failed to store authentication token');
    }
  }

  // Clear token on logout
  Future<void> logout() async {
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'last_check_result');
      _token = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
      await _storage.deleteAll();
      _token = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // Check if token is valid
  Future<bool> checkTokenValidity() async {
    try {
      final isValid = await _apiConfig.checkTokenValidity();
      _status = isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
      return isValid;
    } catch (e) {
      print('Error checking token validity: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Get current user ID from token
  Future<int?> getCurrentUserId() async {
    return await _apiConfig.getCurrentUserId();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class AuthService {
  final http.Client _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    double? monthlyBudget,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'password': password,
              'name': name,
              'monthlyBudget': monthlyBudget,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Save token and user data
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        return data;
      } else {
        throw Exception(data['error'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Save token and user data
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        return data;
      } else {
        throw Exception(data['error'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUserData() async {
    final userData = await _storage.read(key: _userKey);
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user info from server
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not logged in');
      }

      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Update stored user data
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to get user');
      }
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Update user's monthly budget
  Future<Map<String, dynamic>> updateBudget(double monthlyBudget) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not logged in');
      }

      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/budget'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'monthlyBudget': monthlyBudget}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Update stored user data
        await _storage.write(key: _userKey, value: json.encode(data['user']));
        return data;
      } else {
        throw Exception(data['error'] ?? 'Failed to update budget');
      }
    } catch (e) {
      throw Exception('Failed to update budget: $e');
    }
  }

  /// Get authorization header
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not logged in');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void dispose() {
    _client.close();
  }
}

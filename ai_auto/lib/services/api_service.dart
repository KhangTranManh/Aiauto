import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';

/// API Service for REST endpoints
class ApiService {
  final http.Client _client;
  final AuthService _authService;

  ApiService({http.Client? client, AuthService? authService})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService();

  /// Get auth headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sanitize error messages for user display
  String _getSanitizedError(dynamic error, [String? context]) {
    // Never expose technical details to users
    if (error.toString().contains('401') || error.toString().contains('Unauthorized')) {
      return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
    } else if (error.toString().contains('404')) {
      return 'Không tìm thấy dữ liệu.';
    } else if (error.toString().contains('500') || error.toString().contains('502') || error.toString().contains('503')) {
      return 'Lỗi máy chủ. Vui lòng thử lại sau.';
    } else if (error.toString().contains('TimeoutException') || error.toString().contains('timeout')) {
      return 'Kết nối chậm. Vui lòng kiểm tra mạng.';
    } else if (error.toString().contains('SocketException') || error.toString().contains('connection')) {
      return 'Không thể kết nối. Kiểm tra kết nối mạng.';
    }
    // Generic error message - never expose stack traces or technical details
    return context != null ? 'Có lỗi xảy ra. Vui lòng thử lại.' : 'Lỗi không xác định.';
  }

  /// Check server health
  Future<HealthResponse> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.health}'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HealthResponse.fromJson(data);
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'health'));
    }
  }

  /// Get API status
  Future<ApiStatus> getStatus() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.status}'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiStatus.fromJson(data);
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'status'));
    }
  }

  /// Get recent transactions
  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.recentTransactions}',
      ).replace(queryParameters: {'limit': limit.toString()});

      final headers = await _getHeaders();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> transactions = data['transactions'];
          return transactions
              .map((item) => Transaction.fromJson(item))
              .toList();
        } else {
          throw Exception(_getSanitizedError('API_ERROR'));
        }
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'transactions'));
    }
  }

  /// Get transactions by month
  Future<Map<String, dynamic>> getMonthlyTransactions({
    required int year,
    required int month,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.monthlyTransactions}/$year/$month',
            ),
            headers: headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> transactionsJson = data['transactions'];
          final transactions = transactionsJson
              .map((item) => Transaction.fromJson(item))
              .toList();

          return {
            'success': true,
            'period': data['period'],
            'count': data['count'],
            'total': data['total'],
            'totalFormatted': data['totalFormatted'],
            'transactions': transactions,
          };
        } else {
          throw Exception(_getSanitizedError('API_ERROR'));
        }
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'monthly'));
    }
  }

  /// Scan receipt text (for both manual upload and notification)
  Future<Map<String, dynamic>> scanReceipt(String receiptText) async {
    try {
      final headers = await _getHeaders();
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/scan-receipt'),
            headers: headers,
            body: json.encode({'receiptText': receiptText}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(_getSanitizedError('SCAN_ERROR'));
        }
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'scan'));
    }
  }

  /// Get expense forecast for current month
  Future<Map<String, dynamic>> getForecast({double? budget}) async {
    try {
      final uri = budget != null
          ? Uri.parse('${ApiConfig.baseUrl}/api/forecast')
              .replace(queryParameters: {'budget': budget.toInt().toString()})
          : Uri.parse('${ApiConfig.baseUrl}/api/forecast');

      final headers = await _getHeaders();
      final response = await _client
          .get(uri, headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['forecast'];
        } else {
          throw Exception(_getSanitizedError('FORECAST_ERROR'));
        }
      } else {
        throw Exception(_getSanitizedError(response.statusCode));
      }
    } catch (e) {
      throw Exception(_getSanitizedError(e, 'forecast'));
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

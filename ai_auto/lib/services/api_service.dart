import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/transaction_model.dart';

/// API Service for REST endpoints
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

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
        throw Exception('Failed to check health: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Health check failed: $e');
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
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get status failed: $e');
    }
  }

  /// Get recent transactions
  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.recentTransactions}',
      ).replace(queryParameters: {'limit': limit.toString()});

      final response = await _client
          .get(uri)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> transactions = data['transactions'];
          return transactions
              .map((item) => Transaction.fromJson(item))
              .toList();
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to get transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get recent transactions failed: $e');
    }
  }

  /// Get transactions by month
  Future<Map<String, dynamic>> getMonthlyTransactions({
    required int year,
    required int month,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.monthlyTransactions}/$year/$month',
            ),
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
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to get monthly transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get monthly transactions failed: $e');
    }
  }

  /// Scan receipt text (for both manual upload and notification)
  Future<Map<String, dynamic>> scanReceipt(String receiptText) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/scan-receipt'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'receiptText': receiptText}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Scan failed');
        }
      } else {
        throw Exception('Failed to scan receipt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Scan receipt failed: $e');
    }
  }

  /// Get expense forecast for current month
  Future<Map<String, dynamic>> getForecast() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/forecast'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['forecast'];
        } else {
          throw Exception(data['error'] ?? 'Forecast failed');
        }
      } else {
        throw Exception('Failed to get forecast: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get forecast failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

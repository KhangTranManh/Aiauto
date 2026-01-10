import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

/// Provider for managing transactions state
class TransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Transaction> _recentTransactions = [];
  List<Transaction> _monthlyTransactions = [];
  Map<String, dynamic>? _monthlySummary;
  bool _isLoading = false;
  String? _error;

  TransactionProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // Getters
  List<Transaction> get recentTransactions => _recentTransactions;
  List<Transaction> get monthlyTransactions => _monthlyTransactions;
  Map<String, dynamic>? get monthlySummary => _monthlySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch recent transactions
  Future<void> fetchRecentTransactions({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recentTransactions = await _apiService.getRecentTransactions(limit: limit);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _recentTransactions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch monthly transactions
  Future<void> fetchMonthlyTransactions({
    required int year,
    required int month,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getMonthlyTransactions(
        year: year,
        month: month,
      );
      
      _monthlyTransactions = result['transactions'] as List<Transaction>;
      _monthlySummary = result;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _monthlyTransactions = [];
      _monthlySummary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate total for transactions
  double calculateTotal(List<Transaction> transactions) {
    return transactions.fold(0, (sum, transaction) => sum + transaction.amount);
  }

  /// Group transactions by category
  Map<String, List<Transaction>> groupByCategory(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    
    for (var transaction in transactions) {
      if (!grouped.containsKey(transaction.category)) {
        grouped[transaction.category] = [];
      }
      grouped[transaction.category]!.add(transaction);
    }
    
    return grouped;
  }

  /// Get category totals
  Map<String, double> getCategoryTotals(List<Transaction> transactions) {
    final Map<String, double> totals = {};
    
    for (var transaction in transactions) {
      totals[transaction.category] = 
          (totals[transaction.category] ?? 0) + transaction.amount;
    }
    
    return totals;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}

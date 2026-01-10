import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';

/// Monthly Report Screen - Display monthly statistics
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _hasLoaded = false;
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _forecast;
  bool _isForecastLoading = false;
  double _monthlyBudget = 10000000; // Default

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyBudget = prefs.getDouble('monthly_budget') ?? 10000000;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only fetch data once when screen is first built
    if (!_hasLoaded) {
      _hasLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchData();
      });
    }
  }

  void _fetchData() {
    context.read<TransactionProvider>().fetchMonthlyTransactions(
          year: _selectedYear,
          month: _selectedMonth,
        );
    // Fetch forecast only for current month
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth == now.month) {
      _fetchForecast();
    } else {
      setState(() {
        _forecast = null; // Clear forecast for past months
      });
    }
  }

  Future<void> _fetchForecast() async {
    setState(() {
      _isForecastLoading = true;
    });

    try {
      final forecast = await _apiService.getForecast(budget: _monthlyBudget);
      setState(() {
        _forecast = forecast;
        _isForecastLoading = false;
      });
    } catch (e) {
      setState(() {
        _forecast = null;
        _isForecastLoading = false;
      });
      debugPrint('Forecast error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo tháng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showMonthPicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi: ${provider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (provider.monthlyTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có giao dịch trong tháng $_selectedMonth/$_selectedYear',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final summary = provider.monthlySummary!;
          // Handle both int and double from JSON
          final total = (summary['total'] is int) 
              ? (summary['total'] as int).toDouble() 
              : summary['total'] as double;
          final categoryTotals = provider.getCategoryTotals(
            provider.monthlyTransactions,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Month selector
              _buildMonthSelector(),
              const SizedBox(height: 16),

              // Forecast card (only for current month)
              if (_forecast != null) ...[
                _buildForecastCard(_forecast!),
                const SizedBox(height: 16),
              ],
              if (_isForecastLoading) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Total card
              _buildTotalCard(total, summary['count'] as int),
              const SizedBox(height: 16),

              // Pie chart
              if (categoryTotals.isNotEmpty) ...[
                _buildPieChart(categoryTotals),
                const SizedBox(height: 16),
              ],

              // Category breakdown
              _buildCategoryBreakdown(categoryTotals),
              const SizedBox(height: 16),

              // Recent transactions
              _buildRecentTransactions(provider.monthlyTransactions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForecastCard(Map<String, dynamic> forecast) {
    final currentSpent = forecast['current_spent'] as int;
    final predictedTotal = forecast['predicted_total'] as int;
    final safetyStatus = forecast['safety_status'] as String;
    final message = forecast['message'] as String;
    final budget = forecast['budget'] as int;
    final currentDate = forecast['current_date'] as int;
    final daysInMonth = forecast['days_in_month'] as int;

    // Determine color based on safety status
    Color statusColor;
    IconData statusIcon;
    switch (safetyStatus) {
      case 'Danger':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'Warning':
        statusColor = Colors.orange;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
    }

    final percentComplete = (currentDate / daysInMonth * 100).toInt();
    final percentBudget = (predictedTotal / budget * 100).toInt();

    return Card(
      elevation: 4,
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.trending_up, color: statusColor, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'DỰ ĐOÁN CHI TIÊU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        safetyStatus == 'Danger' ? 'NGUY HIỂM' : 
                        safetyStatus == 'Warning' ? 'CẢNH BÁO' : 'AN TOÀN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ tháng: Ngày $currentDate/$daysInMonth',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '$percentComplete%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: currentDate / daysInMonth,
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                    minHeight: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Current vs Predicted
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Đã chi',
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: 'đ',
                      decimalDigits: 0,
                    ).format(currentSpent),
                    Colors.blue,
                    Icons.shopping_cart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Dự đoán cuối tháng',
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: 'đ',
                      decimalDigits: 0,
                    ).format(predictedTotal),
                    statusColor,
                    Icons.auto_graph,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Budget progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'So với ngân sách',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '$percentBudget%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (predictedTotal / budget).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    color: statusColor,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ngân sách: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(budget)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tháng:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showMonthPicker,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                '$_selectedMonth/$_selectedYear',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(double total, int count) {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'TỔNG CHI TIÊU',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              NumberFormat.currency(
                locale: 'vi_VN',
                symbol: 'đ',
                decimalDigits: 0,
              ).format(total),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count giao dịch',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> categoryTotals) {
    final total = categoryTotals.values.reduce((a, b) => a + b);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phân bổ chi tiêu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: categoryTotals.entries.map((entry) {
                    final percentage = (entry.value / total * 100);
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: _getCategoryColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoryTotals.entries.map((entry) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: _getCategoryColor(entry.key),
                  ),
                  label: Text(entry.key),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, double> categoryTotals) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết theo danh mục',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryTotals.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(entry.key),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(entry.key),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: 'đ',
                              decimalDigits: 0,
                            ).format(entry.value),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<Transaction> transactions) {
    final recentTransactions = transactions.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giao dịch gần đây',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...recentTransactions.map((transaction) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _getCategoryColor(transaction.category),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(transaction.category),
                subtitle: Text(
                  transaction.note.isEmpty ? transaction.formattedDate : transaction.note,
                ),
                trailing: Text(
                  transaction.formattedAmount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = _selectedYear;
        int tempMonth = _selectedMonth;

        return AlertDialog(
          title: const Text('Chọn tháng'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            tempYear--;
                          });
                        },
                      ),
                      Text(
                        '$tempYear',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            tempYear++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Month grid
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: List.generate(12, (index) {
                      final month = index + 1;
                      final isSelected = month == tempMonth;
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            tempMonth = month;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'T$month',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedYear = tempYear;
                  _selectedMonth = tempMonth;
                });
                Navigator.pop(context);
                _fetchData();
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Shopping':
        return Colors.purple;
      case 'Entertainment':
        return Colors.pink;
      case 'Bills':
        return Colors.red;
      case 'Health':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills':
        return Icons.receipt;
      case 'Health':
        return Icons.favorite;
      default:
        return Icons.attach_money;
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}

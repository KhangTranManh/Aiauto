import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';
import '../services/socket_service.dart';

/// Monthly Report Screen - Display monthly statistics
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  final SocketService _socketService = SocketService();
  String? _aiForecast;
  bool _isForecastLoading = false;
  double _monthlyBudget = 10000000; // Default

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadBudget();
    _setupSocketCallbacks();
    _socketService.connect(); // Connect socket early
    
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _setupSocketCallbacks() {
    _socketService.onConnected = (_) {
      // Connected, ready to request forecast
    };

    _socketService.onAgentResponse = (response) {
      if (mounted) {
        setState(() {
          _aiForecast = response['answer'] ?? 'Không thể tạo dự báo.';
          _isForecastLoading = false;
        });
      }
    };

    _socketService.onError = (error) {
      if (mounted) {
        setState(() {
          _aiForecast = null;
          _isForecastLoading = false;
        });
      }
    };
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyBudget = prefs.getDouble('monthly_budget') ?? 10000000;
    });
  }

  void _fetchData() {
    final provider = context.read<TransactionProvider>();
    provider.fetchMonthlyTransactions(
          year: _selectedYear,
          month: _selectedMonth,
        );
    // Clear forecast state when fetching new data
    setState(() {
      _aiForecast = null;
      _isForecastLoading = false;
    });
  }

  Future<void> _fetchAIForecast() async {
    setState(() {
      _isForecastLoading = true;
    });

    try {
      // Wait a bit for socket to connect if not already connected
      int retries = 0;
      while (!_socketService.isConnected && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        retries++;
      }

      if (!_socketService.isConnected) {
        _socketService.connect();
        await Future.delayed(const Duration(seconds: 1));
      }

      final provider = context.read<TransactionProvider>();
      final transactions = provider.monthlyTransactions;
      final summary = provider.monthlySummary;
      
      // Build spending summary
      String spendingSummary = '';
      if (transactions.isNotEmpty && summary != null) {
        final total = (summary['total'] is int) 
            ? (summary['total'] as int).toDouble() 
            : summary['total'] as double;
        final categoryTotals = provider.getCategoryTotals(transactions);
        
        spendingSummary = 'Chi tiêu đến nay: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(total)}. ';
        spendingSummary += 'Phân bổ: ';
        categoryTotals.forEach((category, amount) {
          spendingSummary += '$category ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(amount)}, ';
        });
      } else {
        spendingSummary = 'Chưa có giao dịch nào trong tháng này. ';
      }
      
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final currentDay = now.day;
      
      final prompt = '''
Hãy phân tích và dự báo chi tiêu của tôi:

📊 THÔNG TIN HIỆN TẠI:
- Ngân sách tháng ${_selectedMonth}: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(_monthlyBudget)}
- Đã qua: ngày $currentDay/$daysInMonth (${(currentDay / daysInMonth * 100).toStringAsFixed(0)}% tháng)
$spendingSummary

🎯 YÊU CẦU:
1. Dự đoán tổng chi tiêu cuối tháng dựa trên xu hướng hiện tại
2. Đánh giá mức độ an toàn (An toàn/Cảnh báo/Nguy hiểm)
3. Đưa ra lời khuyên cụ thể để kiểm soát chi tiêu
4. Gợi ý điều chỉnh ngân sách cho các danh mục

Hãy trả lời ngắn gọn, rõ ràng với emoji phù hợp.''';
      
      _socketService.sendMessage(prompt);
      
    } catch (e) {
      setState(() {
        _aiForecast = null;
        _isForecastLoading = false;
      });
      debugPrint('AI Forecast error: $e');
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
          // Trigger AI forecast when data is loaded and it's the current month
          if (!provider.isLoading && 
              provider.monthlyTransactions.isNotEmpty && 
              _aiForecast == null && 
              !_isForecastLoading) {
            final now = DateTime.now();
            if (_selectedYear == now.year && _selectedMonth == now.month) {
              // Use Future.microtask to avoid calling setState during build
              Future.microtask(() => _fetchAIForecast());
            }
          }

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

              // AI Forecast card (only for current month)
              if (_aiForecast != null) ...[
                _buildAIForecastCard(_aiForecast!),
                const SizedBox(height: 16),
              ],
              if (_isForecastLoading) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('AI đang phân tích chi tiêu của bạn...'),
                      ],
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

  Widget _buildAIForecastCard(String forecast) {
    return Card(
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '🤖 DỰ BÁO THÔNG MINH',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchAIForecast,
                  tooltip: 'Làm mới dự báo',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // AI Forecast Content
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                forecast,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💡 Phân tích bởi AI dựa trên lịch sử chi tiêu và ngân sách của bạn',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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
    _socketService.dispose();
    super.dispose();
  }
}

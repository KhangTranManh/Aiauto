import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/transaction_provider.dart';

/// Settings Screen - Configure app settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _serverStatus;
  final TextEditingController _budgetController = TextEditingController();
  double _monthlyBudget = 10000000; // Default 10 million VND

  @override
  void initState() {
    super.initState();
    _loadBudget();
    // Delay server status check until after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServerStatus();
    });
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyBudget = prefs.getDouble('monthly_budget') ?? 10000000;
      _budgetController.text = _monthlyBudget.toInt().toString();
    });
  }

  Future<void> _saveBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', budget);
    setState(() {
      _monthlyBudget = budget;
    });
    _showSnackBar('✅ Đã lưu ngân sách: ${_formatCurrency(budget)}', Colors.green);
  }

  String _formatCurrency(double amount) {
    return '${(amount / 1000000).toStringAsFixed(1)} triệu đ';
  }

  void _showBudgetDialog() {
    _budgetController.text = _monthlyBudget.toInt().toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt ngân sách tháng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập ngân sách chi tiêu hàng tháng của bạn:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Ngân sách (VND)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 10000000 = 10 triệu đ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final budget = double.tryParse(_budgetController.text);
              if (budget != null && budget > 0) {
                _saveBudget(budget);
                Navigator.pop(context);
              } else {
                _showError('Vui lòng nhập số tiền hợp lệ');
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkServerStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to fetch transactions to test backend connection
      await context.read<TransactionProvider>().fetchMonthlyTransactions(
        year: DateTime.now().year,
        month: DateTime.now().month,
      );
      
      setState(() {
        _serverStatus = {
          'connected': true,
          'message': 'Backend đang hoạt động',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _serverStatus = {
          'connected': false,
          'error': e.toString(),
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả dữ liệu?'),
        content: const Text(
          'Cảnh báo: Thao tác này sẽ xóa TẤT CẢ giao dịch trong cơ sở dữ liệu. Không thể hoàn tác!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _showSnackBar('⚠️ Tính năng đang phát triển - cần thêm API endpoint', Colors.orange);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    _showSnackBar('❌ $message', Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kết nối Backend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_serverStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _serverStatus!['connected'] == true
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _serverStatus!['connected'] == true
                                ? Icons.check_circle
                                : Icons.error,
                            color: _serverStatus!['connected'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _serverStatus!['connected'] == true
                                      ? 'Đã kết nối'
                                      : 'Không kết nối được',
                                  style: TextStyle(
                                    color: _serverStatus!['connected'] == true
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serverStatus!['connected'] == true
                                      ? _serverStatus!['message'] ?? 'Backend hoạt động'
                                      : _serverStatus!['error'] ?? 'Lỗi không xác định',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkServerStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Kiểm tra kết nối'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Budget Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ngân sách tháng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ngân sách hiện tại',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_monthlyBudget),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _showBudgetDialog,
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Thay đổi ngân sách',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dùng để dự đoán và cảnh báo chi tiêu',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storage,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Quản lý dữ liệu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.sync, color: Colors.white),
                    ),
                    title: const Text('Đồng bộ dữ liệu'),
                    subtitle: const Text('Làm mới dữ liệu từ server'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        await context.read<TransactionProvider>().fetchMonthlyTransactions(
                          year: DateTime.now().year,
                          month: DateTime.now().month,
                        );
                        _showSnackBar('✅ Đã đồng bộ dữ liệu', Colors.green);
                      } catch (e) {
                        _showError('Lỗi đồng bộ: $e');
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    title: const Text('Xóa tất cả dữ liệu'),
                    subtitle: const Text('Xóa toàn bộ giao dịch (không thể hoàn tác)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _clearAllData,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // About
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Về ứng dụng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Tên ứng dụng', 'AI Auto Finance'),
                  _buildInfoRow('Phiên bản', '1.0.0'),
                  _buildInfoRow('Backend', 'Node.js + Express + MongoDB'),
                  _buildInfoRow('AI Model', 'Ollama (llama3.1:8b)'),
                  _buildInfoRow('Platform', 'Web + Mobile (Android/iOS)'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Features Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tính năng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(Icons.chat, 'Chat AI', 'Trò chuyện với AI để quản lý chi tiêu'),
                  _buildFeatureItem(Icons.camera_alt, 'Quét hóa đơn', 'Tự động trích xuất thông tin từ hóa đơn'),
                  _buildFeatureItem(Icons.bar_chart, 'Báo cáo', 'Thống kê chi tiêu theo tháng'),
                  _buildFeatureItem(Icons.trending_up, 'Giá Bitcoin', 'Xem giá BTC real-time'),
                  _buildFeatureItem(Icons.currency_exchange, 'Tỷ giá USD/VND', 'Xem tỷ giá hối đoái'),
                  _buildFeatureItem(Icons.receipt_long, 'OCR Mobile', 'Quét hóa đơn bằng camera (chỉ mobile)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }
}

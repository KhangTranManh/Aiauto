import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/transaction_provider.dart';
import '../services/auth_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  TextRecognizer? _textRecognizer;
  
  File? _imageFile;
  XFile? _webImage; // Store XFile for web
  String _extractedText = '';
  bool _isProcessing = false;
  bool _isUploading = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    // Only initialize ML Kit on mobile platforms
    if (!kIsWeb) {
      _textRecognizer = TextRecognizer();
    }
  }

  @override
  void dispose() {
    // Only close if it was initialized
    if (!kIsWeb && _textRecognizer != null) {
      _textRecognizer!.close();
    }
    super.dispose();
  }

  // Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _webImage = image;
            _imageFile = null;
          } else {
            _imageFile = File(image.path);
            _webImage = null;
          }
          _extractedText = '';
          _result = null;
        });
        if (!kIsWeb) {
          await _extractText();
        } else {
          _showSnackBar('Web: OCR không khả dụng. Vui lòng nhập text thủ công.', Colors.orange);
        }
      }
    } catch (e) {
      _showError('Lỗi khi chụp ảnh: $e');
    }
  }

  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _webImage = image;
            _imageFile = null;
          } else {
            _imageFile = File(image.path);
            _webImage = null;
          }
          _extractedText = '';
          _result = null;
        });
        if (!kIsWeb) {
          await _extractText();
        } else {
          _showSnackBar('Web: OCR không khả dụng. Vui lòng nhập text thủ công.', Colors.orange);
        }
      }
    } catch (e) {
      _showError('Lỗi khi chọn ảnh: $e');
    }
  }

  // Extract text from image using ML Kit
  Future<void> _extractText() async {
    if (_imageFile == null && _webImage == null) {
      _showError('Chưa có ảnh. Vui lòng chụp/chọn ảnh trước.');
      return;
    }

    // Web platform: Show dialog to manually input text
    if (kIsWeb) {
      _showSnackBar('Web không hỗ trợ OCR tự động. Vui lòng nhập text từ hóa đơn.', Colors.blue);
      await _showEditDialog();
      return;
    }

    // Mobile: Use ML Kit OCR
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false;
      });

      if (_extractedText.isNotEmpty) {
        _showSnackBar('Đã trích xuất ${_extractedText.length} ký tự từ hóa đơn', Colors.green);
        // Note: Receipt text NOT logged for privacy/security
      } else {
        _showSnackBar('Không tìm thấy text trong ảnh', Colors.orange);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Lỗi khi đọc text: $e');
    }
  }

  // Send extracted text to backend API
  Future<void> _sendToBackend() async {
    if (_extractedText.isEmpty) {
      _showError('Chưa có text để gửi. Vui lòng chụp/chọn ảnh hóa đơn trước.');
      return;
    }

    setState(() {
      _isUploading = true;
      _result = null;
    });

    try {
      // Get auth token
      final authService = AuthService();
      final token = await authService.getToken();
      
      final url = Uri.parse('${ApiConfig.baseUrl}/api/scan-receipt');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'receiptText': _extractedText}),
      );

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _result = data['data'];
          });
          
          // Refresh the transaction list in TransactionProvider
          if (mounted) {
            context.read<TransactionProvider>().fetchMonthlyTransactions(
              year: DateTime.now().year,
              month: DateTime.now().month,
            );
          }
          
          _showSnackBar('✅ Đã lưu giao dịch thành công!', Colors.green);
        } else {
          _showError('Không thể xử lý hóa đơn. Vui lòng thử lại.');
        }
      } else if (response.statusCode == 401) {
        _showError('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      } else {
        _showError('Không thể kết nối. Vui lòng thử lại.');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('Đã xảy ra lỗi. Vui lòng thử lại.');
    }
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red);
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

  void _clear() {
    setState(() {
      _imageFile = null;
      _webImage = null;
      _extractedText = '';
      _result = null;
    });
  }

  // Show dialog to manually edit text (useful for web or corrections)
  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: _extractedText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập text từ hóa đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập các thông tin quan trọng từ hóa đơn:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Số tiền (VD: 280.000 VND)\n'
              '• Tên cửa hàng/ngân hàng\n'
              '• Ngày tháng (nếu có)\n'
              '• Loại giao dịch',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 10,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'VD: Chuyển tiền TRAN THIEN MINH\n280.000 VND\n3 Th1, 2026\nTMCP Quân Đội',
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
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _extractedText = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét hóa đơn'),
        actions: [
          if (_imageFile != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clear,
              tooltip: 'Xóa',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            if (_imageFile != null || _webImage != null)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Use conditional rendering for web vs mobile
                    if (kIsWeb && _webImage != null)
                      Image.network(
                        _webImage!.path,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                const Text('Không thể hiển thị ảnh'),
                              ],
                            ),
                          );
                        },
                      )
                    else if (!kIsWeb && _imageFile != null)
                      Image.file(
                        _imageFile!,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Đang đọc hóa đơn...'),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            else
              Card(
                child: Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Chụp hoặc chọn ảnh hóa đơn',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (!kIsWeb) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Chụp ảnh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: Text(kIsWeb ? 'Chọn ảnh' : 'Thư viện'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                if (kIsWeb || _imageFile != null || _webImage != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditDialog(),
                      icon: const Icon(Icons.edit),
                      label: const Text('Nhập text'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Extracted text preview
            if (_extractedText.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Text đã trích xuất:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _extractedText.length < 20 ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_extractedText.length} ký tự',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_extractedText.length < 20)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ Text quá ngắn (${_extractedText.length} ký tự). AI sẽ không có đủ thông tin để phân tích chính xác.',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _extractedText,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Manual edit button for web or correction
                      TextButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.edit),
                        label: const Text('Chỉnh sửa text'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Send button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _sendToBackend,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isUploading ? 'Đang gửi...' : 'Gửi lên AI để phân tích'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Result display
            if (_result != null) ...[
              const Text(
                'Kết quả phân tích:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildResultRow('Số tiền:', '${_result!['amount']?.toStringAsFixed(0) ?? '0'}đ', Colors.red),
                      const Divider(),
                      _buildResultRow('Loại:', _result!['category'] ?? 'Unknown', Colors.blue),
                      const Divider(),
                      _buildResultRow('Cửa hàng:', _result!['merchant'] ?? 'Unknown', Colors.purple),
                      const Divider(),
                      _buildResultRow('Ngày:', _result!['date'] ?? 'Unknown', Colors.orange),
                      if (_result!['note']?.isNotEmpty == true) ...[
                        const Divider(),
                        _buildResultRow('Ghi chú:', _result!['note'], Colors.grey),
                      ],
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Đã lưu vào database',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

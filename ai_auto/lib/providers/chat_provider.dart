import 'package:flutter/foundation.dart';
import '../services/socket_service.dart';
import 'transaction_provider.dart';

/// Chat Message Model
class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? status;

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.status,
  });
}

/// Provider for managing chat state
class ChatProvider with ChangeNotifier {
  final SocketService _socketService;
  final TransactionProvider? _transactionProvider;
  
  List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isProcessing = false;
  String? _error;

  ChatProvider({
    SocketService? socketService,
    TransactionProvider? transactionProvider,
  })  : _socketService = socketService ?? SocketService(),
        _transactionProvider = transactionProvider {
    _setupSocketCallbacks();
  }

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  /// Setup socket callbacks
  void _setupSocketCallbacks() {
    _socketService.onConnected = (message) {
      _isConnected = true;
      _error = null;
      _addMessage(ChatMessage(
        message: message,
        isUser: false,
        timestamp: DateTime.now(),
        status: 'connected',
      ));
      notifyListeners();
    };

    _socketService.onMessageReceived = (message) {
      _isProcessing = true;
      notifyListeners();
    };

    _socketService.onAgentStatus = (status, message) {
      _isProcessing = status == 'thinking';
      // Don't add "Đang xử lý..." message to avoid duplication
      // Just update the processing state
      notifyListeners();
    };

    _socketService.onAgentResponse = (response) {
      _isProcessing = false;
      final answer = response['answer'] ?? 'No response';
      final success = response['success'] ?? false;
      
      _addMessage(ChatMessage(
        message: answer,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      
      // Refresh transactions if the operation was successful
      if (success && _transactionProvider != null) {
        final now = DateTime.now();
        _transactionProvider.fetchRecentTransactions(limit: 10);
        _transactionProvider.fetchMonthlyTransactions(
          year: now.year,
          month: now.month,
        );
      }
      
      notifyListeners();
    };

    _socketService.onError = (error) {
      _error = error;
      _isProcessing = false;
      // Show user-friendly error without technical details
      _addMessage(ChatMessage(
        message: 'Đã xảy ra lỗi. Vui lòng thử lại.',
        isUser: false,
        timestamp: DateTime.now(),
        status: 'error',
      ));
      notifyListeners();
    };

    _socketService.onDisconnected = () {
      _isConnected = false;
      _isProcessing = false;
      // Don't show error message for disconnections - just update status
      notifyListeners();
    };
  }

  /// Connect to server
  void connect() {
    _socketService.connect();
  }

  /// Send message
  void sendMessage(String message) {
    if (message.trim().isEmpty) return;

    // Add user message to chat
    _addMessage(ChatMessage(
      message: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // Send to server
    _socketService.sendMessage(message);
    notifyListeners();
  }

  /// Add message to list
  void _addMessage(ChatMessage message) {
    _messages.add(message);
  }

  /// Clear messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Disconnect
  void disconnect() {
    _socketService.disconnect();
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}

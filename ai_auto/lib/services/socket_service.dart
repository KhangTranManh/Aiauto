import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logger/logger.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Socket.IO Service for real-time communication
class SocketService {
  IO.Socket? _socket;
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();
  bool _isConnected = false;

  // Callbacks
  Function(String message)? onConnected;
  Function(String message)? onMessageReceived;
  Function(String status, String message)? onAgentStatus;
  Function(Map<String, dynamic> response)? onAgentResponse;
  Function(String error)? onError;
  Function()? onDisconnected;

  bool get isConnected => _isConnected;

  /// Connect to Socket.IO server
  Future<void> connect() async {
    try {
      _logger.i('Connecting to Socket.IO server: ${ApiConfig.socketUrl}');

      // Get user data to extract userId
      final userData = await _authService.getUserData();
      final userId = userData?['_id'] ?? 'default';
      
      _logger.i('📱 User data from storage: $userData');
      _logger.i('👤 Extracted userId: $userId');

      _socket = IO.io(
        ApiConfig.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({'userId': userId}) // Pass userId in handshake
            .disableAutoConnect()
            .enableForceNew()
            .enableReconnection() // Enable auto-reconnection
            .setReconnectionDelay(2000) // Wait 2 seconds between reconnection attempts
            .setReconnectionAttempts(5) // Try to reconnect 5 times
            .build(),
      );

      _setupEventHandlers();
      _socket!.connect();
    } catch (e) {
      _logger.e('Socket connection error: $e');
      // Don't expose technical error to user - just call disconnect handler
      onDisconnected?.call();
    }
  }

  /// Setup event handlers
  void _setupEventHandlers() {
    _socket!.onConnect((_) {
      _isConnected = true;
      _logger.i('✅ Socket connected: ${_socket!.id}');
    });

    _socket!.on('connected', (data) {
      _logger.i('Connected event received: $data');
      final message = data['message'] ?? 'Connected to server';
      onConnected?.call(message);
    });

    _socket!.on('message_received', (data) {
      _logger.i('Message received acknowledgment: $data');
      final message = data['message'] ?? '';
      onMessageReceived?.call(message);
    });

    _socket!.on('agent_status', (data) {
      _logger.i('Agent status: $data');
      final status = data['status'] ?? '';
      final message = data['message'] ?? '';
      onAgentStatus?.call(status, message);
    });

    _socket!.on('agent_response', (data) {
      _logger.i('Agent response: $data');
      onAgentResponse?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('error', (data) {
      _logger.e('Socket error: $data');
      final message = data['message'] ?? 'Unknown error';
      onError?.call(message);
    });

    _socket!.on('pong', (data) {
      _logger.d('Pong received: $data');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _logger.w('❌ Socket disconnected');
      onDisconnected?.call();
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      _logger.e('Connection error: $data'); // Log technical details for debugging
      // Don't expose technical details to user - just silently handle it
      onDisconnected?.call();
    });

    _socket!.onError((data) {
      _logger.e('Socket error: $data'); // Log technical details for debugging
      // Don't expose technical details to user - just silently handle it
      onDisconnected?.call();
    });
  }

  /// Send user message to AI agent
  void sendMessage(String message) {
    if (_socket == null || !_isConnected) {
      _logger.w('Socket not connected. Cannot send message.');
      onError?.call('Not connected to server');
      return;
    }

    _logger.i('Sending message: $message');
    _socket!.emit('user_message', {'message': message});
  }

  /// Send ping
  void sendPing() {
    if (_socket == null || !_isConnected) {
      _logger.w('Socket not connected. Cannot send ping.');
      return;
    }

    _socket!.emit('ping');
  }

  /// Disconnect from server
  void disconnect() {
    if (_socket != null) {
      _logger.i('Disconnecting socket...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
  }
}

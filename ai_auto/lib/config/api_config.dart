import 'dart:io';
import 'package:flutter/foundation.dart';

/// API Configuration
class ApiConfig {
  // ⚠️ FOR PHYSICAL DEVICE: Set your computer's IP address here
  // Find your IP: Run "ipconfig" (Windows) or "ifconfig" (Mac/Linux) in terminal
  // Look for IPv4 Address like 192.168.x.x or 10.0.x.x
  static const String? _physicalDeviceIP = '192.168.1.224'; // Your computer's IP
  
  // Automatically detect the correct base URL based on platform
  static String get baseUrl {
    // If physical device IP is set, use it (for testing on real Android/iOS device)
    if (_physicalDeviceIP != null && !kIsWeb) {
      return 'http://$_physicalDeviceIP:3000';
    }
    
    if (kIsWeb) {
      // Web: use same origin or localhost
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      // Android Emulator: use special IP to access host machine
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      // iOS Simulator: can use localhost
      return 'http://localhost:3000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms: use localhost
      return 'http://localhost:3000';
    } else {
      // Fallback for any other platform
      return 'http://localhost:3000';
    }
  }
  
  // How to find your IP:
  // Windows: ipconfig (look for IPv4 Address)
  // Mac/Linux: ifconfig | grep "inet " (look for 192.168.x.x)
  
  // API Endpoints
  static const String health = '/health';
  static const String status = '/api/status';
  static const String recentTransactions = '/api/transactions/recent';
  static const String monthlyTransactions = '/api/transactions/month';
  
  // Socket.IO URL - same as base URL
  static String get socketUrl => baseUrl;
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}

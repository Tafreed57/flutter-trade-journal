import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loader
/// 
/// Loads configuration from multiple sources in priority order:
/// 1. --dart-define compile-time variables (highest priority)
/// 2. .env file (development only)
/// 3. Default values
/// 
/// ## Setup
/// 1. For development: Create a `.env` file in the project root
/// 2. For release: Use `--dart-define=KEY=value` at build time
class EnvConfig {
  // Private constructor - use static methods
  EnvConfig._();
  
  /// Whether the environment is loaded
  static bool _isLoaded = false;
  
  /// Compile-time constants from --dart-define
  /// These take priority over .env file
  static const String _dartDefineApiKey = String.fromEnvironment('FINNHUB_API_KEY');
  static const String _dartDefineApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _dartDefineWsUrl = String.fromEnvironment('WS_URL');
  
  /// Load environment variables from .env file
  /// 
  /// Call this once at app startup, before runApp()
  static Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      await dotenv.load(fileName: '.env');
      _isLoaded = true;
    } catch (e) {
      // .env file might not exist in development
      // That's okay - we'll handle missing keys gracefully
      _isLoaded = true;
    }
  }
  
  /// Get Finnhub API key
  /// 
  /// Priority: --dart-define > .env > null
  static String? get finnhubApiKey {
    // First check compile-time constant
    if (_dartDefineApiKey.isNotEmpty) {
      return _dartDefineApiKey;
    }
    
    // Then check .env file
    if (!_isLoaded) return null;
    
    try {
      final key = dotenv.env['FINNHUB_API_KEY'];
      
      if (key == null || key.isEmpty || key == 'your_finnhub_api_key_here') {
        return null;
      }
      
      return key;
    } catch (_) {
      return null;
    }
  }
  
  /// Get API base URL (for Finnhub or custom backend)
  static String get apiBaseUrl {
    if (_dartDefineApiBaseUrl.isNotEmpty) {
      return _dartDefineApiBaseUrl;
    }
    final envUrl = dotenv.maybeGet('API_BASE_URL');
    return envUrl ?? 'https://finnhub.io/api/v1';
  }
  
  /// Get WebSocket URL
  static String get wsUrl {
    if (_dartDefineWsUrl.isNotEmpty) {
      return _dartDefineWsUrl;
    }
    final envUrl = dotenv.maybeGet('WS_URL');
    return envUrl ?? 'wss://ws.finnhub.io';
  }
  
  /// Check if Finnhub is configured
  static bool get isFinnhubConfigured => finnhubApiKey != null;
  
  /// Get any environment variable by name
  /// 
  /// Note: Compile-time --dart-define variables can only be accessed
  /// through the specific getters above, not through this method.
  static String? get(String key) {
    if (!_isLoaded) return null;
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
  
  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;
  
  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;
  
  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;
}


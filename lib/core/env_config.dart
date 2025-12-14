import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loader
/// 
/// Loads API keys and other sensitive configuration from .env file.
/// NEVER hardcode API keys in source code!
/// 
/// ## Setup
/// 1. Create a `.env` file in the project root
/// 2. Add your API keys (see .env.example)
/// 3. Call `EnvConfig.load()` before using any API
class EnvConfig {
  // Private constructor - use static methods
  EnvConfig._();
  
  /// Whether the environment is loaded
  static bool _isLoaded = false;
  
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
  /// Returns null if not set or if env not loaded yet
  static String? get finnhubApiKey {
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
  
  /// Check if Finnhub is configured
  static bool get isFinnhubConfigured => _isLoaded && finnhubApiKey != null;
  
  /// Get any environment variable by name
  static String? get(String key) {
    if (!_isLoaded) return null;
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
  
  /// Check if running in development mode
  static bool get isDevelopment {
    // Flutter doesn't have a built-in way to check this
    // You can use --dart-define to set a flag
    const isRelease = bool.fromEnvironment('dart.vm.product');
    return !isRelease;
  }
}


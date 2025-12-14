import 'package:flutter/foundation.dart';

/// App-wide logging utility with log levels
/// 
/// Usage:
///   Log.d('Debug message');
///   Log.i('Info message');
///   Log.w('Warning message');
///   Log.e('Error message', error, stackTrace);
/// 
/// In release mode, only warnings and errors are logged.
class Log {
  static const String _tag = 'TradingJournal';
  
  /// Log level thresholds
  static const int _levelDebug = 0;
  static const int _levelInfo = 1;
  static const int _levelWarning = 2;
  static const int _levelError = 3;
  
  /// Minimum log level (debug in debug mode, warning in release)
  static int get _minLevel => kReleaseMode ? _levelWarning : _levelDebug;
  
  /// Debug log - only shown in debug builds
  static void d(String message, [String? tag]) {
    _log(_levelDebug, '🐛', tag ?? _tag, message);
  }
  
  /// Info log - general information
  static void i(String message, [String? tag]) {
    _log(_levelInfo, 'ℹ️', tag ?? _tag, message);
  }
  
  /// Warning log - potential issues
  static void w(String message, [String? tag]) {
    _log(_levelWarning, '⚠️', tag ?? _tag, message);
  }
  
  /// Error log - actual errors with optional exception/stack
  static void e(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    _log(_levelError, '❌', tag ?? _tag, message);
    if (error != null && !kReleaseMode) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null && !kReleaseMode) {
      debugPrint('   Stack: $stackTrace');
    }
  }
  
  /// Network-specific logging
  static void network(String message, {bool isError = false}) {
    if (isError) {
      e(message, null, null, 'Network');
    } else {
      d(message, 'Network');
    }
  }
  
  /// WebSocket-specific logging
  static void ws(String message, {bool isError = false}) {
    if (isError) {
      e(message, null, null, 'WebSocket');
    } else {
      d(message, 'WebSocket');
    }
  }
  
  /// Trade/Journal logging
  static void trade(String message) {
    i(message, 'Trade');
  }
  
  static void _log(int level, String emoji, String tag, String message) {
    if (level < _minLevel) return;
    debugPrint('$emoji [$tag] $message');
  }
}


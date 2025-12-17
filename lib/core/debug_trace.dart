/// Debug instrumentation for tracing journal and trade operations
/// 
/// This provides detailed timing and flow logging to diagnose:
/// - Chart trades not saving to journal
/// - Journal loading forever/slow
/// - Account-specific loading issues
library;

import 'logger.dart';

/// Debug tracer for journal operations
class JournalDebug {
  static final _timestamps = <String, DateTime>{};
  static bool _enabled = true;
  
  /// Enable/disable debug tracing
  static void setEnabled(bool enabled) => _enabled = enabled;
  
  /// Start timing an operation
  static void start(String operation) {
    if (!_enabled) return;
    _timestamps[operation] = DateTime.now();
    Log.d('⏱️ [DEBUG] $operation START at ${DateTime.now().toIso8601String()}');
  }
  
  /// End timing an operation and log duration
  static void end(String operation, {String? details}) {
    if (!_enabled) return;
    final startTime = _timestamps.remove(operation);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      final extra = details != null ? ' | $details' : '';
      Log.d('⏱️ [DEBUG] $operation END (${duration.inMilliseconds}ms)$extra');
    } else {
      Log.d('⏱️ [DEBUG] $operation END (no start time)');
    }
  }
  
  /// Log auth events
  static void auth(String event, {String? userId, String? error}) {
    if (!_enabled) return;
    final userInfo = userId != null ? ' | userId: ${userId.substring(0, 8)}...' : '';
    final errorInfo = error != null ? ' | ERROR: $error' : '';
    Log.d('🔐 [AUTH] $event$userInfo$errorInfo');
  }
  
  /// Log journal load events
  static void journalLoad(String event, {
    String? userId,
    int? tradeCount,
    String? source,
    String? error,
  }) {
    if (!_enabled) return;
    final parts = <String>[];
    if (userId != null) parts.add('userId: ${userId.substring(0, 8)}...');
    if (tradeCount != null) parts.add('trades: $tradeCount');
    if (source != null) parts.add('source: $source');
    if (error != null) parts.add('ERROR: $error');
    
    final details = parts.isNotEmpty ? ' | ${parts.join(', ')}' : '';
    Log.d('📋 [JOURNAL] $event$details');
  }
  
  /// Log trade events (chart-based)
  static void chartTrade(String event, {
    String? symbol,
    String? toolId,
    String? positionId,
    String? tradeId,
    String? userId,
    String? error,
  }) {
    if (!_enabled) return;
    final parts = <String>[];
    if (symbol != null) parts.add('symbol: $symbol');
    if (toolId != null) parts.add('toolId: ${toolId.substring(0, 8)}...');
    if (positionId != null) parts.add('posId: ${positionId.substring(0, 8)}...');
    if (tradeId != null) parts.add('tradeId: ${tradeId.substring(0, 8)}...');
    if (userId != null) parts.add('userId: ${userId.substring(0, 8)}...');
    if (error != null) parts.add('ERROR: $error');
    
    final details = parts.isNotEmpty ? ' | ${parts.join(', ')}' : '';
    Log.d('📊 [CHART_TRADE] $event$details');
  }
  
  /// Log manual trade events
  static void manualTrade(String event, {
    String? tradeId,
    String? symbol,
    String? userId,
    String? error,
  }) {
    if (!_enabled) return;
    final parts = <String>[];
    if (tradeId != null) parts.add('tradeId: ${tradeId.substring(0, 8)}...');
    if (symbol != null) parts.add('symbol: $symbol');
    if (userId != null) parts.add('userId: ${userId.substring(0, 8)}...');
    if (error != null) parts.add('ERROR: $error');
    
    final details = parts.isNotEmpty ? ' | ${parts.join(', ')}' : '';
    Log.d('✏️ [MANUAL_TRADE] $event$details');
  }
  
  /// Log Firestore operations
  static void firestore(String event, {
    String? collection,
    String? docId,
    int? docCount,
    String? error,
  }) {
    if (!_enabled) return;
    final parts = <String>[];
    if (collection != null) parts.add('collection: $collection');
    if (docId != null) parts.add('docId: ${docId.substring(0, 8)}...');
    if (docCount != null) parts.add('docs: $docCount');
    if (error != null) parts.add('ERROR: $error');
    
    final details = parts.isNotEmpty ? ' | ${parts.join(', ')}' : '';
    Log.d('🔥 [FIRESTORE] $event$details');
  }
  
  /// Log state transitions
  static void state(String provider, String event, {Map<String, dynamic>? data}) {
    if (!_enabled) return;
    final dataStr = data != null ? ' | $data' : '';
    Log.d('🔄 [STATE] $provider: $event$dataStr');
  }
  
  /// Log a warning (visible issue that needs attention)
  static void warn(String message) {
    if (!_enabled) return;
    Log.w('⚠️ [DEBUG_WARN] $message');
  }
  
  /// Log an error
  static void error(String message, [dynamic e]) {
    if (!_enabled) return;
    Log.e('❌ [DEBUG_ERROR] $message', e);
  }
}


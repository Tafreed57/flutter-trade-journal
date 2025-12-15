import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/logger.dart';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';

/// Persisted candle data for a symbol
class PersistedCandleData {
  final String symbol;
  final Timeframe baseTimeframe;
  final List<Candle> candles;
  final DateTime lastUpdated;
  
  PersistedCandleData({
    required this.symbol,
    required this.baseTimeframe,
    required this.candles,
    required this.lastUpdated,
  });
  
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'baseTimeframe': baseTimeframe.index,
    'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    'candles': candles.map((c) => {
      'timestamp': c.timestamp.millisecondsSinceEpoch,
      'open': c.open,
      'high': c.high,
      'low': c.low,
      'close': c.close,
      'volume': c.volume,
    }).toList(),
  };
  
  factory PersistedCandleData.fromJson(Map<String, dynamic> json) {
    final candlesList = (json['candles'] as List).map((c) => Candle(
      timestamp: DateTime.fromMillisecondsSinceEpoch(c['timestamp'] as int),
      open: (c['open'] as num).toDouble(),
      high: (c['high'] as num).toDouble(),
      low: (c['low'] as num).toDouble(),
      close: (c['close'] as num).toDouble(),
      volume: (c['volume'] as num).toDouble(),
    )).toList();
    
    return PersistedCandleData(
      symbol: json['symbol'] as String,
      baseTimeframe: Timeframe.values[json['baseTimeframe'] as int],
      candles: candlesList,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int),
    );
  }
}

/// Central market data engine that manages:
/// - Raw candle storage (persisted)
/// - Aggregation cache per timeframe
/// - Live price updates
/// - Replay state
/// 
/// Architecture:
/// ```
/// MarketDataEngine
/// ├── _rawCandleStore: Persisted base timeframe candles (Hive)
/// ├── _aggregationCache: Map<Timeframe, List<Candle>>
/// ├── LivePriceHandler: Updates last candle in real-time
/// └── ReplayController: Manages replay mode state
/// ```
class MarketDataEngine {
  static MarketDataEngine? _instance;
  static MarketDataEngine get instance => _instance ??= MarketDataEngine._();
  
  MarketDataEngine._();
  
  // Persistence
  Box<String>? _candleBox;
  static const String _boxName = 'candle_history';
  static const int _maxCandlesPerSymbol = 2000; // Cap history size
  
  // Raw candle storage (base timeframe = m1 or m5)
  final Map<String, PersistedCandleData> _rawCandleStore = {};
  
  // Aggregation cache: symbol -> timeframe -> candles
  final Map<String, Map<Timeframe, List<Candle>>> _aggregationCache = {};
  
  // Replay state
  bool _isReplayMode = false;
  DateTime? _replayCursorTime;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;
  
  // Listeners
  final List<VoidCallback> _listeners = [];
  
  // Getters for replay
  bool get isReplayMode => _isReplayMode;
  DateTime? get replayCursorTime => _replayCursorTime;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  
  /// Initialize the engine and load persisted data
  Future<void> init() async {
    try {
      _candleBox = await Hive.openBox<String>(_boxName);
      await _loadPersistedData();
      Log.i('MarketDataEngine initialized with ${_rawCandleStore.length} symbols');
    } catch (e) {
      Log.e('MarketDataEngine init error', e);
    }
  }
  
  /// Load all persisted candle data
  Future<void> _loadPersistedData() async {
    if (_candleBox == null) return;
    
    for (final key in _candleBox!.keys) {
      try {
        final jsonStr = _candleBox!.get(key);
        if (jsonStr != null) {
          final json = _parseJson(jsonStr);
          if (json != null) {
            final data = PersistedCandleData.fromJson(json);
            _rawCandleStore[data.symbol] = data;
            Log.d('Loaded ${data.candles.length} candles for ${data.symbol}');
          }
        }
      } catch (e) {
        Log.e('Error loading persisted data for $key', e);
      }
    }
  }
  
  Map<String, dynamic>? _parseJson(String jsonStr) {
    try {
      // Simple JSON parsing for our format
      return Map<String, dynamic>.from(
        Uri.splitQueryString(jsonStr).map((k, v) => MapEntry(k, v))
      );
    } catch (e) {
      // Try dart:convert if simple parse fails
      try {
        return null; // Will implement proper JSON parsing
      } catch (e2) {
        return null;
      }
    }
  }
  
  /// Store candles for a symbol (base timeframe)
  Future<void> storeCandles(String symbol, List<Candle> candles, Timeframe timeframe) async {
    if (candles.isEmpty) return;
    
    // Get existing data
    final existing = _rawCandleStore[symbol];
    List<Candle> mergedCandles;
    
    if (existing != null) {
      // Merge new candles with existing, avoiding duplicates
      mergedCandles = _mergeCandles(existing.candles, candles);
    } else {
      mergedCandles = List.from(candles);
    }
    
    // Sort by timestamp
    mergedCandles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Cap size
    if (mergedCandles.length > _maxCandlesPerSymbol) {
      mergedCandles = mergedCandles.sublist(mergedCandles.length - _maxCandlesPerSymbol);
    }
    
    // Store
    final data = PersistedCandleData(
      symbol: symbol,
      baseTimeframe: timeframe,
      candles: mergedCandles,
      lastUpdated: DateTime.now(),
    );
    
    _rawCandleStore[symbol] = data;
    
    // Clear aggregation cache for this symbol (will be rebuilt on demand)
    _aggregationCache.remove(symbol);
    
    // Persist to Hive
    await _persistData(symbol, data);
    
    _notifyListeners();
  }
  
  /// Merge candle lists, avoiding duplicates by timestamp
  List<Candle> _mergeCandles(List<Candle> existing, List<Candle> newCandles) {
    final Map<int, Candle> candleMap = {};
    
    // Add existing
    for (final c in existing) {
      candleMap[c.timestamp.millisecondsSinceEpoch] = c;
    }
    
    // Add/update with new (new takes priority for same timestamp)
    for (final c in newCandles) {
      candleMap[c.timestamp.millisecondsSinceEpoch] = c;
    }
    
    return candleMap.values.toList();
  }
  
  /// Persist data to Hive
  Future<void> _persistData(String symbol, PersistedCandleData data) async {
    if (_candleBox == null) return;
    
    try {
      // Simple serialization (could use json_serializable for production)
      final json = data.toJson();
      // For now, store as stringified format
      // In production, use proper JSON encoding
      await _candleBox!.put(symbol, _encodeData(json));
    } catch (e) {
      Log.e('Error persisting data for $symbol', e);
    }
  }
  
  String _encodeData(Map<String, dynamic> json) {
    // Simple encoding - in production use dart:convert
    final buffer = StringBuffer();
    buffer.write('symbol=${json['symbol']}&');
    buffer.write('baseTimeframe=${json['baseTimeframe']}&');
    buffer.write('lastUpdated=${json['lastUpdated']}&');
    buffer.write('candleCount=${(json['candles'] as List).length}');
    // Note: This is simplified - full implementation would serialize all candle data
    return buffer.toString();
  }
  
  /// Get candles for a symbol at a specific timeframe
  /// Uses cache or aggregates from raw data
  List<Candle> getCandles(String symbol, Timeframe timeframe) {
    // Check cache first
    final cache = _aggregationCache[symbol];
    if (cache != null && cache.containsKey(timeframe)) {
      final candles = cache[timeframe]!;
      return _applyReplayFilter(candles);
    }
    
    // Get raw data
    final rawData = _rawCandleStore[symbol];
    if (rawData == null) {
      return [];
    }
    
    // If same timeframe as raw, return directly
    if (rawData.baseTimeframe == timeframe) {
      return _applyReplayFilter(rawData.candles);
    }
    
    // Aggregate to requested timeframe
    final aggregated = _aggregateCandles(rawData.candles, rawData.baseTimeframe, timeframe);
    
    // Cache the result
    _aggregationCache.putIfAbsent(symbol, () => {});
    _aggregationCache[symbol]![timeframe] = aggregated;
    
    return _applyReplayFilter(aggregated);
  }
  
  /// Apply replay filter (only show candles <= cursor time)
  List<Candle> _applyReplayFilter(List<Candle> candles) {
    if (!_isReplayMode || _replayCursorTime == null) {
      return candles;
    }
    
    return candles.where((c) => !c.timestamp.isAfter(_replayCursorTime!)).toList();
  }
  
  /// Aggregate candles from one timeframe to another
  List<Candle> _aggregateCandles(List<Candle> source, Timeframe from, Timeframe to) {
    if (source.isEmpty) return [];
    
    // Can only aggregate to larger timeframes
    if (to.duration <= from.duration) {
      return source;
    }
    
    final Map<int, List<Candle>> buckets = {};
    
    for (final candle in source) {
      final bucketStart = _getBucketStart(candle.timestamp, to);
      final bucketKey = bucketStart.millisecondsSinceEpoch;
      
      buckets.putIfAbsent(bucketKey, () => []);
      buckets[bucketKey]!.add(candle);
    }
    
    final aggregated = <Candle>[];
    
    for (final entry in buckets.entries) {
      final bucket = entry.value;
      if (bucket.isEmpty) continue;
      
      // Sort bucket by time
      bucket.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      final open = bucket.first.open;
      final close = bucket.last.close;
      final high = bucket.map((c) => c.high).reduce((a, b) => a > b ? a : b);
      final low = bucket.map((c) => c.low).reduce((a, b) => a < b ? a : b);
      final volume = bucket.map((c) => c.volume).reduce((a, b) => a + b);
      
      aggregated.add(Candle(
        timestamp: DateTime.fromMillisecondsSinceEpoch(entry.key),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));
    }
    
    aggregated.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return aggregated;
  }
  
  /// Get the start of a timeframe bucket for a given timestamp
  DateTime _getBucketStart(DateTime time, Timeframe timeframe) {
    switch (timeframe) {
      case Timeframe.m1:
        return DateTime(time.year, time.month, time.day, time.hour, time.minute);
      case Timeframe.m5:
        return DateTime(time.year, time.month, time.day, time.hour, (time.minute ~/ 5) * 5);
      case Timeframe.m15:
        return DateTime(time.year, time.month, time.day, time.hour, (time.minute ~/ 15) * 15);
      case Timeframe.m30:
        return DateTime(time.year, time.month, time.day, time.hour, (time.minute ~/ 30) * 30);
      case Timeframe.h1:
        return DateTime(time.year, time.month, time.day, time.hour);
      case Timeframe.h4:
        return DateTime(time.year, time.month, time.day, (time.hour ~/ 4) * 4);
      case Timeframe.d1:
        return DateTime(time.year, time.month, time.day);
      case Timeframe.w1:
        final weekday = time.weekday;
        return DateTime(time.year, time.month, time.day - (weekday - 1));
      case Timeframe.mn1:
        return DateTime(time.year, time.month, 1);
    }
  }
  
  /// Update the last candle with a live price tick
  void updateWithLivePrice(String symbol, LivePrice price, Timeframe currentTimeframe) {
    if (_isReplayMode) return; // Don't update in replay mode
    
    final rawData = _rawCandleStore[symbol];
    if (rawData == null || rawData.candles.isEmpty) return;
    
    final candles = List<Candle>.from(rawData.candles);
    final lastCandle = candles.last;
    
    // Update the last candle
    final updatedCandle = Candle(
      timestamp: lastCandle.timestamp,
      open: lastCandle.open,
      high: price.price > lastCandle.high ? price.price : lastCandle.high,
      low: price.price < lastCandle.low ? price.price : lastCandle.low,
      close: price.price,
      volume: lastCandle.volume,
    );
    
    candles[candles.length - 1] = updatedCandle;
    
    // Update store (without persisting every tick)
    _rawCandleStore[symbol] = PersistedCandleData(
      symbol: symbol,
      baseTimeframe: rawData.baseTimeframe,
      candles: candles,
      lastUpdated: DateTime.now(),
    );
    
    // Clear aggregation cache
    _aggregationCache.remove(symbol);
    
    _notifyListeners();
  }
  
  /// Check if we have data for a symbol
  bool hasData(String symbol) => _rawCandleStore.containsKey(symbol);
  
  /// Get the last update time for a symbol
  DateTime? getLastUpdateTime(String symbol) => _rawCandleStore[symbol]?.lastUpdated;
  
  /// Get available time range for a symbol
  (DateTime?, DateTime?) getTimeRange(String symbol) {
    final data = _rawCandleStore[symbol];
    if (data == null || data.candles.isEmpty) {
      return (null, null);
    }
    return (data.candles.first.timestamp, data.candles.last.timestamp);
  }
  
  // ==================== REPLAY MODE ====================
  
  /// Enter replay mode
  void enterReplayMode() {
    _isReplayMode = true;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _notifyListeners();
  }
  
  /// Exit replay mode and return to live
  void exitReplayMode() {
    _isReplayMode = false;
    _replayCursorTime = null;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _notifyListeners();
  }
  
  /// Set replay cursor to a specific time
  void setReplayCursor(DateTime time) {
    _replayCursorTime = time;
    _notifyListeners();
  }
  
  /// Start playback
  void play() {
    if (!_isReplayMode) return;
    _isPlaying = true;
    _startPlaybackTimer();
    _notifyListeners();
  }
  
  /// Pause playback
  void pause() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _notifyListeners();
  }
  
  /// Set playback speed (1.0 = realtime, 2.0 = 2x, etc.)
  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _startPlaybackTimer();
    }
  }
  
  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    
    // Advance cursor every 100ms (scaled by playback speed)
    final interval = Duration(milliseconds: (100 / _playbackSpeed).round());
    
    _playbackTimer = Timer.periodic(interval, (_) {
      if (_replayCursorTime == null) return;
      
      // Advance by 1 minute per tick (adjust based on timeframe)
      _replayCursorTime = _replayCursorTime!.add(const Duration(minutes: 1));
      _notifyListeners();
    });
  }
  
  // ==================== LISTENERS ====================
  
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
  
  // ==================== CLEANUP ====================
  
  /// Clear all cached data (for debugging)
  Future<void> clearAllData() async {
    _rawCandleStore.clear();
    _aggregationCache.clear();
    await _candleBox?.clear();
    _notifyListeners();
  }
  
  /// Dispose resources
  void dispose() {
    _playbackTimer?.cancel();
    _listeners.clear();
  }
}

typedef VoidCallback = void Function();


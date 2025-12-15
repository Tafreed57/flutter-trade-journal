import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/logger.dart';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';

/// Key for storing candles: symbol + timeframe
class CandleKey {
  final String symbol;
  final Timeframe timeframe;
  
  CandleKey(this.symbol, this.timeframe);
  
  String get key => '${symbol}_${timeframe.name}';
  
  @override
  bool operator ==(Object other) =>
      other is CandleKey && other.symbol == symbol && other.timeframe == timeframe;
  
  @override
  int get hashCode => symbol.hashCode ^ timeframe.hashCode;
}

/// Persisted candle data for a symbol + timeframe
class PersistedCandleData {
  final String symbol;
  final Timeframe timeframe;
  final List<Candle> candles;
  final DateTime lastUpdated;
  
  PersistedCandleData({
    required this.symbol,
    required this.timeframe,
    required this.candles,
    required this.lastUpdated,
  });
  
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'timeframe': timeframe.index,
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
      timeframe: Timeframe.values[json['timeframe'] as int],
      candles: candlesList,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int),
    );
  }
}

/// Central market data engine that manages:
/// - Candle storage per (symbol, timeframe) pair
/// - Live price updates
/// - Replay state
/// 
/// FIXED ARCHITECTURE:
/// - Each (symbol, timeframe) pair has its own candle series
/// - No more "aggregation from base timeframe" which couldn't disaggregate
/// - Timeframe switching now properly loads different data
class MarketDataEngine {
  static MarketDataEngine? _instance;
  static MarketDataEngine get instance => _instance ??= MarketDataEngine._();
  
  MarketDataEngine._();
  
  // Persistence
  Box<String>? _candleBox;
  static const String _boxName = 'candle_history_v2'; // New version for new format
  static const int _maxCandlesPerSeries = 2000;
  
  // Candle storage: keyed by "symbol_timeframe"
  // FIXED: Each timeframe has its own series (not derived from a base)
  final Map<String, PersistedCandleData> _candleStore = {};
  
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
      Log.i('MarketDataEngine initialized with ${_candleStore.length} series');
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
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final data = PersistedCandleData.fromJson(json);
          final storeKey = CandleKey(data.symbol, data.timeframe).key;
          _candleStore[storeKey] = data;
          Log.d('Loaded ${data.candles.length} candles for ${data.symbol} ${data.timeframe.label}');
        }
      } catch (e) {
        Log.e('Error loading persisted data for $key', e);
      }
    }
  }
  
  /// Store candles for a symbol + timeframe pair
  /// FIXED: Each timeframe is stored separately
  Future<void> storeCandles(String symbol, List<Candle> candles, Timeframe timeframe) async {
    if (candles.isEmpty) return;
    
    final storeKey = CandleKey(symbol, timeframe).key;
    
    // Get existing data for this specific series
    final existing = _candleStore[storeKey];
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
    if (mergedCandles.length > _maxCandlesPerSeries) {
      mergedCandles = mergedCandles.sublist(mergedCandles.length - _maxCandlesPerSeries);
    }
    
    // Store
    final data = PersistedCandleData(
      symbol: symbol,
      timeframe: timeframe,
      candles: mergedCandles,
      lastUpdated: DateTime.now(),
    );
    
    _candleStore[storeKey] = data;
    
    // Persist to Hive
    await _persistData(storeKey, data);
    
    Log.d('Stored ${mergedCandles.length} candles for $symbol ${timeframe.label}');
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
  Future<void> _persistData(String key, PersistedCandleData data) async {
    if (_candleBox == null) return;
    
    try {
      final jsonStr = jsonEncode(data.toJson());
      await _candleBox!.put(key, jsonStr);
    } catch (e) {
      Log.e('Error persisting data for $key', e);
    }
  }
  
  /// Get candles for a symbol at a specific timeframe
  /// FIXED: Returns the specific series for this (symbol, timeframe) pair
  List<Candle> getCandles(String symbol, Timeframe timeframe) {
    final storeKey = CandleKey(symbol, timeframe).key;
    final data = _candleStore[storeKey];
    
    if (data == null) {
      Log.d('No candles found for $symbol ${timeframe.label}');
      return [];
    }
    
    Log.d('Returning ${data.candles.length} candles for $symbol ${timeframe.label}');
    return _applyReplayFilter(data.candles);
  }
  
  /// Apply replay filter (only show candles <= cursor time)
  List<Candle> _applyReplayFilter(List<Candle> candles) {
    if (!_isReplayMode || _replayCursorTime == null) {
      return candles;
    }
    
    return candles.where((c) => !c.timestamp.isAfter(_replayCursorTime!)).toList();
  }
  
  /// Update the last candle with a live price tick
  /// FIXED: Updates the specific timeframe series
  void updateWithLivePrice(String symbol, LivePrice price, Timeframe currentTimeframe) {
    if (_isReplayMode) return;
    
    final storeKey = CandleKey(symbol, currentTimeframe).key;
    final data = _candleStore[storeKey];
    
    if (data == null || data.candles.isEmpty) return;
    
    final candles = List<Candle>.from(data.candles);
    final lastCandle = candles.last;
    
    // INVARIANT CHECK: Detect mega-candle bug early
    // If the price deviates more than 5% from the current candle's price range,
    // something is wrong with the price sync
    final maxExpectedMove = lastCandle.close * 0.05; // 5% tolerance
    final priceDeviation = (price.price - lastCandle.close).abs();
    
    if (priceDeviation > maxExpectedMove) {
      Log.w('MEGA-CANDLE PREVENTION: Price deviation ${(priceDeviation / lastCandle.close * 100).toStringAsFixed(1)}% detected!');
      Log.w('  Timeframe: ${currentTimeframe.label}');
      Log.w('  Last candle OHLC: O=${lastCandle.open.toStringAsFixed(2)}, H=${lastCandle.high.toStringAsFixed(2)}, L=${lastCandle.low.toStringAsFixed(2)}, C=${lastCandle.close.toStringAsFixed(2)}');
      Log.w('  Incoming price: ${price.price.toStringAsFixed(2)}');
      Log.w('  Skipping this tick to prevent chart corruption');
      return; // Skip this tick - it would create a mega candle
    }
    
    // Update the last candle
    final updatedCandle = Candle(
      timestamp: lastCandle.timestamp,
      open: lastCandle.open,
      high: price.price > lastCandle.high ? price.price : lastCandle.high,
      low: price.price < lastCandle.low ? price.price : lastCandle.low,
      close: price.price,
      volume: lastCandle.volume,
    );
    
    // INVARIANT: Validate OHLC relationships
    assert(updatedCandle.high >= updatedCandle.open, 'High must be >= open');
    assert(updatedCandle.high >= updatedCandle.close, 'High must be >= close');
    assert(updatedCandle.low <= updatedCandle.open, 'Low must be <= open');
    assert(updatedCandle.low <= updatedCandle.close, 'Low must be <= close');
    assert(updatedCandle.low <= updatedCandle.high, 'Low must be <= high');
    
    candles[candles.length - 1] = updatedCandle;
    
    // Update store (without persisting every tick for performance)
    _candleStore[storeKey] = PersistedCandleData(
      symbol: symbol,
      timeframe: currentTimeframe,
      candles: candles,
      lastUpdated: DateTime.now(),
    );
    
    _notifyListeners();
  }
  
  /// Check if we have data for a symbol + timeframe pair
  /// FIXED: Checks specific timeframe, not just symbol
  bool hasData(String symbol, Timeframe timeframe) {
    final storeKey = CandleKey(symbol, timeframe).key;
    final data = _candleStore[storeKey];
    return data != null && data.candles.isNotEmpty;
  }
  
  /// Get the last update time for a symbol + timeframe
  DateTime? getLastUpdateTime(String symbol, Timeframe timeframe) {
    final storeKey = CandleKey(symbol, timeframe).key;
    return _candleStore[storeKey]?.lastUpdated;
  }
  
  /// Get available time range for a symbol + timeframe
  (DateTime?, DateTime?) getTimeRange(String symbol, Timeframe timeframe) {
    final storeKey = CandleKey(symbol, timeframe).key;
    final data = _candleStore[storeKey];
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
    _candleStore.clear();
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

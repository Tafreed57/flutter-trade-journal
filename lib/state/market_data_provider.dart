import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/env_config.dart';
import '../core/logger.dart';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';
import '../services/finnhub_repository.dart';
import '../services/market_data_engine.dart';
import '../services/market_data_repository.dart';
import '../services/mock_market_data.dart';

/// State management for market data
/// 
/// NEW ARCHITECTURE:
/// - Uses MarketDataEngine for persistence and caching
/// - Timeframe changes reuse cached data (no regeneration)
/// - Data persists across app restarts
/// - Supports replay mode
/// 
/// Responsibilities:
/// - Symbol/timeframe selection
/// - Loading data from repository → storing in engine
/// - Live price subscriptions
/// - Providing data to UI (via engine)
class MarketDataProvider extends ChangeNotifier {
  MarketDataRepository? _repository;
  bool _useMockData = false;
  
  // Current state
  String _currentSymbol = 'AAPL';
  Timeframe _currentTimeframe = Timeframe.h1;
  LivePrice? _lastPrice;
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;
  
  // Subscriptions
  StreamSubscription<LivePrice>? _priceSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  
  // Engine reference
  final MarketDataEngine _engine = MarketDataEngine.instance;
  
  // Getters
  String get currentSymbol => _currentSymbol;
  Timeframe get currentTimeframe => _currentTimeframe;
  
  /// Get candles from the engine (not regenerated each time!)
  List<Candle> get candles => _engine.getCandles(_currentSymbol, _currentTimeframe);
  
  LivePrice? get lastPrice => _lastPrice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isConnected => _isConnected;
  bool get isConfigured => EnvConfig.isFinnhubConfigured || _useMockData;
  bool get isMockMode => _useMockData;
  
  // Replay mode passthrough
  bool get isReplayMode => _engine.isReplayMode;
  DateTime? get replayCursorTime => _engine.replayCursorTime;
  bool get isPlaying => _engine.isPlaying;
  
  /// Initialize the market data provider
  Future<void> init() async {
    // Initialize the engine first (loads persisted data)
    await _engine.init();
    
    // Listen to engine changes
    _engine.addListener(_onEngineUpdate);
    
    // Check if we have cached data for current symbol
    if (_engine.hasData(_currentSymbol)) {
      Log.i('Loaded cached data for $_currentSymbol');
      // Data is already available, just notify
      notifyListeners();
      
      // Still connect to live updates
      await _initRepository();
      return;
    }
    
    // No cached data, load from repository
    await _initRepository();
  }
  
  Future<void> _initRepository() async {
    // If no API key, use mock data directly
    if (!EnvConfig.isFinnhubConfigured) {
      Log.i('No Finnhub API key, using mock data');
      await _initMockData();
      return;
    }
    
    try {
      _repository = FinnhubMarketDataRepository(
        apiKey: EnvConfig.finnhubApiKey!,
      );
      
      await _repository!.init();
      
      // Listen to connection state
      _connectionSubscription = _repository!.connectionState.listen((connected) {
        _isConnected = connected;
        notifyListeners();
      });
      
      _isConnected = _repository!.isConnected;
      _error = null;
      
      // Try to load initial data - if it fails with 403, switch to mock
      await loadCandles();
      
      // If we got a 403 error, switch to mock data
      if (_error != null && _error!.contains('403')) {
        Log.w('Finnhub 403 error (paid feature), switching to mock data');
        await _initMockData();
        return;
      }
      
      subscribeToPrice();
      
    } catch (e) {
      _error = 'Failed to initialize market data: $e';
      Log.e('MarketDataProvider init error', e);
      
      // Fallback to mock data
      Log.i('Falling back to mock data');
      await _initMockData();
    }
    
    notifyListeners();
  }
  
  void _onEngineUpdate() {
    notifyListeners();
  }
  
  /// Initialize with mock data (for demo/development)
  Future<void> _initMockData() async {
    // IMPORTANT: Dispose old repository first to stop WebSocket reconnection loops
    _priceSubscription?.cancel();
    _priceSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _repository?.dispose();
    
    _useMockData = true;
    _repository = MockMarketDataRepository();
    await _repository!.init();
    _isConnected = true;
    _error = null;
    
    await loadCandles();
    subscribeToPrice();
    
    notifyListeners();
  }
  
  /// Toggle mock data mode
  Future<void> toggleMockMode() async {
    _useMockData = !_useMockData;
    _priceSubscription?.cancel();
    _connectionSubscription?.cancel();
    _repository?.dispose();
    
    if (_useMockData) {
      await _initMockData();
    } else {
      await _initRepository();
    }
  }
  
  /// Change the current symbol
  Future<void> setSymbol(String symbol) async {
    if (symbol == _currentSymbol) return;
    
    // Unsubscribe from old symbol
    if (_repository != null) {
      _repository!.unsubscribeFromLivePrice(_currentSymbol);
    }
    
    _currentSymbol = symbol.toUpperCase();
    _lastPrice = null;
    
    // Check if we have cached data
    if (_engine.hasData(_currentSymbol)) {
      Log.i('Using cached data for $_currentSymbol');
      notifyListeners();
      subscribeToPrice();
      return;
    }
    
    // Load new data
    await loadCandles();
    subscribeToPrice();
  }
  
  /// Change the current timeframe
  /// 
  /// FIXED: This now uses cached/aggregated data instead of regenerating!
  Future<void> setTimeframe(Timeframe timeframe) async {
    if (timeframe == _currentTimeframe) return;
    
    _currentTimeframe = timeframe;
    
    // If we have data, the engine will aggregate it automatically
    // No need to reload from repository!
    if (_engine.hasData(_currentSymbol)) {
      Log.d('Using cached data for $_currentSymbol at ${timeframe.label}');
      notifyListeners();
      return;
    }
    
    // No cached data, load from repository
    await loadCandles();
  }
  
  /// Load historical candles for current symbol/timeframe
  Future<void> loadCandles() async {
    if (_repository == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final now = DateTime.now();
      final from = _currentTimeframe.getFromDate(now);
      
      final newCandles = await _repository!.getHistoricalCandles(
        _currentSymbol,
        _currentTimeframe,
        from,
        now,
      );
      
      if (newCandles.isEmpty) {
        _error = 'No data available for $_currentSymbol';
      } else {
        // Store in engine (persisted!)
        await _engine.storeCandles(_currentSymbol, newCandles, _currentTimeframe);
        Log.i('Stored ${newCandles.length} candles for $_currentSymbol');
      }
      
    } catch (e) {
      _error = 'Failed to load chart data: $e';
      // Don't log 403 as error - will fall back to mock data
      if (!e.toString().contains('403')) {
        Log.e('Error loading candles', e);
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Subscribe to real-time price updates
  void subscribeToPrice() {
    if (_repository == null) return;
    
    _priceSubscription?.cancel();
    
    _priceSubscription = _repository!
        .subscribeToLivePrice(_currentSymbol)
        .listen((price) {
      _lastPrice = price;
      
      // Update the engine (which updates the last candle)
      _engine.updateWithLivePrice(_currentSymbol, price, _currentTimeframe);
      
      notifyListeners();
    });
  }
  
  /// Search for symbols
  Future<List<SymbolInfo>> searchSymbols(String query) async {
    if (_repository == null || query.length < 2) {
      return [];
    }
    
    try {
      return await _repository!.searchSymbols(query);
    } catch (e) {
      Log.e('Error searching symbols', e);
      return [];
    }
  }
  
  /// Get current quote for a symbol
  Future<Quote?> getQuote(String symbol) async {
    if (_repository == null) return null;
    
    try {
      return await _repository!.getQuote(symbol);
    } catch (e) {
      Log.e('Error getting quote', e);
      return null;
    }
  }
  
  /// Refresh current data (force reload from repository)
  Future<void> refresh() async {
    await loadCandles();
  }
  
  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // ==================== REPLAY MODE ====================
  
  /// Enter replay mode
  void enterReplayMode() {
    _engine.enterReplayMode();
    // Set cursor to the start of available data
    final (start, _) = _engine.getTimeRange(_currentSymbol);
    if (start != null) {
      _engine.setReplayCursor(start);
    }
  }
  
  /// Exit replay mode
  void exitReplayMode() {
    _engine.exitReplayMode();
  }
  
  /// Set replay cursor
  void setReplayCursor(DateTime time) {
    _engine.setReplayCursor(time);
  }
  
  /// Play replay
  void playReplay() {
    _engine.play();
  }
  
  /// Pause replay
  void pauseReplay() {
    _engine.pause();
  }
  
  /// Get time range for replay slider
  (DateTime?, DateTime?) getTimeRange() {
    return _engine.getTimeRange(_currentSymbol);
  }
  
  // ==================== CLEANUP ====================
  
  /// Clear all cached chart data (for debugging)
  Future<void> clearCache() async {
    await _engine.clearAllData();
    await loadCandles();
  }
  
  @override
  void dispose() {
    _priceSubscription?.cancel();
    _connectionSubscription?.cancel();
    _repository?.dispose();
    _engine.removeListener(_onEngineUpdate);
    super.dispose();
  }
}

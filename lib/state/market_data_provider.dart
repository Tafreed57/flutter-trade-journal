import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/env_config.dart';
import '../core/logger.dart';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';
import '../services/finnhub_repository.dart';
import '../services/market_data_repository.dart';
import '../services/mock_market_data.dart';

/// State management for market data
/// 
/// Handles:
/// - Loading historical candles
/// - Real-time price subscriptions
/// - Symbol/timeframe selection
/// - Error states
/// - Auto-fallback to mock data when Finnhub fails (free tier limitation)
class MarketDataProvider extends ChangeNotifier {
  MarketDataRepository? _repository;
  bool _useMockData = false;
  
  // Current state
  String _currentSymbol = 'AAPL';
  Timeframe _currentTimeframe = Timeframe.h1;
  List<Candle> _candles = [];
  LivePrice? _lastPrice;
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;
  
  // Subscriptions
  StreamSubscription<LivePrice>? _priceSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  
  // Getters
  String get currentSymbol => _currentSymbol;
  Timeframe get currentTimeframe => _currentTimeframe;
  List<Candle> get candles => List.unmodifiable(_candles);
  LivePrice? get lastPrice => _lastPrice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isConnected => _isConnected;
  bool get isConfigured => EnvConfig.isFinnhubConfigured || _useMockData;
  bool get isMockMode => _useMockData;
  
  /// Initialize the market data provider
  Future<void> init() async {
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
      await init();
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
    
    // Load new data
    await loadCandles();
    subscribeToPrice();
  }
  
  /// Change the current timeframe
  Future<void> setTimeframe(Timeframe timeframe) async {
    if (timeframe == _currentTimeframe) return;
    
    _currentTimeframe = timeframe;
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
      
      _candles = await _repository!.getHistoricalCandles(
        _currentSymbol,
        _currentTimeframe,
        from,
        now,
      );
      
      if (_candles.isEmpty) {
        _error = 'No data available for $_currentSymbol';
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
      
      // Update the last candle with new price (for live chart updates)
      _updateLastCandleWithPrice(price);
      
      notifyListeners();
    });
  }
  
  /// Update the last candle with a new price tick
  /// 
  /// For intraday timeframes: Updates the current candle or creates a new one
  /// For daily+ timeframes: Only updates the last candle's close price (no new candles)
  void _updateLastCandleWithPrice(LivePrice price) {
    if (_candles.isEmpty) return;
    
    // Only update if the price is for the current symbol
    if (price.symbol != _currentSymbol) return;
    
    // Get the last candle
    final lastCandle = _candles.last;
    
    // For daily and higher timeframes, just update the close price
    // Don't create new candles as live data comes in too frequently
    if (_currentTimeframe == Timeframe.d1 || 
        _currentTimeframe == Timeframe.w1 || 
        _currentTimeframe == Timeframe.mn1) {
      // Only update the last candle's close (simulates live trading)
      final updatedCandle = Candle(
        timestamp: lastCandle.timestamp,
        open: lastCandle.open,
        high: price.price > lastCandle.high ? price.price : lastCandle.high,
        low: price.price < lastCandle.low ? price.price : lastCandle.low,
        close: price.price,
        volume: lastCandle.volume,
      );
      
      _candles = [..._candles.sublist(0, _candles.length - 1), updatedCandle];
      return;
    }
    
    // For intraday timeframes, check if we need a new candle
    final candleEnd = lastCandle.timestamp.add(_currentTimeframe.duration);
    
    if (price.timestamp.isBefore(candleEnd)) {
      // Update the existing candle
      final updatedCandle = Candle(
        timestamp: lastCandle.timestamp,
        open: lastCandle.open,
        high: price.price > lastCandle.high ? price.price : lastCandle.high,
        low: price.price < lastCandle.low ? price.price : lastCandle.low,
        close: price.price,
        volume: lastCandle.volume + (price.volume ?? 0),
      );
      
      _candles = [..._candles.sublist(0, _candles.length - 1), updatedCandle];
    } else {
      // Create a new candle for intraday only
      final newCandle = Candle(
        timestamp: candleEnd,
        open: price.price,
        high: price.price,
        low: price.price,
        close: price.price,
        volume: price.volume ?? 0,
      );
      
      _candles = [..._candles, newCandle];
    }
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
  
  /// Refresh current data
  Future<void> refresh() async {
    await loadCandles();
  }
  
  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _priceSubscription?.cancel();
    _connectionSubscription?.cancel();
    _repository?.dispose();
    super.dispose();
  }
}


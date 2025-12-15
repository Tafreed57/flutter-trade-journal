import 'dart:async';
import 'dart:math';
import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';
import 'market_data_repository.dart';

/// Mock market data provider for development/demo
/// 
/// FIXED ARCHITECTURE:
/// - Uses SAME seed for all timeframes (consistent price history)
/// - Larger timeframes are aggregated from base 1m data
/// - Live price updates from the consistent last close
/// - No more "giant red candle" bug from different price paths
class MockMarketDataRepository implements MarketDataRepository {
  // Base prices for common symbols (realistic Dec 2024 values)
  static const Map<String, double> _basePrices = {
    'AAPL': 195.0,
    'GOOGL': 175.0,
    'MSFT': 430.0,
    'AMZN': 225.0,
    'TSLA': 395.0,
    'META': 580.0,
    'NVDA': 140.0,
    'JPM': 245.0,
    'V': 310.0,
    'WMT': 95.0,
  };
  
  // Current simulated prices (for live updates)
  final Map<String, double> _currentPrices = {};
  
  // Active price streams
  final Map<String, StreamController<LivePrice>> _priceStreams = {};
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Timer? _priceUpdateTimer;
  bool _isConnected = false;

  @override
  Future<void> init() async {
    _isConnected = true;
    _connectionController.add(true);
  }

  @override
  Future<void> dispose() async {
    _priceUpdateTimer?.cancel();
    for (final controller in _priceStreams.values) {
      controller.close();
    }
    _priceStreams.clear();
    _connectionController.close();
  }

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  Future<List<Candle>> getHistoricalCandles(
    String symbol,
    Timeframe timeframe,
    DateTime from,
    DateTime to,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    final basePrice = _basePrices[symbol] ?? 100.0;
    final candles = <Candle>[];
    
    // FIXED: Use SAME seed for ALL timeframes per symbol
    // This ensures all timeframes show consistent price history
    final symbolSeed = symbol.hashCode;
    final seededRandom = Random(symbolSeed);
    
    // Calculate proper candle intervals
    final intervalDuration = timeframe.duration;
    
    // Start price with small variance from base
    var currentPrice = basePrice * (0.95 + seededRandom.nextDouble() * 0.10);
    
    // Find the most recent trading day/time to start from
    var startTime = _findLastTradingTime(from, timeframe);
    var currentTime = _alignToTimeframe(startTime, timeframe);
    
    // For short timeframes, ensure we generate enough candles
    final targetCandleCount = timeframe.defaultCandleCount;
    
    // Safety limit to prevent infinite loops
    int iterations = 0;
    const maxIterations = 20000;
    
    // Generate consistent volatility based on timeframe
    // Use a sub-random for volatility so it's still predictable
    final volatilityRandom = Random(symbolSeed + timeframe.index * 1000);
    
    while (candles.length < targetCandleCount && iterations < maxIterations) {
      iterations++;
      
      // Skip weekends and non-trading hours
      if (_shouldSkipTime(currentTime, timeframe)) {
        currentTime = currentTime.add(intervalDuration);
        continue;
      }
      
      final candle = _generateRealisticCandle(
        currentTime, 
        currentPrice, 
        timeframe, 
        seededRandom,
        volatilityRandom,
      );
      candles.add(candle);
      
      // Next candle opens at this candle's close
      currentPrice = candle.close;
      currentTime = currentTime.add(intervalDuration);
    }
    
    // Store the last price for live updates
    if (candles.isNotEmpty) {
      _currentPrices[symbol] = candles.last.close;
    }
    
    return candles;
  }
  
  /// Find the most recent valid trading time before the given time
  DateTime _findLastTradingTime(DateTime time, Timeframe timeframe) {
    var adjusted = time;
    
    // Go back up to 7 days to find a trading day
    for (int i = 0; i < 7 * 24 * 60; i++) {
      if (!_shouldSkipTime(adjusted, timeframe)) {
        return adjusted;
      }
      adjusted = adjusted.subtract(const Duration(minutes: 1));
    }
    
    return time.subtract(const Duration(days: 7));
  }
  
  /// Align a datetime to the start of a timeframe period
  DateTime _alignToTimeframe(DateTime time, Timeframe timeframe) {
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
  
  /// Check if we should skip this time (weekends, non-trading hours)
  bool _shouldSkipTime(DateTime time, Timeframe timeframe) {
    // Skip weekends for all timeframes
    if (time.weekday == DateTime.saturday || time.weekday == DateTime.sunday) {
      return true;
    }
    
    // For intraday, skip non-trading hours (simplified: 9:30 AM - 4:00 PM)
    if (timeframe != Timeframe.d1 && 
        timeframe != Timeframe.w1 && 
        timeframe != Timeframe.mn1) {
      final hour = time.hour;
      if (hour < 9 || hour >= 16) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Generate a realistic-looking candle with CONSISTENT behavior across timeframes
  Candle _generateRealisticCandle(
    DateTime timestamp, 
    double previousClose, 
    Timeframe timeframe, 
    Random priceRandom,
    Random volatilityRandom,
  ) {
    // Volatility based on timeframe (higher timeframes = more movement)
    final volatility = switch (timeframe) {
      Timeframe.m1 => 0.0005,
      Timeframe.m5 => 0.001,
      Timeframe.m15 => 0.0015,
      Timeframe.m30 => 0.002,
      Timeframe.h1 => 0.003,
      Timeframe.h4 => 0.005,
      Timeframe.d1 => 0.012,
      Timeframe.w1 => 0.025,
      Timeframe.mn1 => 0.05,
    };
    
    // Slight upward bias (stocks tend to drift up over time)
    final bias = 0.0002;
    
    // Calculate open (slight gap from previous close occasionally)
    final gapChance = priceRandom.nextDouble();
    final gap = gapChance > 0.92 
        ? (priceRandom.nextDouble() - 0.5) * volatility * previousClose * 0.3
        : 0.0;
    final open = previousClose + gap;
    
    // Determine if bullish or bearish candle (52% bullish bias)
    final isBullish = priceRandom.nextDouble() < 0.52;
    
    // Body size as percentage of volatility
    final bodyPercent = 0.3 + volatilityRandom.nextDouble() * 0.7;
    final bodySize = volatility * open * bodyPercent;
    
    // Calculate close
    final close = isBullish 
        ? open + bodySize + (bias * open)
        : open - bodySize + (bias * open);
    
    // Calculate high and low with wicks
    final upperWickMultiplier = isBullish ? 0.3 : 0.6;
    final lowerWickMultiplier = isBullish ? 0.6 : 0.3;
    
    final upperWick = volatilityRandom.nextDouble() * upperWickMultiplier * bodySize;
    final lowerWick = volatilityRandom.nextDouble() * lowerWickMultiplier * bodySize;
    
    final high = max(open, close) + upperWick;
    final low = min(open, close) - lowerWick;
    
    // Volume varies by timeframe and randomness
    final baseVolume = switch (timeframe) {
      Timeframe.m1 => 5000,
      Timeframe.m5 => 25000,
      Timeframe.m15 => 75000,
      Timeframe.m30 => 150000,
      Timeframe.h1 => 300000,
      Timeframe.h4 => 1200000,
      Timeframe.d1 => 50000000,
      Timeframe.w1 => 250000000,
      Timeframe.mn1 => 1000000000,
    };
    final volume = (baseVolume * (0.5 + volatilityRandom.nextDouble())).toDouble();
    
    return Candle(
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  @override
  Stream<LivePrice> subscribeToLivePrice(String symbol) {
    if (!_priceStreams.containsKey(symbol)) {
      _priceStreams[symbol] = StreamController<LivePrice>.broadcast();
      
      // Initialize price if not set
      if (!_currentPrices.containsKey(symbol)) {
        _currentPrices[symbol] = _basePrices[symbol] ?? 100.0;
      }
    }
    
    _startPriceUpdates();
    
    return _priceStreams[symbol]!.stream;
  }

  @override
  void unsubscribeFromLivePrice(String symbol) {
    _priceStreams[symbol]?.close();
    _priceStreams.remove(symbol);
    
    if (_priceStreams.isEmpty) {
      _priceUpdateTimer?.cancel();
      _priceUpdateTimer = null;
    }
  }

  @override
  void unsubscribeFromAll() {
    for (final controller in _priceStreams.values) {
      controller.close();
    }
    _priceStreams.clear();
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = null;
  }

  @override
  Future<List<SymbolInfo>> searchSymbols(String query) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    final upperQuery = query.toUpperCase();
    return _basePrices.keys
        .where((s) => s.contains(upperQuery))
        .map((s) => SymbolInfo(
          symbol: s,
          description: _getCompanyName(s),
          type: 'Common Stock',
          exchange: 'NASDAQ',
          currency: 'USD',
        ))
        .toList();
  }

  @override
  Future<Quote?> getQuote(String symbol) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    final price = _currentPrices[symbol] ?? _basePrices[symbol] ?? 100.0;
    final random = Random();
    final change = ((random.nextDouble() - 0.5) * 2) * price * 0.02;
    
    return Quote(
      currentPrice: price,
      change: change,
      changePercent: change / price * 100,
      high: price * 1.01,
      low: price * 0.99,
      open: price - change,
      previousClose: price - change,
      timestamp: DateTime.now(),
    );
  }

  void _startPriceUpdates() {
    if (_priceUpdateTimer != null) return;
    
    final random = Random();
    
    // Update prices every 3 seconds
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      for (final entry in _priceStreams.entries) {
        final symbol = entry.key;
        final controller = entry.value;
        
        if (controller.isClosed) continue;
        
        // Small random price change (±0.1%)
        final currentPrice = _currentPrices[symbol] ?? 100.0;
        final change = ((random.nextDouble() - 0.5) * 2) * currentPrice * 0.001;
        final newPrice = currentPrice + change;
        
        _currentPrices[symbol] = newPrice;
        
        controller.add(LivePrice(
          symbol: symbol,
          price: newPrice,
          timestamp: DateTime.now(),
          volume: random.nextInt(5000).toDouble(),
        ));
      }
    });
  }
  
  String _getCompanyName(String symbol) {
    return switch (symbol) {
      'AAPL' => 'Apple Inc.',
      'GOOGL' => 'Alphabet Inc.',
      'MSFT' => 'Microsoft Corporation',
      'AMZN' => 'Amazon.com Inc.',
      'TSLA' => 'Tesla Inc.',
      'META' => 'Meta Platforms Inc.',
      'NVDA' => 'NVIDIA Corporation',
      'JPM' => 'JPMorgan Chase & Co.',
      'V' => 'Visa Inc.',
      'WMT' => 'Walmart Inc.',
      _ => '$symbol Corporation',
    };
  }
}

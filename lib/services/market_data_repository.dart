import '../models/candle.dart';
import '../models/live_price.dart';
import '../models/timeframe.dart';

/// Abstract interface for market data providers
/// 
/// This abstraction allows swapping data providers (e.g., Finnhub → Polygon)
/// without changing the rest of the app. All market data access goes through
/// this interface.
/// 
/// ## Usage Example
/// ```dart
/// final repo = FinnhubMarketDataRepository(apiKey: 'your_key');
/// await repo.init();
/// 
/// // Fetch historical data
/// final candles = await repo.getHistoricalCandles(
///   'AAPL',
///   Timeframe.h1,
///   DateTime.now().subtract(Duration(days: 7)),
///   DateTime.now(),
/// );
/// 
/// // Subscribe to live prices
/// repo.subscribeToLivePrice('AAPL').listen((price) {
///   print('${price.symbol}: \$${price.price}');
/// });
/// ```
abstract class MarketDataRepository {
  /// Initialize the repository (e.g., open WebSocket connection)
  Future<void> init();

  /// Clean up resources (e.g., close WebSocket)
  Future<void> dispose();

  /// Fetch historical OHLCV candlestick data
  /// 
  /// [symbol] - Trading symbol (e.g., "AAPL", "BINANCE:BTCUSDT")
  /// [timeframe] - Chart resolution
  /// [from] - Start date (inclusive)
  /// [to] - End date (inclusive)
  /// 
  /// Returns empty list if no data available or on error.
  Future<List<Candle>> getHistoricalCandles(
    String symbol,
    Timeframe timeframe,
    DateTime from,
    DateTime to,
  );

  /// Subscribe to real-time price updates for a symbol
  /// 
  /// Returns a stream of [LivePrice] updates.
  /// Call [unsubscribeFromLivePrice] when done.
  Stream<LivePrice> subscribeToLivePrice(String symbol);

  /// Unsubscribe from price updates for a symbol
  void unsubscribeFromLivePrice(String symbol);

  /// Unsubscribe from all price updates
  void unsubscribeFromAll();

  /// Search for symbols matching a query
  /// 
  /// Returns list of matching symbols with metadata.
  Future<List<SymbolInfo>> searchSymbols(String query);

  /// Get quote (current price snapshot) for a symbol
  Future<Quote?> getQuote(String symbol);

  /// Sync the current price for a symbol (used when switching timeframes with cached data)
  /// This ensures live price updates use the correct baseline price.
  /// 
  /// CRITICAL: This prevents the "mega candle" bug where cached data uses a different
  /// price level than the live price stream.
  void syncCurrentPrice(String symbol, double price);

  /// Check if the WebSocket connection is active
  bool get isConnected;

  /// Stream of connection state changes
  Stream<bool> get connectionState;
}

/// Symbol search result with metadata
class SymbolInfo {
  final String symbol;
  final String description;
  final String type; // "Common Stock", "Crypto", "Forex", etc.
  final String? exchange;
  final String? currency;

  const SymbolInfo({
    required this.symbol,
    required this.description,
    required this.type,
    this.exchange,
    this.currency,
  });

  factory SymbolInfo.fromFinnhub(Map<String, dynamic> json) {
    return SymbolInfo(
      symbol: json['symbol'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      exchange: json['displaySymbol'] as String?,
      currency: json['currency'] as String?,
    );
  }
}

/// Current price quote snapshot
class Quote {
  final double currentPrice;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final DateTime timestamp;

  const Quote({
    required this.currentPrice,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.timestamp,
  });

  factory Quote.fromFinnhub(Map<String, dynamic> json) {
    return Quote(
      currentPrice: (json['c'] as num).toDouble(),
      change: (json['d'] as num?)?.toDouble() ?? 0,
      changePercent: (json['dp'] as num?)?.toDouble() ?? 0,
      high: (json['h'] as num).toDouble(),
      low: (json['l'] as num).toDouble(),
      open: (json['o'] as num).toDouble(),
      previousClose: (json['pc'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['t'] as int) * 1000,
      ),
    );
  }
}

/// Exception for market data errors
class MarketDataException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const MarketDataException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'MarketDataException: $message${code != null ? ' ($code)' : ''}';
}


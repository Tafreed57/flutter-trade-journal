/// Represents a single OHLC candlestick
/// 
/// Used for chart rendering and technical analysis.
/// Data comes from market data API (e.g., Finnhub).
class Candle {
  /// Unix timestamp in milliseconds
  final DateTime timestamp;
  
  /// Opening price
  final double open;
  
  /// Highest price during the period
  final double high;
  
  /// Lowest price during the period
  final double low;
  
  /// Closing price
  final double close;
  
  /// Trading volume
  final double volume;

  const Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Whether this candle is bullish (close > open)
  bool get isBullish => close >= open;

  /// Whether this candle is bearish (close < open)
  bool get isBearish => close < open;

  /// The body size (absolute difference between open and close)
  double get bodySize => (close - open).abs();

  /// The full range (high - low)
  double get range => high - low;

  /// Upper wick/shadow size
  double get upperWick => high - (isBullish ? close : open);

  /// Lower wick/shadow size
  double get lowerWick => (isBullish ? open : close) - low;

  /// Create from Finnhub API response
  /// 
  /// Finnhub returns arrays for each OHLCV component:
  /// { "c": [closes], "h": [highs], "l": [lows], "o": [opens], "t": [timestamps], "v": [volumes] }
  factory Candle.fromFinnhubIndex(Map<String, dynamic> json, int index) {
    return Candle(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['t'][index] as int) * 1000,
      ),
      open: (json['o'][index] as num).toDouble(),
      high: (json['h'][index] as num).toDouble(),
      low: (json['l'][index] as num).toDouble(),
      close: (json['c'][index] as num).toDouble(),
      volume: (json['v'][index] as num).toDouble(),
    );
  }

  /// Parse a list of candles from Finnhub response
  static List<Candle> listFromFinnhub(Map<String, dynamic> json) {
    // Check if the response has data
    if (json['s'] != 'ok' || json['t'] == null) {
      return [];
    }

    final timestamps = json['t'] as List;
    final candles = <Candle>[];

    for (int i = 0; i < timestamps.length; i++) {
      candles.add(Candle.fromFinnhubIndex(json, i));
    }

    return candles;
  }

  @override
  String toString() {
    return 'Candle(${timestamp.toIso8601String()}, O:$open H:$high L:$low C:$close V:$volume)';
  }
}


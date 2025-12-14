/// Represents a real-time price update from WebSocket
/// 
/// Used for live price display and paper trading execution.
class LivePrice {
  /// Trading symbol (e.g., "AAPL", "BINANCE:BTCUSDT")
  final String symbol;
  
  /// Current price
  final double price;
  
  /// Timestamp of the price update
  final DateTime timestamp;
  
  /// Trading volume (if available)
  final double? volume;
  
  /// Price change from previous update (if available)
  final double? change;
  
  /// Percentage change (if available)
  final double? changePercent;

  const LivePrice({
    required this.symbol,
    required this.price,
    required this.timestamp,
    this.volume,
    this.change,
    this.changePercent,
  });

  /// Create from Finnhub WebSocket trade message
  /// 
  /// Finnhub sends: { "data": [{ "s": "AAPL", "p": 150.25, "t": 1234567890, "v": 100 }], "type": "trade" }
  factory LivePrice.fromFinnhubTrade(Map<String, dynamic> trade) {
    return LivePrice(
      symbol: trade['s'] as String,
      price: (trade['p'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(trade['t'] as int),
      volume: (trade['v'] as num?)?.toDouble(),
    );
  }

  /// Parse multiple prices from Finnhub WebSocket message
  static List<LivePrice> listFromFinnhub(Map<String, dynamic> json) {
    if (json['type'] != 'trade' || json['data'] == null) {
      return [];
    }

    final trades = json['data'] as List;
    return trades
        .map((trade) => LivePrice.fromFinnhubTrade(trade as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() {
    return 'LivePrice($symbol: \$$price @ ${timestamp.toIso8601String()})';
  }
}


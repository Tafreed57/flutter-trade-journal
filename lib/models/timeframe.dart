/// Chart timeframe/resolution options
/// 
/// Used for selecting candlestick chart intervals.
/// Maps to Finnhub resolution parameter.
enum Timeframe {
  m1('1', '1m', Duration(minutes: 1)),
  m5('5', '5m', Duration(minutes: 5)),
  m15('15', '15m', Duration(minutes: 15)),
  m30('30', '30m', Duration(minutes: 30)),
  h1('60', '1H', Duration(hours: 1)),
  h4('240', '4H', Duration(hours: 4)), // Note: Finnhub may not support this directly
  d1('D', '1D', Duration(days: 1)),
  w1('W', '1W', Duration(days: 7)),
  mn1('M', '1M', Duration(days: 30));

  /// Finnhub API resolution parameter
  final String apiValue;
  
  /// Display label for UI
  final String label;
  
  /// Duration of one candle
  final Duration duration;

  const Timeframe(this.apiValue, this.label, this.duration);

  /// Get number of candles to fetch for a reasonable chart view
  /// Returns count for approximately 100-200 candles
  int get defaultCandleCount {
    switch (this) {
      case Timeframe.m1:
        return 200; // ~3.3 hours
      case Timeframe.m5:
        return 200; // ~16.6 hours
      case Timeframe.m15:
        return 200; // ~50 hours
      case Timeframe.m30:
        return 150; // ~75 hours
      case Timeframe.h1:
        return 150; // ~6 days
      case Timeframe.h4:
        return 120; // ~20 days
      case Timeframe.d1:
        return 120; // ~4 months
      case Timeframe.w1:
        return 104; // ~2 years
      case Timeframe.mn1:
        return 60; // ~5 years
    }
  }

  /// Calculate the "from" timestamp for fetching candles
  DateTime getFromDate(DateTime to) {
    return to.subtract(duration * defaultCandleCount);
  }

  /// Common timeframes for quick selection in UI
  static List<Timeframe> get quickSelect => [
    Timeframe.m1,
    Timeframe.m5,
    Timeframe.m15,
    Timeframe.h1,
    Timeframe.d1,
  ];
}


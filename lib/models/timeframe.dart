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

  /// Get number of RAW intervals to request
  /// This accounts for weekends/holidays being skipped
  /// We request more than we need to ensure we get enough valid candles
  int get defaultCandleCount {
    switch (this) {
      case Timeframe.m1:
        return 500; // Request more to account for non-trading hours
      case Timeframe.m5:
        return 500; 
      case Timeframe.m15:
        return 400;
      case Timeframe.m30:
        return 400;
      case Timeframe.h1:
        return 400; // ~16 days raw → ~112 trading hours (16 trading days × 7 hours)
      case Timeframe.h4:
        return 300; // ~50 days raw → ~200+ 4H candles
      case Timeframe.d1:
        return 200; // ~200 days → ~140 trading days
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


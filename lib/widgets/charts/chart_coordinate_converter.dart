import 'dart:math' as math;
import 'dart:ui';
import '../../models/candle.dart';
import '../../models/chart_drawing.dart';

/// Unified coordinate conversion utility for the candlestick chart.
/// 
/// This class provides a single source of truth for all coordinate conversions:
/// - Screen (widget-local) → Chart local (plot area)
/// - Chart local → Data space (price/time)
/// - Data space → Chart local (for rendering)
/// 
/// All drawing tools and hit-testing MUST use this class to ensure consistency.
class ChartCoordinateConverter {
  final List<Candle> candles;
  final double scrollOffset;
  final double candleWidth;
  final double candleGap;
  final double chartWidth;      // Excludes price axis
  final double chartHeight;
  final double priceAxisWidth;
  
  // Calculated price range
  late final double minPrice;
  late final double maxPrice;
  late final double candleStep;
  
  ChartCoordinateConverter({
    required this.candles,
    required this.scrollOffset,
    required this.candleWidth,
    required this.candleGap,
    required this.chartWidth,
    required this.chartHeight,
    this.priceAxisWidth = 60.0,
  }) {
    candleStep = candleWidth * (1 + candleGap);
    _calculateVisiblePriceRange();
  }
  
  /// Calculate the price range for visible candles
  void _calculateVisiblePriceRange() {
    if (candles.isEmpty) {
      minPrice = 0;
      maxPrice = 100;
      return;
    }
    
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);
    
    double min = double.infinity;
    double max = double.negativeInfinity;
    
    for (int i = math.max(0, candles.length - endIndex - 1);
         i < math.min(candles.length, candles.length - startIndex + 1); i++) {
      final candle = candles[i];
      min = math.min(min, candle.low);
      max = math.max(max, candle.high);
    }
    
    if (min.isInfinite || max.isInfinite) {
      minPrice = candles.first.low;
      maxPrice = candles.first.high;
    } else {
      final range = max - min;
      final padding = range * 0.08;
      minPrice = min - padding;
      maxPrice = max + padding;
    }
  }
  
  /// Check if a screen position is within the drawable chart area
  bool isInChartArea(Offset screenPosition) {
    return screenPosition.dx >= 0 &&
           screenPosition.dx < chartWidth &&
           screenPosition.dy >= 0 &&
           screenPosition.dy < chartHeight;
  }
  
  /// Convert screen position to chart point (price + time).
  /// 
  /// This is the PRIMARY method for gesture → data conversion.
  /// Returns null if position is outside chart area.
  ChartPoint? screenToChartPoint(Offset screenPosition) {
    // Clamp to chart bounds
    final clampedX = screenPosition.dx.clamp(0.0, chartWidth);
    final clampedY = screenPosition.dy.clamp(0.0, chartHeight);
    
    // Convert Y to price (top = maxPrice, bottom = minPrice)
    final price = maxPrice - (clampedY / chartHeight) * (maxPrice - minPrice);
    
    // Convert X to timestamp
    // Candles are drawn RIGHT to LEFT (newest on right)
    // scrollOffset shifts the view to the left (showing older candles)
    // 
    // At x=chartWidth (right edge), we show the newest candles
    // At x=0 (left edge), we show older candles
    // 
    // candleIndex 0 = newest candle (at chartWidth when scrollOffset=0)
    // candleIndex increases for older candles
    
    // The x position from right edge, adjusted for scroll
    final xFromRight = chartWidth - clampedX + scrollOffset;
    final candleIndex = (xFromRight / candleStep).floor();
    
    // Convert to array index (candles[0] is oldest, candles[length-1] is newest)
    final actualIndex = candles.length - 1 - candleIndex;
    
    DateTime timestamp;
    if (actualIndex >= 0 && actualIndex < candles.length) {
      timestamp = candles[actualIndex].timestamp;
    } else if (actualIndex < 0) {
      // Future time (right of newest candle)
      final minutesPerCandle = candles.length > 1
          ? candles.last.timestamp.difference(candles[candles.length - 2].timestamp).inMinutes
          : 5;
      timestamp = candles.last.timestamp.add(Duration(minutes: minutesPerCandle * (-actualIndex)));
    } else {
      // Past time (left of oldest candle)
      final minutesPerCandle = candles.length > 1
          ? candles[1].timestamp.difference(candles[0].timestamp).inMinutes
          : 5;
      timestamp = candles.first.timestamp.subtract(
        Duration(minutes: minutesPerCandle * (actualIndex - candles.length + 1))
      );
    }
    
    return ChartPoint(timestamp: timestamp, price: price);
  }
  
  /// Convert a chart point (price + time) to screen position.
  /// 
  /// This is the PRIMARY method for data → screen conversion (rendering).
  Offset chartPointToScreen(ChartPoint point) {
    // Convert price to Y
    final y = priceToY(point.price);
    
    // Convert timestamp to X
    final x = timestampToX(point.timestamp);
    
    return Offset(x, y);
  }
  
  /// Convert price to Y screen coordinate
  double priceToY(double price) {
    return chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
  }
  
  /// Convert Y screen coordinate to price
  double yToPrice(double y) {
    return maxPrice - (y / chartHeight) * (maxPrice - minPrice);
  }
  
  /// Convert timestamp to X screen coordinate
  double timestampToX(DateTime timestamp) {
    // Find the candleIndex for this timestamp
    int candleIndex = 0;
    
    // Binary search would be better for performance, but linear is clearer
    for (int i = candles.length - 1; i >= 0; i--) {
      if (!candles[i].timestamp.isAfter(timestamp)) {
        candleIndex = candles.length - 1 - i;
        break;
      }
    }
    
    // If timestamp is after all candles, extrapolate
    if (timestamp.isAfter(candles.last.timestamp)) {
      final minutesPerCandle = candles.length > 1
          ? candles.last.timestamp.difference(candles[candles.length - 2].timestamp).inMinutes
          : 5;
      final minutesAhead = timestamp.difference(candles.last.timestamp).inMinutes;
      candleIndex = -(minutesAhead / minutesPerCandle).floor();
    }
    
    // Convert candleIndex to X
    // candleIndex 0 is at chartWidth, higher indices move left
    return chartWidth - (candleIndex * candleStep) - scrollOffset;
  }
  
  /// Find the candle at a given X screen coordinate
  Candle? candleAtX(double x) {
    final point = screenToChartPoint(Offset(x, chartHeight / 2));
    if (point == null) return null;
    
    // Find closest candle by timestamp
    for (int i = 0; i < candles.length; i++) {
      if (candles[i].timestamp.isAtSameMomentAs(point.timestamp) ||
          candles[i].timestamp.isAfter(point.timestamp)) {
        return candles[i];
      }
    }
    return candles.isNotEmpty ? candles.last : null;
  }
  
  /// Get the X coordinate for a specific candle index (0 = newest)
  double candleIndexToX(int index) {
    return chartWidth - (index * candleStep) - scrollOffset;
  }
  
  /// Snap a position to the nearest candle center
  Offset snapToCandle(Offset position) {
    final xFromRight = chartWidth - position.dx + scrollOffset;
    final candleIndex = (xFromRight / candleStep).round();
    final snappedX = chartWidth - (candleIndex * candleStep) - scrollOffset + candleWidth / 2;
    return Offset(snappedX, position.dy);
  }
  
  /// Calculate distance between two screen points in chart data units
  double distanceInPriceUnits(Offset a, Offset b) {
    final pointA = screenToChartPoint(a);
    final pointB = screenToChartPoint(b);
    if (pointA == null || pointB == null) return double.infinity;
    return (pointA.price - pointB.price).abs();
  }
  
  /// Hit test tolerance in screen pixels
  static const double hitTestTolerance = 10.0;
  
  /// Convert screen tolerance to price tolerance
  double screenToPriceTolerance(double screenPixels) {
    return (screenPixels / chartHeight) * (maxPrice - minPrice);
  }
  
  /// Convert screen tolerance to time tolerance (in minutes)
  int screenToTimeTolerance(double screenPixels) {
    final candleCount = screenPixels / candleStep;
    if (candles.length < 2) return 5;
    final minutesPerCandle = candles[1].timestamp.difference(candles[0].timestamp).inMinutes.abs();
    return (candleCount * minutesPerCandle).round();
  }
  
  /// Debug: Get current converter state as a string
  String get debugInfo => '''
ChartCoordinateConverter:
  chartWidth: ${chartWidth.toStringAsFixed(1)}
  chartHeight: ${chartHeight.toStringAsFixed(1)}
  scrollOffset: ${scrollOffset.toStringAsFixed(1)}
  candleWidth: ${candleWidth.toStringAsFixed(1)}
  candleStep: ${candleStep.toStringAsFixed(1)}
  priceRange: ${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)}
  candleCount: ${candles.length}
''';
}


import 'dart:math' as math;
import 'dart:ui';
import '../../models/candle.dart';
import '../../models/chart_drawing.dart';

/// Unified coordinate conversion utility for the candlestick chart.
/// 
/// COORDINATE SYSTEM:
/// - Candles are indexed with 0 = newest (rightmost when scroll=0)
/// - Screen X: 0 = left edge, chartWidth = right edge of plot area
/// - Candle position: x = chartWidth - (candleIndex * candleStep) + scrollOffset
/// 
/// When scrollOffset = 0:
///   - candleIndex 0 → x = chartWidth (right edge)
///   - candleIndex increases → x decreases (moves left)
/// 
/// When scrollOffset > 0 (scrolled to see older candles):
///   - All candles shift RIGHT by scrollOffset pixels
///   - Newest candles move off-screen to the right
///   - Older candles become visible on the left
class ChartCoordinateConverter {
  final List<Candle> candles;
  final double scrollOffset;
  final double candleWidth;
  final double candleGap;
  final double chartWidth;      // Excludes price axis
  final double chartHeight;
  final double priceAxisWidth;
  
  // Calculated values
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
  
  // ==========================================================================
  // CORE CONVERSION: Screen ↔ CandleIndex ↔ Data
  // ==========================================================================
  
  /// Convert screen X to candle index (fractional, for precise positioning)
  double screenXToCandleIndex(double screenX) {
    // From: screenX = chartWidth - (candleIndex * candleStep) + scrollOffset
    // Solve for candleIndex:
    // candleIndex = (chartWidth + scrollOffset - screenX) / candleStep
    return (chartWidth + scrollOffset - screenX) / candleStep;
  }
  
  /// Convert candle index to screen X
  double candleIndexToScreenX(double candleIndex) {
    // screenX = chartWidth - (candleIndex * candleStep) + scrollOffset
    return chartWidth - (candleIndex * candleStep) + scrollOffset;
  }
  
  /// Convert screen Y to price
  double screenYToPrice(double screenY) {
    // Y=0 is top (maxPrice), Y=chartHeight is bottom (minPrice)
    return maxPrice - (screenY / chartHeight) * (maxPrice - minPrice);
  }
  
  /// Convert price to screen Y
  double priceToScreenY(double price) {
    return chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
  }
  
  /// Alias for priceToScreenY (used by painter)
  double priceToY(double price) => priceToScreenY(price);
  
  /// Get candle at a given screen X position
  Candle? candleAtX(double screenX) {
    if (candles.isEmpty) return null;
    
    final candleIndex = screenXToCandleIndex(screenX).round();
    final actualArrayIndex = candles.length - 1 - candleIndex;
    
    if (actualArrayIndex >= 0 && actualArrayIndex < candles.length) {
      return candles[actualArrayIndex];
    }
    return null;
  }
  
  // ==========================================================================
  // HIGH-LEVEL CONVERSION: Screen ↔ ChartPoint
  // ==========================================================================
  
  /// Convert screen position to chart point (price + time)
  ChartPoint? screenToChartPoint(Offset screenPosition) {
    final clampedX = screenPosition.dx.clamp(0.0, chartWidth);
    final clampedY = screenPosition.dy.clamp(0.0, chartHeight);
    
    // Convert Y to price
    final price = screenYToPrice(clampedY);
    
    // Convert X to candleIndex, then to timestamp
    final candleIndexFrac = screenXToCandleIndex(clampedX);
    final candleIndex = candleIndexFrac.round();
    
    // candleIndex 0 = newest candle = candles[candles.length - 1]
    final actualArrayIndex = candles.length - 1 - candleIndex;
    
    DateTime timestamp;
    if (actualArrayIndex >= 0 && actualArrayIndex < candles.length) {
      timestamp = candles[actualArrayIndex].timestamp;
    } else if (actualArrayIndex >= candles.length) {
      // Past the oldest candle (left side)
      final extraCandles = actualArrayIndex - candles.length + 1;
      final avgDuration = _getAverageCandleDuration();
      timestamp = candles.first.timestamp.subtract(Duration(minutes: avgDuration * extraCandles));
    } else {
      // Into the future (right side)
      final extraCandles = -actualArrayIndex;
      final avgDuration = _getAverageCandleDuration();
      timestamp = candles.last.timestamp.add(Duration(minutes: avgDuration * extraCandles));
    }
    
    return ChartPoint(timestamp: timestamp, price: price);
  }
  
  /// Convert chart point to screen position
  Offset chartPointToScreen(ChartPoint point) {
    final y = priceToScreenY(point.price);
    
    // Find the candleIndex for this timestamp
    final candleIndex = _timestampToCandleIndex(point.timestamp);
    final x = candleIndexToScreenX(candleIndex);
    
    return Offset(x, y);
  }
  
  /// Get candle index from timestamp
  double _timestampToCandleIndex(DateTime timestamp) {
    if (candles.isEmpty) return 0;
    
    // Find the candle with this timestamp or closest one
    for (int i = candles.length - 1; i >= 0; i--) {
      if (!candles[i].timestamp.isAfter(timestamp)) {
        // candleIndex = candles.length - 1 - i
        return (candles.length - 1 - i).toDouble();
      }
    }
    
    // Timestamp is before all candles
    final avgDuration = _getAverageCandleDuration();
    if (avgDuration > 0) {
      final minutesBefore = candles.first.timestamp.difference(timestamp).inMinutes;
      return candles.length - 1 + (minutesBefore / avgDuration);
    }
    return candles.length.toDouble();
  }
  
  int _getAverageCandleDuration() {
    if (candles.length < 2) return 5;
    return candles[1].timestamp.difference(candles[0].timestamp).inMinutes.abs();
  }
  
  // ==========================================================================
  // VIEWPORT INFO
  // ==========================================================================
  
  /// Get the total scrollable width in pixels
  double get totalScrollableWidth => candles.length * candleStep;
  
  /// Get the maximum scroll offset (allows panning past the data)
  double get maxScrollOffset => math.max(totalScrollableWidth * 0.5, totalScrollableWidth - chartWidth + chartWidth * 0.5);
  
  /// Get the minimum scroll offset (negative to allow panning to "future")
  double get minScrollOffset => -chartWidth * 0.5;
  
  /// Get visible candle index range
  (int startIndex, int endIndex) get visibleCandleRange {
    final startIdx = (scrollOffset / candleStep).floor();
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final endIdx = math.min(startIdx + visibleCount, candles.length);
    return (math.max(0, startIdx), endIdx);
  }
  
  // ==========================================================================
  // HIT TESTING
  // ==========================================================================
  
  /// Hit test tolerance in pixels
  static const double handleHitRadius = 12.0;
  static const double lineHitDistance = 8.0;
  
  /// Check if a screen point is near a drawing anchor
  bool isNearAnchor(Offset screenPoint, ChartPoint anchor) {
    final anchorScreen = chartPointToScreen(anchor);
    return (screenPoint - anchorScreen).distance <= handleHitRadius;
  }
  
  /// Find which anchor of a drawing is hit (returns index, or -1 if none)
  int hitTestAnchors(Offset screenPoint, ChartDrawing drawing) {
    final anchors = drawing.anchorPoints;
    for (int i = 0; i < anchors.length; i++) {
      if (isNearAnchor(screenPoint, anchors[i])) {
        return i;
      }
    }
    return -1;
  }
  
  /// Check if a screen point hits the body of a drawing (not anchors)
  bool hitTestBody(Offset screenPoint, ChartDrawing drawing) {
    switch (drawing.type) {
      case DrawingToolType.horizontalLine:
        final hLine = drawing as HorizontalLineDrawing;
        final lineY = priceToScreenY(hLine.price);
        return (screenPoint.dy - lineY).abs() <= lineHitDistance &&
               screenPoint.dx >= 0 && screenPoint.dx <= chartWidth;
               
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
        final line = drawing as TrendLineDrawing;
        if (line.endPoint == null) return false;
        final p1 = chartPointToScreen(line.startPoint);
        final p2 = chartPointToScreen(line.endPoint!);
        return _distanceToLineSegment(screenPoint, p1, p2) <= lineHitDistance;
        
      case DrawingToolType.rectangle:
        final rect = drawing as RectangleDrawing;
        if (rect.endPoint == null) return false;
        final p1 = chartPointToScreen(rect.startPoint);
        final p2 = chartPointToScreen(rect.endPoint!);
        final bounds = Rect.fromPoints(p1, p2);
        return bounds.contains(screenPoint);
        
      case DrawingToolType.fibonacciRetracement:
        final fib = drawing as FibonacciDrawing;
        if (fib.endPoint == null) return false;
        final p1 = chartPointToScreen(fib.startPoint);
        final p2 = chartPointToScreen(fib.endPoint!);
        final bounds = Rect.fromPoints(p1, p2);
        return bounds.contains(screenPoint);
        
      default:
        return false;
    }
  }
  
  double _distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final l2 = (lineEnd - lineStart).distanceSquared;
    if (l2 == 0) return (point - lineStart).distance;
    
    var t = ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
             (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    
    final projection = Offset(
      lineStart.dx + t * (lineEnd.dx - lineStart.dx),
      lineStart.dy + t * (lineEnd.dy - lineStart.dy),
    );
    return (point - projection).distance;
  }
  
  // ==========================================================================
  // DEBUG
  // ==========================================================================
  
  String debugInfo(Offset? cursorPosition) {
    final cursor = cursorPosition ?? Offset.zero;
    final point = screenToChartPoint(cursor);
    final backToScreen = point != null ? chartPointToScreen(point) : null;
    
    return '''
Cursor: (${cursor.dx.toStringAsFixed(1)}, ${cursor.dy.toStringAsFixed(1)})
Price: ${point?.price.toStringAsFixed(2) ?? 'N/A'}
CandleIdx: ${screenXToCandleIndex(cursor.dx).toStringAsFixed(2)}
BackToScreen: ${backToScreen != null ? '(${backToScreen.dx.toStringAsFixed(1)}, ${backToScreen.dy.toStringAsFixed(1)})' : 'N/A'}
Scroll: ${scrollOffset.toStringAsFixed(0)} [${minScrollOffset.toStringAsFixed(0)} to ${maxScrollOffset.toStringAsFixed(0)}]
ChartW: ${chartWidth.toStringAsFixed(0)}, Step: ${candleStep.toStringAsFixed(1)}
Candles: ${candles.length}, TotalW: ${totalScrollableWidth.toStringAsFixed(0)}
''';
  }
}

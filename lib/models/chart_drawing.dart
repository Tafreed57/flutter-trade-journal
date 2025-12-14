import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Types of drawing tools available
enum DrawingToolType {
  none,
  trendLine,
  horizontalLine,
  verticalLine,
  ray,
  fibonacciRetracement,
  rectangle,
  // Future: ellipse, arrow, text, etc.
}

/// A point on the chart with price and time
class ChartPoint {
  final DateTime timestamp;
  final double price;

  const ChartPoint({
    required this.timestamp,
    required this.price,
  });

  ChartPoint copyWith({DateTime? timestamp, double? price}) {
    return ChartPoint(
      timestamp: timestamp ?? this.timestamp,
      price: price ?? this.price,
    );
  }
}

/// Base class for all chart drawings
abstract class ChartDrawing {
  final String id;
  final DrawingToolType type;
  final Color color;
  final double strokeWidth;
  bool isSelected;
  bool isComplete;

  ChartDrawing({
    String? id,
    required this.type,
    this.color = const Color(0xFF00E5FF),
    this.strokeWidth = 1.5,
    this.isSelected = false,
    this.isComplete = false,
  }) : id = id ?? const Uuid().v4();

  /// Check if a point is near this drawing (for selection)
  bool isNearPoint(ChartPoint point, double tolerance);

  /// Get all anchor points for this drawing
  List<ChartPoint> get anchorPoints;

  /// Create a copy with updated properties
  ChartDrawing copyWith({
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  });
}

/// A trend line between two points
class TrendLineDrawing extends ChartDrawing {
  final ChartPoint startPoint;
  final ChartPoint? endPoint;
  final bool extendLeft;
  final bool extendRight;

  TrendLineDrawing({
    super.id,
    required this.startPoint,
    this.endPoint,
    this.extendLeft = false,
    this.extendRight = false,
    super.color,
    super.strokeWidth,
    super.isSelected,
    super.isComplete,
  }) : super(type: DrawingToolType.trendLine);

  @override
  List<ChartPoint> get anchorPoints => [
        startPoint,
        if (endPoint != null) endPoint!,
      ];

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    if (endPoint == null) return false;
    
    // Calculate distance from point to line segment
    final dx = endPoint!.price - startPoint.price;
    final dy = endPoint!.timestamp.difference(startPoint.timestamp).inMinutes.toDouble();
    
    final t = ((point.price - startPoint.price) * dx + 
               (point.timestamp.difference(startPoint.timestamp).inMinutes) * dy) /
              (dx * dx + dy * dy);
    
    final clampedT = t.clamp(0.0, 1.0);
    
    final nearestPrice = startPoint.price + clampedT * dx;
    final nearestTime = startPoint.timestamp.add(Duration(minutes: (clampedT * dy).round()));
    
    final priceDiff = (point.price - nearestPrice).abs();
    final timeDiff = point.timestamp.difference(nearestTime).inMinutes.abs();
    
    return priceDiff < tolerance && timeDiff < tolerance * 10;
  }

  @override
  TrendLineDrawing copyWith({
    ChartPoint? startPoint,
    ChartPoint? endPoint,
    bool? extendLeft,
    bool? extendRight,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return TrendLineDrawing(
      id: id,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      extendLeft: extendLeft ?? this.extendLeft,
      extendRight: extendRight ?? this.extendRight,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// A horizontal price line
class HorizontalLineDrawing extends ChartDrawing {
  final double price;
  final String? label;

  HorizontalLineDrawing({
    super.id,
    required this.price,
    this.label,
    super.color,
    super.strokeWidth,
    super.isSelected,
    super.isComplete = true,
  }) : super(type: DrawingToolType.horizontalLine);

  @override
  List<ChartPoint> get anchorPoints => [
        ChartPoint(timestamp: DateTime.now(), price: price),
      ];

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    return (point.price - price).abs() < tolerance;
  }

  @override
  HorizontalLineDrawing copyWith({
    double? price,
    String? label,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return HorizontalLineDrawing(
      id: id,
      price: price ?? this.price,
      label: label ?? this.label,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// A vertical time line
class VerticalLineDrawing extends ChartDrawing {
  final DateTime timestamp;
  final String? label;

  VerticalLineDrawing({
    super.id,
    required this.timestamp,
    this.label,
    super.color,
    super.strokeWidth,
    super.isSelected,
    super.isComplete = true,
  }) : super(type: DrawingToolType.verticalLine);

  @override
  List<ChartPoint> get anchorPoints => [
        ChartPoint(timestamp: timestamp, price: 0),
      ];

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    return point.timestamp.difference(timestamp).inMinutes.abs() < tolerance * 10;
  }

  @override
  VerticalLineDrawing copyWith({
    DateTime? timestamp,
    String? label,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return VerticalLineDrawing(
      id: id,
      timestamp: timestamp ?? this.timestamp,
      label: label ?? this.label,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Fibonacci retracement levels
class FibonacciDrawing extends ChartDrawing {
  final ChartPoint startPoint;
  final ChartPoint? endPoint;
  
  /// Standard Fibonacci levels
  static const List<double> defaultLevels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

  FibonacciDrawing({
    super.id,
    required this.startPoint,
    this.endPoint,
    super.color = const Color(0xFFFFD700),
    super.strokeWidth,
    super.isSelected,
    super.isComplete,
  }) : super(type: DrawingToolType.fibonacciRetracement);

  @override
  List<ChartPoint> get anchorPoints => [
        startPoint,
        if (endPoint != null) endPoint!,
      ];

  /// Get price level for a Fibonacci ratio
  double? getPriceForLevel(double level) {
    if (endPoint == null) return null;
    final range = endPoint!.price - startPoint.price;
    return startPoint.price + (range * level);
  }

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    if (endPoint == null) return false;
    
    // Check if near any Fibonacci level
    for (final level in defaultLevels) {
      final levelPrice = getPriceForLevel(level);
      if (levelPrice != null && (point.price - levelPrice).abs() < tolerance) {
        return true;
      }
    }
    return false;
  }

  @override
  FibonacciDrawing copyWith({
    ChartPoint? startPoint,
    ChartPoint? endPoint,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return FibonacciDrawing(
      id: id,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Rectangle/Box drawing
class RectangleDrawing extends ChartDrawing {
  final ChartPoint startPoint;
  final ChartPoint? endPoint;
  final bool filled;
  final double fillOpacity;

  RectangleDrawing({
    super.id,
    required this.startPoint,
    this.endPoint,
    this.filled = true,
    this.fillOpacity = 0.1,
    super.color,
    super.strokeWidth,
    super.isSelected,
    super.isComplete,
  }) : super(type: DrawingToolType.rectangle);

  @override
  List<ChartPoint> get anchorPoints => [
        startPoint,
        if (endPoint != null) endPoint!,
      ];

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    if (endPoint == null) return false;
    
    final minPrice = startPoint.price < endPoint!.price ? startPoint.price : endPoint!.price;
    final maxPrice = startPoint.price > endPoint!.price ? startPoint.price : endPoint!.price;
    
    return point.price >= minPrice - tolerance && 
           point.price <= maxPrice + tolerance;
  }

  @override
  RectangleDrawing copyWith({
    ChartPoint? startPoint,
    ChartPoint? endPoint,
    bool? filled,
    double? fillOpacity,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return RectangleDrawing(
      id: id,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      filled: filled ?? this.filled,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}


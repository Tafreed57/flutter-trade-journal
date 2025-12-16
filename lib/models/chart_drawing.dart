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
  longPosition,   // TradingView-style Long Position tool
  shortPosition,  // TradingView-style Short Position tool
}

/// Status of a position tool
enum PositionToolStatus {
  draft,    // Being created/edited, not yet active
  active,   // Live position, SL/TP can trigger
  closed,   // Position was closed (manually or via SL/TP)
}

/// Handle types for position tool editing
enum PositionToolHandle {
  body,             // Drag to move entire tool
  entryLine,        // Drag to change entry price
  entryLeft,        // Left handle of entry line
  entryRight,       // Right handle of entry line
  stopLossLine,     // Drag to change stop loss
  stopLossLeft,     // Left handle of SL
  stopLossRight,    // Right handle of SL
  takeProfitLine,   // Drag to change take profit
  takeProfitLeft,   // Left handle of TP
  takeProfitRight,  // Right handle of TP
  rightEdge,        // Drag to change tool width
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

/// TradingView-style Position Tool (Long or Short)
/// 
/// Displays:
/// - Entry line with price label
/// - Stop Loss zone (red for long, green for short)
/// - Take Profit zone (green for long, red for short)
/// - Risk/Reward ratio
/// 
/// When active, integrates with PaperTradingEngine for real SL/TP triggers
class PositionToolDrawing extends ChartDrawing {
  /// Entry price and anchor time (left edge of the tool)
  final ChartPoint entryPoint;
  
  /// Right edge time (defines tool width)
  final DateTime endTime;
  
  /// Stop loss price
  final double stopLossPrice;
  
  /// Take profit price
  final double takeProfitPrice;
  
  /// Position quantity (shares/contracts)
  final double quantity;
  
  /// Whether this is a long (buy) or short (sell) position
  final bool isLong;
  
  /// Current status of the position tool
  PositionToolStatus status;
  
  /// Linked position ID (when active, references PaperPosition)
  String? linkedPositionId;
  
  /// Symbol this position is for
  final String symbol;
  
  /// Exit price (only set when closed)
  double? exitPrice;
  
  /// Realized P&L (only set when closed)
  double? realizedPnL;
  
  /// Creation timestamp
  final DateTime createdAt;
  
  /// Last update timestamp
  DateTime updatedAt;

  PositionToolDrawing({
    super.id,
    required this.entryPoint,
    DateTime? endTime,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.isLong,
    required this.symbol,
    this.quantity = 1.0,
    this.status = PositionToolStatus.draft,
    this.linkedPositionId,
    this.exitPrice,
    this.realizedPnL,
    DateTime? createdAt,
    DateTime? updatedAt,
    super.isSelected,
    super.isComplete = true,
  }) : // Default endTime: entry + reasonable default width
       // Use 24 hours as default - visible across most timeframes and zoom levels
       // (about 24 1h candles, 4.8 4h candles, etc.)
       endTime = endTime ?? entryPoint.timestamp.add(const Duration(hours: 24)),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       super(
         type: isLong ? DrawingToolType.longPosition : DrawingToolType.shortPosition,
         color: isLong ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
       );
  
  /// Get start time (left edge)
  DateTime get startTime => entryPoint.timestamp;

  /// Entry price
  double get entryPrice => entryPoint.price;
  
  /// Risk amount per share
  double get riskPerShare => (entryPrice - stopLossPrice).abs();
  
  /// Reward amount per share
  double get rewardPerShare => (takeProfitPrice - entryPrice).abs();
  
  /// Risk/Reward ratio (e.g., 2.0 means reward is 2x the risk)
  double get riskRewardRatio {
    if (riskPerShare == 0) return 0;
    return rewardPerShare / riskPerShare;
  }
  
  /// Total risk amount
  double get totalRisk => riskPerShare * quantity;
  
  /// Total potential reward
  double get totalReward => rewardPerShare * quantity;
  
  /// Calculate unrealized P&L at a given price
  double unrealizedPnL(double currentPrice) {
    final priceDiff = currentPrice - entryPrice;
    return priceDiff * quantity * (isLong ? 1 : -1);
  }
  
  /// Check if stop loss should trigger
  bool shouldTriggerStopLoss(double currentPrice) {
    if (status != PositionToolStatus.active) return false;
    
    if (isLong) {
      return currentPrice <= stopLossPrice;
    } else {
      return currentPrice >= stopLossPrice;
    }
  }
  
  /// Check if take profit should trigger
  bool shouldTriggerTakeProfit(double currentPrice) {
    if (status != PositionToolStatus.active) return false;
    
    if (isLong) {
      return currentPrice >= takeProfitPrice;
    } else {
      return currentPrice <= takeProfitPrice;
    }
  }
  
  /// Validate that the prices make sense
  bool get isValid {
    if (isLong) {
      // Long: SL < Entry < TP
      return stopLossPrice < entryPrice && entryPrice < takeProfitPrice;
    } else {
      // Short: TP < Entry < SL
      return takeProfitPrice < entryPrice && entryPrice < stopLossPrice;
    }
  }
  
  /// Get the profit zone top price
  double get profitZoneTop => isLong ? takeProfitPrice : entryPrice;
  
  /// Get the profit zone bottom price
  double get profitZoneBottom => isLong ? entryPrice : takeProfitPrice;
  
  /// Get the loss zone top price
  double get lossZoneTop => isLong ? entryPrice : stopLossPrice;
  
  /// Get the loss zone bottom price
  double get lossZoneBottom => isLong ? stopLossPrice : entryPrice;

  @override
  List<ChartPoint> get anchorPoints => [
    // Left side anchors
    entryPoint, // Entry at left edge
    ChartPoint(timestamp: startTime, price: stopLossPrice),   // SL at left
    ChartPoint(timestamp: startTime, price: takeProfitPrice), // TP at left
    // Right side anchors (for resizing)
    ChartPoint(timestamp: endTime, price: entryPrice),        // Entry at right
    ChartPoint(timestamp: endTime, price: stopLossPrice),     // SL at right
    ChartPoint(timestamp: endTime, price: takeProfitPrice),   // TP at right
  ];
  
  /// Width of the tool in time
  Duration get duration => endTime.difference(startTime);

  @override
  bool isNearPoint(ChartPoint point, double tolerance) {
    // Check time range first
    final inTimeRange = !point.timestamp.isBefore(startTime) && 
                        !point.timestamp.isAfter(endTime);
    
    if (!inTimeRange) return false;
    
    // Check if near entry, SL, or TP lines within the time range
    final nearEntry = (point.price - entryPrice).abs() < tolerance;
    final nearSL = (point.price - stopLossPrice).abs() < tolerance;
    final nearTP = (point.price - takeProfitPrice).abs() < tolerance;
    
    // Also check if within the tool's price range
    final minPrice = [entryPrice, stopLossPrice, takeProfitPrice].reduce((a, b) => a < b ? a : b);
    final maxPrice = [entryPrice, stopLossPrice, takeProfitPrice].reduce((a, b) => a > b ? a : b);
    final inPriceRange = point.price >= minPrice - tolerance && point.price <= maxPrice + tolerance;
    
    return nearEntry || nearSL || nearTP || inPriceRange;
  }
  
  /// Handle type for position tool editing
  PositionToolHandle? getHandleAt(ChartPoint point, double priceTolerance, double timeTolerance) {
    final timeFromStart = point.timestamp.difference(startTime).inMinutes.abs();
    final timeFromEnd = point.timestamp.difference(endTime).inMinutes.abs();
    final nearStart = timeFromStart < timeTolerance;
    final nearEnd = timeFromEnd < timeTolerance;
    
    // Check for price handles (SL/TP lines)
    if ((point.price - stopLossPrice).abs() < priceTolerance) {
      if (nearStart) return PositionToolHandle.stopLossLeft;
      if (nearEnd) return PositionToolHandle.stopLossRight;
      return PositionToolHandle.stopLossLine;
    }
    
    if ((point.price - takeProfitPrice).abs() < priceTolerance) {
      if (nearStart) return PositionToolHandle.takeProfitLeft;
      if (nearEnd) return PositionToolHandle.takeProfitRight;
      return PositionToolHandle.takeProfitLine;
    }
    
    if ((point.price - entryPrice).abs() < priceTolerance) {
      if (nearStart) return PositionToolHandle.entryLeft;
      if (nearEnd) return PositionToolHandle.entryRight;
      return PositionToolHandle.entryLine;
    }
    
    // Check if inside the box (for moving)
    final minPrice = [entryPrice, stopLossPrice, takeProfitPrice].reduce((a, b) => a < b ? a : b);
    final maxPrice = [entryPrice, stopLossPrice, takeProfitPrice].reduce((a, b) => a > b ? a : b);
    if (point.price >= minPrice && point.price <= maxPrice) {
      if (nearEnd) return PositionToolHandle.rightEdge;
      return PositionToolHandle.body;
    }
    
    return null;
  }

  @override
  PositionToolDrawing copyWith({
    ChartPoint? entryPoint,
    DateTime? endTime,
    double? stopLossPrice,
    double? takeProfitPrice,
    double? quantity,
    bool? isLong,
    String? symbol,
    PositionToolStatus? status,
    String? linkedPositionId,
    double? exitPrice,
    double? realizedPnL,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    bool? isComplete,
  }) {
    return PositionToolDrawing(
      id: id,
      entryPoint: entryPoint ?? this.entryPoint,
      endTime: endTime ?? this.endTime,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      quantity: quantity ?? this.quantity,
      isLong: isLong ?? this.isLong,
      symbol: symbol ?? this.symbol,
      status: status ?? this.status,
      linkedPositionId: linkedPositionId ?? this.linkedPositionId,
      exitPrice: exitPrice ?? this.exitPrice,
      realizedPnL: realizedPnL ?? this.realizedPnL,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSelected: isSelected ?? this.isSelected,
      isComplete: isComplete ?? this.isComplete,
    );
  }
  
  /// Create a Long position tool with default SL/TP based on percentages
  static PositionToolDrawing createLong({
    required String symbol,
    required ChartPoint entryPoint,
    double slPercent = 2.0,  // 2% below entry
    double tpPercent = 4.0,  // 4% above entry (2:1 R:R)
    double quantity = 1.0,
  }) {
    final entry = entryPoint.price;
    return PositionToolDrawing(
      entryPoint: entryPoint,
      stopLossPrice: entry * (1 - slPercent / 100),
      takeProfitPrice: entry * (1 + tpPercent / 100),
      isLong: true,
      symbol: symbol,
      quantity: quantity,
    );
  }
  
  /// Create a Short position tool with default SL/TP based on percentages
  static PositionToolDrawing createShort({
    required String symbol,
    required ChartPoint entryPoint,
    double slPercent = 2.0,  // 2% above entry
    double tpPercent = 4.0,  // 4% below entry (2:1 R:R)
    double quantity = 1.0,
  }) {
    final entry = entryPoint.price;
    return PositionToolDrawing(
      entryPoint: entryPoint,
      stopLossPrice: entry * (1 + slPercent / 100),
      takeProfitPrice: entry * (1 - tpPercent / 100),
      isLong: false,
      symbol: symbol,
      quantity: quantity,
    );
  }
}


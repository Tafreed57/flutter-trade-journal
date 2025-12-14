import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/candle.dart';
import '../../models/chart_drawing.dart';
import '../../models/chart_marker.dart';
import '../../theme/app_theme.dart';

/// Chart indicator configuration
class ChartIndicator {
  final String name;
  final int period;
  final Color color;
  final bool enabled;

  const ChartIndicator({
    required this.name,
    required this.period,
    required this.color,
    this.enabled = true,
  });

  ChartIndicator copyWith({bool? enabled}) {
    return ChartIndicator(
      name: name,
      period: period,
      color: color,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Professional TradingView-like candlestick chart
/// 
/// Features:
/// - Pinch to zoom / Mouse wheel zoom
/// - Drag to pan (scroll through history)
/// - Crosshair with OHLC tooltip on long press / hover
/// - Auto-scaling Y-axis
/// - Time axis with smart labels
/// - Volume bars
/// - Current price line
/// - Trade markers and position lines
/// - EMA/SMA indicators
class CandlestickChart extends StatefulWidget {
  final List<Candle> candles;
  final double? currentPrice;
  final bool showVolume;
  final VoidCallback? onLoadMore;
  final List<ChartMarker> markers;
  final List<ChartLine> positionLines;
  final List<ChartIndicator> indicators;
  final bool showGrid;
  
  // Drawing tools support
  final List<ChartDrawing> drawings;
  final ChartDrawing? activeDrawing;
  final DrawingToolType currentTool;
  final void Function(ChartPoint)? onDrawingStart;
  final void Function(ChartPoint)? onDrawingUpdate;
  final void Function(ChartPoint?)? onDrawingComplete;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.currentPrice,
    this.showVolume = true,
    this.onLoadMore,
    this.markers = const [],
    this.positionLines = const [],
    this.indicators = const [],
    this.showGrid = true,
    this.drawings = const [],
    this.activeDrawing,
    this.currentTool = DrawingToolType.none,
    this.onDrawingStart,
    this.onDrawingUpdate,
    this.onDrawingComplete,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> 
    with SingleTickerProviderStateMixin {
  // Chart view state
  double _scrollOffset = 0;
  double _candleWidth = 10;
  static const double _minCandleWidth = 2;
  static const double _maxCandleWidth = 40;
  static const double _candleGap = 0.2; // Gap as fraction of candle width
  static const double _priceAxisWidth = 60.0;
  
  // Crosshair state
  bool _showCrosshair = false;
  Offset _crosshairPosition = Offset.zero;
  Candle? _selectedCandle;
  
  // Gesture tracking
  double? _panStartOffset;
  double? _scaleStartWidth;
  Offset? _scaleStartFocalPoint;
  
  // Drawing state
  bool _isDrawing = false;
  
  // Animation
  late AnimationController _animController;
  
  // Cache chart dimensions for conversions
  double _chartWidth = 0;
  double _chartHeight = 0;
  double _minPrice = 0;
  double _maxPrice = 0;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const Center(
        child: Text(
          'No chart data',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final isDrawingMode = widget.currentTool != DrawingToolType.none;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight * (widget.showVolume ? 0.78 : 0.92);
        final volumeHeight = constraints.maxHeight * 0.15;
        final timeAxisHeight = constraints.maxHeight * 0.07;
        
        // Cache dimensions for coordinate conversions
        _chartWidth = constraints.maxWidth - _priceAxisWidth;
        _chartHeight = chartHeight;
        _calculatePriceRange();
        
        return Listener(
          // Mouse wheel zoom for desktop
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && !isDrawingMode) {
              _handleMouseScroll(event, constraints.maxWidth);
            }
          },
          child: GestureDetector(
            // Use a single gesture recognizer approach to avoid conflicts
            behavior: HitTestBehavior.opaque,
            // Drawing mode uses pan gestures
            onPanStart: isDrawingMode 
                ? (d) => _onDrawingStart(d.localPosition)
                : (d) => _onScaleStart(ScaleStartDetails(
                    focalPoint: d.globalPosition,
                    localFocalPoint: d.localPosition,
                  )),
            onPanUpdate: isDrawingMode
                ? (d) => _onDrawingUpdate(d.localPosition)
                : (d) => _onScaleUpdate(
                    ScaleUpdateDetails(
                      focalPoint: d.globalPosition,
                      localFocalPoint: d.localPosition,
                      scale: 1.0,
                    ),
                    constraints.maxWidth,
                  ),
            onPanEnd: isDrawingMode
                ? (_) => _onDrawingEnd()
                : (_) => _onScaleEnd(ScaleEndDetails()),
            // Long press for crosshair in normal mode
            onLongPressStart: isDrawingMode ? null : (d) => _onCrosshairStart(d.localPosition, constraints),
            onLongPressMoveUpdate: isDrawingMode ? null : (d) => _onCrosshairMove(d.localPosition, constraints),
            onLongPressEnd: isDrawingMode ? null : (_) => _onCrosshairEnd(),
            // Single tap for horizontal/vertical line tools
            onTap: isDrawingMode ? () {} : null,
            onTapDown: isDrawingMode
                ? (d) => _onDrawingTap(d.localPosition)
                : null,
            child: MouseRegion(
              cursor: isDrawingMode ? SystemMouseCursors.precise : SystemMouseCursors.grab,
              child: Container(
                color: Colors.transparent, // Needed for gesture detection
                child: Column(
                  children: [
                    // Main chart
                    SizedBox(
                      height: chartHeight,
                      child: Stack(
                        children: [
                          // Chart canvas
                          ClipRect(
                            child: CustomPaint(
                              size: Size(constraints.maxWidth, chartHeight),
                              painter: _CandlestickPainter(
                                candles: widget.candles,
                                scrollOffset: _scrollOffset,
                                candleWidth: _candleWidth,
                                candleGap: _candleGap,
                                currentPrice: widget.currentPrice,
                                showCrosshair: _showCrosshair || isDrawingMode,
                                crosshairPosition: _crosshairPosition,
                                markers: widget.markers,
                                positionLines: widget.positionLines,
                                indicators: widget.indicators,
                                showGrid: widget.showGrid,
                                drawings: widget.drawings,
                                activeDrawing: widget.activeDrawing,
                              ),
                            ),
                          ),
                          
                          // Crosshair tooltip
                          if (_showCrosshair && _selectedCandle != null && !isDrawingMode)
                            _buildCrosshairTooltip(_selectedCandle!, constraints),
                            
                          // Drawing mode indicator
                          if (isDrawingMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_rounded, size: 14, color: Colors.black),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getToolName(widget.currentTool),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Volume bars
                    if (widget.showVolume)
                      SizedBox(
                        height: volumeHeight,
                        child: ClipRect(
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, volumeHeight),
                            painter: _VolumePainter(
                              candles: widget.candles,
                              scrollOffset: _scrollOffset,
                              candleWidth: _candleWidth,
                              candleGap: _candleGap,
                            ),
                          ),
                        ),
                      ),
                    
                    // Time axis
                    SizedBox(
                      height: timeAxisHeight,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, timeAxisHeight),
                        painter: _TimeAxisPainter(
                          candles: widget.candles,
                          scrollOffset: _scrollOffset,
                          candleWidth: _candleWidth,
                          candleGap: _candleGap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _getToolName(DrawingToolType tool) {
    return switch (tool) {
      DrawingToolType.none => '',
      DrawingToolType.trendLine => 'Trend Line',
      DrawingToolType.horizontalLine => 'Horizontal Line',
      DrawingToolType.verticalLine => 'Vertical Line',
      DrawingToolType.ray => 'Ray',
      DrawingToolType.fibonacciRetracement => 'Fibonacci',
      DrawingToolType.rectangle => 'Rectangle',
    };
  }
  
  /// Calculate price range for visible candles
  void _calculatePriceRange() {
    if (widget.candles.isEmpty) return;
    
    final candleStep = _candleWidth * (1 + _candleGap);
    final visibleCount = (_chartWidth / candleStep).ceil() + 2;
    final startIndex = (_scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, widget.candles.length);
    
    _minPrice = double.infinity;
    _maxPrice = double.negativeInfinity;
    
    for (int i = math.max(0, widget.candles.length - endIndex - 1);
         i < math.min(widget.candles.length, widget.candles.length - startIndex + 1); i++) {
      final candle = widget.candles[i];
      _minPrice = math.min(_minPrice, candle.low);
      _maxPrice = math.max(_maxPrice, candle.high);
    }
    
    final priceRange = _maxPrice - _minPrice;
    final padding = priceRange * 0.08;
    _minPrice -= padding;
    _maxPrice += padding;
  }
  
  /// Convert screen position to chart point (price + time)
  ChartPoint _screenToChartPoint(Offset position) {
    // Price from Y position
    final price = _maxPrice - (position.dy / _chartHeight) * (_maxPrice - _minPrice);
    
    // Time from X position
    final candleStep = _candleWidth * (1 + _candleGap);
    final xInChart = position.dx + _scrollOffset;
    final candleIndex = (xInChart / candleStep).floor();
    final actualIndex = widget.candles.length - 1 - candleIndex;
    
    DateTime timestamp;
    if (actualIndex >= 0 && actualIndex < widget.candles.length) {
      timestamp = widget.candles[actualIndex].timestamp;
    } else {
      timestamp = DateTime.now();
    }
    
    return ChartPoint(timestamp: timestamp, price: price);
  }
  
  // ==================== DRAWING HANDLERS ====================
  
  void _onDrawingTap(Offset position) {
    // For single-click tools like horizontal/vertical lines
    if (widget.currentTool == DrawingToolType.horizontalLine ||
        widget.currentTool == DrawingToolType.verticalLine) {
      final point = _screenToChartPoint(position);
      widget.onDrawingStart?.call(point);
    }
  }
  
  void _onDrawingStart(Offset position) {
    _isDrawing = true;
    final point = _screenToChartPoint(position);
    widget.onDrawingStart?.call(point);
    setState(() {
      _crosshairPosition = position;
    });
  }
  
  void _onDrawingUpdate(Offset position) {
    if (!_isDrawing) return;
    final point = _screenToChartPoint(position);
    widget.onDrawingUpdate?.call(point);
    setState(() {
      _crosshairPosition = position;
    });
  }
  
  void _onDrawingEnd() {
    if (!_isDrawing) return;
    _isDrawing = false;
    final point = _screenToChartPoint(_crosshairPosition);
    widget.onDrawingComplete?.call(point);
  }

  Widget _buildCrosshairTooltip(Candle candle, BoxConstraints constraints) {
    final isUp = candle.close >= candle.open;
    final change = candle.close - candle.open;
    final changePercent = (change / candle.open) * 100;
    
    // Position tooltip to avoid edges
    double left = _crosshairPosition.dx + 12;
    if (left + 140 > constraints.maxWidth) {
      left = _crosshairPosition.dx - 152;
    }
    
    double top = 8;
    
    return Positioned(
      left: left.clamp(8, constraints.maxWidth - 148),
      top: top,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date/Time
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(candle.timestamp),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            
            // OHLC values
            _TooltipRow('O', candle.open.toStringAsFixed(2)),
            _TooltipRow('H', candle.high.toStringAsFixed(2), AppColors.profit),
            _TooltipRow('L', candle.low.toStringAsFixed(2), AppColors.loss),
            _TooltipRow('C', candle.close.toStringAsFixed(2)),
            
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 4),
            
            // Change
            Row(
              children: [
                Icon(
                  isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: isUp ? AppColors.profit : AppColors.loss,
                  size: 16,
                ),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isUp ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ],
            ),
            
            // Volume
            if (candle.volume > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Vol: ${_formatVolume(candle.volume)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1e9) return '${(volume / 1e9).toStringAsFixed(1)}B';
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(1)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(1)}K';
    return volume.toStringAsFixed(0);
  }

  // ==================== GESTURE HANDLERS ====================

  void _handleMouseScroll(PointerScrollEvent event, double chartWidth) {
    setState(() {
      // Zoom in/out based on scroll direction
      final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      final newWidth = (_candleWidth * zoomFactor).clamp(_minCandleWidth, _maxCandleWidth);
      
      // Adjust scroll to keep chart centered at mouse position
      const priceAxisWidth = 60.0;
      final chartAreaWidth = chartWidth - priceAxisWidth;
      final oldTotalWidth = widget.candles.length * (_candleWidth * (1 + _candleGap));
      final newTotalWidth = widget.candles.length * (newWidth * (1 + _candleGap));
      
      _candleWidth = newWidth;
      _scrollOffset = (_scrollOffset * (newTotalWidth / oldTotalWidth))
          .clamp(0, math.max(0, newTotalWidth - chartAreaWidth));
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _panStartOffset = _scrollOffset;
    _scaleStartWidth = _candleWidth;
    _scaleStartFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double chartWidth) {
    setState(() {
      final priceAxisWidth = 60.0;
      final chartAreaWidth = chartWidth - priceAxisWidth;
      
      // Handle zoom
      if (details.scale != 1.0 && _scaleStartWidth != null) {
        final newWidth = (_scaleStartWidth! * details.scale)
            .clamp(_minCandleWidth, _maxCandleWidth);
        _candleWidth = newWidth;
      }
      
      // Handle pan
      if (_panStartOffset != null && _scaleStartFocalPoint != null) {
        final dx = _scaleStartFocalPoint!.dx - details.localFocalPoint.dx;
        final totalWidth = widget.candles.length * (_candleWidth * (1 + _candleGap));
        _scrollOffset = (_panStartOffset! + dx)
            .clamp(0, math.max(0, totalWidth - chartAreaWidth + priceAxisWidth));
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _panStartOffset = null;
    _scaleStartWidth = null;
    _scaleStartFocalPoint = null;
  }

  void _onCrosshairStart(Offset position, BoxConstraints constraints) {
    _updateCrosshair(position, constraints);
  }

  void _onCrosshairMove(Offset position, BoxConstraints constraints) {
    _updateCrosshair(position, constraints);
  }

  void _updateCrosshair(Offset position, BoxConstraints constraints) {
    final candleStep = _candleWidth * (1 + _candleGap);
    
    // Find candle at position
    final xInChart = position.dx + _scrollOffset;
    final candleIndex = (xInChart / candleStep).floor();
    final actualIndex = widget.candles.length - 1 - candleIndex;
    
    if (actualIndex >= 0 && actualIndex < widget.candles.length) {
      setState(() {
        _showCrosshair = true;
        _crosshairPosition = position;
        _selectedCandle = widget.candles[actualIndex];
      });
    }
  }

  void _onCrosshairEnd() {
    setState(() {
      _showCrosshair = false;
      _selectedCandle = null;
    });
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _TooltipRow(this.label, this.value, [this.color]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main candlestick chart painter
class _CandlestickPainter extends CustomPainter {
  final List<Candle> candles;
  final double scrollOffset;
  final double candleWidth;
  final double candleGap;
  final double? currentPrice;
  final bool showCrosshair;
  final Offset crosshairPosition;
  final List<ChartMarker> markers;
  final List<ChartLine> positionLines;
  final List<ChartIndicator> indicators;
  final bool showGrid;
  final List<ChartDrawing> drawings;
  final ChartDrawing? activeDrawing;

  static const double priceAxisWidth = 60.0;

  _CandlestickPainter({
    required this.candles,
    required this.scrollOffset,
    required this.candleWidth,
    required this.candleGap,
    this.currentPrice,
    required this.showCrosshair,
    required this.crosshairPosition,
    this.markers = const [],
    this.positionLines = const [],
    this.indicators = const [],
    this.showGrid = true,
    this.drawings = const [],
    this.activeDrawing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final chartWidth = size.width - priceAxisWidth;
    final chartHeight = size.height;
    final candleStep = candleWidth * (1 + candleGap);
    
    // Calculate visible range
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);
    
    // Get price range for visible candles
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    
    for (int i = math.max(0, candles.length - endIndex - 1).toInt(); 
         i < math.min(candles.length, candles.length - startIndex + 1).toInt(); i++) {
      final candle = candles[i];
      minPrice = math.min(minPrice, candle.low);
      maxPrice = math.max(maxPrice, candle.high);
    }
    
    // Add padding
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.08;
    minPrice -= padding;
    maxPrice += padding;
    
    // Draw grid
    _drawGrid(canvas, size, chartWidth, chartHeight, minPrice, maxPrice);
    
    // Draw position lines (SL/TP)
    for (final line in positionLines) {
      _drawPriceLine(canvas, chartWidth, chartHeight, minPrice, maxPrice, line.price, line.color, line.label, line.isDashed);
    }
    
    // Draw candles
    for (int i = startIndex; i < endIndex; i++) {
      if (i < 0 || i >= candles.length) continue;
      
      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset - candleWidth / 2;
      
      if (x < -candleWidth * 2 || x > chartWidth + candleWidth * 2) continue;
      
      _drawCandle(canvas, candle, x, chartHeight, minPrice, maxPrice);
    }
    
    // Draw indicators (EMA lines)
    for (final indicator in indicators) {
      if (indicator.enabled) {
        _drawIndicator(canvas, chartWidth, chartHeight, minPrice, maxPrice, 
            candleStep, startIndex, endIndex, indicator);
      }
    }
    
    // Draw current price line
    if (currentPrice != null) {
      _drawCurrentPriceLine(canvas, chartWidth, chartHeight, minPrice, maxPrice);
    }
    
    // Draw markers
    _drawMarkers(canvas, chartWidth, chartHeight, minPrice, maxPrice, startIndex, endIndex);
    
    // Draw all drawings
    for (final drawing in drawings) {
      _drawDrawing(canvas, chartWidth, chartHeight, minPrice, maxPrice, drawing);
    }
    
    // Draw active (in-progress) drawing
    if (activeDrawing != null) {
      _drawDrawing(canvas, chartWidth, chartHeight, minPrice, maxPrice, activeDrawing!);
    }
    
    // Draw price axis
    _drawPriceAxis(canvas, size, chartHeight, minPrice, maxPrice);
    
    // Draw crosshair
    if (showCrosshair) {
      _drawCrosshair(canvas, chartWidth, chartHeight, minPrice, maxPrice);
    }
  }
  
  /// Draw a chart drawing (line, fib, rectangle, etc.)
  void _drawDrawing(Canvas canvas, double chartWidth, double chartHeight,
      double minPrice, double maxPrice, ChartDrawing drawing) {
    final candleStep = candleWidth * (1 + candleGap);
    
    double priceToY(double price) {
      return chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
    }
    
    double timeToX(DateTime time) {
      // Find the closest candle index
      int candleIndex = 0;
      for (int i = 0; i < candles.length; i++) {
        if (!candles[i].timestamp.isAfter(time)) {
          candleIndex = candles.length - 1 - i;
        }
      }
      return chartWidth - (candleIndex * candleStep) + scrollOffset;
    }
    
    switch (drawing.type) {
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
        final line = drawing as TrendLineDrawing;
        if (line.endPoint == null) return;
        
        final x1 = timeToX(line.startPoint.timestamp);
        final y1 = priceToY(line.startPoint.price);
        final x2 = timeToX(line.endPoint!.timestamp);
        final y2 = priceToY(line.endPoint!.price);
        
        final paint = Paint()
          ..color = line.color
          ..strokeWidth = line.strokeWidth
          ..strokeCap = StrokeCap.round;
        
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        
        // Draw anchor points if selected
        if (line.isSelected) {
          final anchorPaint = Paint()
            ..color = line.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x1, y1), 4, anchorPaint);
          canvas.drawCircle(Offset(x2, y2), 4, anchorPaint);
        }
        break;
        
      case DrawingToolType.horizontalLine:
        final hLine = drawing as HorizontalLineDrawing;
        final y = priceToY(hLine.price);
        
        if (y < 0 || y > chartHeight) return;
        
        final paint = Paint()
          ..color = hLine.color
          ..strokeWidth = hLine.strokeWidth;
        
        // Dashed line
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        double startX = 0;
        
        while (startX < chartWidth) {
          canvas.drawLine(
            Offset(startX, y),
            Offset(math.min(startX + dashWidth, chartWidth), y),
            paint,
          );
          startX += dashWidth + dashSpace;
        }
        
        // Price label
        final labelBg = Paint()..color = hLine.color;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(chartWidth, y - 10, priceAxisWidth, 20),
            const Radius.circular(3),
          ),
          labelBg,
        );
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: hLine.price.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(chartWidth + (priceAxisWidth - textPainter.width) / 2, y - 5),
        );
        break;
        
      case DrawingToolType.fibonacciRetracement:
        final fib = drawing as FibonacciDrawing;
        if (fib.endPoint == null) return;
        
        final x1 = timeToX(fib.startPoint.timestamp);
        final x2 = timeToX(fib.endPoint!.timestamp);
        final minX = math.min(x1, x2);
        final maxX = math.max(x1, x2);
        
        final paint = Paint()
          ..color = fib.color
          ..strokeWidth = 0.8;
        
        // Draw each Fibonacci level
        for (final level in FibonacciDrawing.defaultLevels) {
          final price = fib.getPriceForLevel(level);
          if (price == null) continue;
          
          final y = priceToY(price);
          if (y < 0 || y > chartHeight) continue;
          
          // Draw level line
          canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);
          
          // Draw level label
          final labelText = '${(level * 100).toStringAsFixed(1)}% (${price.toStringAsFixed(2)})';
          final textPainter = TextPainter(
            text: TextSpan(
              text: labelText,
              style: TextStyle(
                color: fib.color,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          
          textPainter.paint(canvas, Offset(minX + 4, y - 12));
        }
        
        // Draw boundary box
        final y1 = priceToY(fib.startPoint.price);
        final y2 = priceToY(fib.endPoint!.price);
        
        final boxPaint = Paint()
          ..color = fib.color.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTRB(minX, math.min(y1, y2), maxX, math.max(y1, y2)),
          boxPaint,
        );
        break;
        
      case DrawingToolType.rectangle:
        final rect = drawing as RectangleDrawing;
        if (rect.endPoint == null) return;
        
        final x1 = timeToX(rect.startPoint.timestamp);
        final y1 = priceToY(rect.startPoint.price);
        final x2 = timeToX(rect.endPoint!.timestamp);
        final y2 = priceToY(rect.endPoint!.price);
        
        final rectBounds = Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
        
        // Fill
        if (rect.filled) {
          final fillPaint = Paint()
            ..color = rect.color.withValues(alpha: rect.fillOpacity)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rectBounds, fillPaint);
        }
        
        // Border
        final borderPaint = Paint()
          ..color = rect.color
          ..strokeWidth = rect.strokeWidth
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rectBounds, borderPaint);
        
        // Draw anchor points if selected
        if (rect.isSelected) {
          final anchorPaint = Paint()
            ..color = rect.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x1, y1), 4, anchorPaint);
          canvas.drawCircle(Offset(x2, y2), 4, anchorPaint);
          canvas.drawCircle(Offset(x1, y2), 4, anchorPaint);
          canvas.drawCircle(Offset(x2, y1), 4, anchorPaint);
        }
        break;
        
      case DrawingToolType.verticalLine:
        // TODO: Implement vertical line drawing
        break;
        
      case DrawingToolType.none:
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size, double chartWidth, double chartHeight,
      double minPrice, double maxPrice) {
    if (!showGrid) return;
    
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    
    // Horizontal grid lines (price levels)
    final priceStep = _calculatePriceStep(maxPrice - minPrice);
    var price = (minPrice / priceStep).ceil() * priceStep;
    
    while (price < maxPrice) {
      final y = chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      price += priceStep;
    }
  }

  double _calculatePriceStep(double range) {
    final magnitude = (range / 5).abs();
    if (magnitude >= 100) return 50;
    if (magnitude >= 50) return 25;
    if (magnitude >= 10) return 10;
    if (magnitude >= 5) return 5;
    if (magnitude >= 1) return 1;
    if (magnitude >= 0.5) return 0.5;
    if (magnitude >= 0.1) return 0.1;
    return 0.01;
  }

  /// Calculate EMA values for the given period
  List<double?> _calculateEMA(int period) {
    if (candles.length < period) return List.filled(candles.length, null);
    
    final emaValues = List<double?>.filled(candles.length, null);
    final multiplier = 2 / (period + 1);
    
    // Calculate initial SMA for first EMA value
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    emaValues[period - 1] = sum / period;
    
    // Calculate EMA for remaining values
    for (int i = period; i < candles.length; i++) {
      final prevEma = emaValues[i - 1]!;
      emaValues[i] = (candles[i].close - prevEma) * multiplier + prevEma;
    }
    
    return emaValues;
  }

  /// Draw an indicator line on the chart
  void _drawIndicator(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
    double candleStep,
    int startIndex,
    int endIndex,
    ChartIndicator indicator,
  ) {
    final emaValues = _calculateEMA(indicator.period);
    
    final paint = Paint()
      ..color = indicator.color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    bool started = false;
    
    for (int i = startIndex; i < endIndex; i++) {
      if (i < 0 || i >= candles.length) continue;
      
      final actualIndex = candles.length - 1 - i;
      final emaValue = emaValues[actualIndex];
      
      if (emaValue == null) continue;
      
      final x = chartWidth - (i * candleStep) + scrollOffset;
      final y = chartHeight - ((emaValue - minPrice) / (maxPrice - minPrice)) * chartHeight;
      
      if (x < -20 || x > chartWidth + 20) continue;
      
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawCandle(Canvas canvas, Candle candle, double x, double chartHeight,
      double minPrice, double maxPrice) {
    final isUp = candle.close >= candle.open;
    final color = isUp ? AppColors.profit : AppColors.loss;
    
    final openY = chartHeight - ((candle.open - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final closeY = chartHeight - ((candle.close - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final highY = chartHeight - ((candle.high - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final lowY = chartHeight - ((candle.low - minPrice) / (maxPrice - minPrice)) * chartHeight;
    
    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    
    // Draw wick
    canvas.drawLine(
      Offset(x + candleWidth / 2, highY),
      Offset(x + candleWidth / 2, lowY),
      wickPaint,
    );
    
    // Draw body
    final bodyTop = math.min(openY, closeY);
    final bodyBottom = math.max(openY, closeY);
    final bodyHeight = math.max(1.0, bodyBottom - bodyTop);
    
    final bodyPaint = Paint()
      ..color = color
      ..style = isUp ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1;
    
    canvas.drawRect(
      Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight),
      bodyPaint,
    );
  }

  void _drawCurrentPriceLine(Canvas canvas, double chartWidth, double chartHeight,
      double minPrice, double maxPrice) {
    if (currentPrice == null) return;
    
    final y = chartHeight - ((currentPrice! - minPrice) / (maxPrice - minPrice)) * chartHeight;
    
    if (y < 0 || y > chartHeight) return;
    
    // Dashed line
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1;
    
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    
    while (startX < chartWidth) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, chartWidth), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
    
    // Price label
    final labelBg = Paint()..color = AppColors.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chartWidth, y - 10, priceAxisWidth, 20),
        const Radius.circular(3),
      ),
      labelBg,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: currentPrice!.toStringAsFixed(2),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(chartWidth + (priceAxisWidth - textPainter.width) / 2, y - 5),
    );
  }

  void _drawPriceLine(Canvas canvas, double chartWidth, double chartHeight,
      double minPrice, double maxPrice, double price, Color color, String? label, bool isDashed) {
    final y = chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
    
    if (y < 0 || y > chartHeight) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    
    if (isDashed) {
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      double startX = 0;
      
      while (startX < chartWidth) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(math.min(startX + dashWidth, chartWidth), y),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), paint);
    }
    
    if (label != null) {
      final bgPaint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartWidth - 65, y - 8, 65, 16),
          const Radius.circular(3),
        ),
        bgPaint,
      );
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      
      textPainter.paint(canvas, Offset(chartWidth - 63, y - 5));
    }
  }

  void _drawMarkers(Canvas canvas, double chartWidth, double chartHeight,
      double minPrice, double maxPrice, int startIndex, int endIndex) {
    if (markers.isEmpty || candles.isEmpty) return;
    
    final candleStep = candleWidth * (1 + candleGap);
    
    for (final marker in markers) {
      // Find candle index for marker timestamp
      int? candleIndex;
      for (int i = 0; i < candles.length; i++) {
        if (marker.timestamp.isAfter(candles[i].timestamp) ||
            marker.timestamp.isAtSameMomentAs(candles[i].timestamp)) {
          if (i == candles.length - 1 ||
              marker.timestamp.isBefore(candles[i + 1].timestamp)) {
            candleIndex = candles.length - 1 - i;
            break;
          }
        }
      }
      
      if (candleIndex == null) continue;
      
      final x = chartWidth - (candleIndex * candleStep) + scrollOffset;
      if (x < -20 || x > chartWidth + 20) continue;
      
      final y = chartHeight - ((marker.price - minPrice) / (maxPrice - minPrice)) * chartHeight;
      if (y < -20 || y > chartHeight + 20) continue;
      
      _drawMarker(canvas, x, y, marker);
    }
  }

  void _drawMarker(Canvas canvas, double x, double y, ChartMarker marker) {
    final size = marker.isEntry ? 14.0 : 10.0;
    
    final bgPaint = Paint()
      ..color = marker.color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), size / 2, bgPaint);
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawCircle(Offset(x, y), size / 2, borderPaint);
    
    // Draw arrow for entry markers
    if (marker.isEntry) {
      final arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      
      if (marker.type == MarkerType.buyEntry) {
        canvas.drawLine(Offset(x, y + 2), Offset(x, y - 2), arrowPaint);
        canvas.drawLine(Offset(x - 2, y), Offset(x, y - 2), arrowPaint);
        canvas.drawLine(Offset(x + 2, y), Offset(x, y - 2), arrowPaint);
      } else {
        canvas.drawLine(Offset(x, y - 2), Offset(x, y + 2), arrowPaint);
        canvas.drawLine(Offset(x - 2, y), Offset(x, y + 2), arrowPaint);
        canvas.drawLine(Offset(x + 2, y), Offset(x, y + 2), arrowPaint);
      }
    }
  }

  void _drawPriceAxis(Canvas canvas, Size size, double chartHeight,
      double minPrice, double maxPrice) {
    final chartWidth = size.width - priceAxisWidth;
    
    // Background
    final bgPaint = Paint()..color = AppColors.surface;
    canvas.drawRect(
      Rect.fromLTWH(chartWidth, 0, priceAxisWidth, chartHeight),
      bgPaint,
    );
    
    // Border
    final borderPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartWidth, 0),
      Offset(chartWidth, chartHeight),
      borderPaint,
    );
    
    // Price labels
    final priceStep = _calculatePriceStep(maxPrice - minPrice);
    var price = (minPrice / priceStep).ceil() * priceStep;
    
    while (price < maxPrice) {
      final y = chartHeight - ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: _formatPrice(price),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      
      textPainter.paint(canvas, Offset(chartWidth + 6, y - 5));
      
      price += priceStep;
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }

  void _drawCrosshair(Canvas canvas, double chartWidth, double chartHeight,
      double minPrice, double maxPrice) {
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    
    // Vertical line
    canvas.drawLine(
      Offset(crosshairPosition.dx, 0),
      Offset(crosshairPosition.dx, chartHeight),
      paint,
    );
    
    // Horizontal line
    canvas.drawLine(
      Offset(0, crosshairPosition.dy),
      Offset(chartWidth, crosshairPosition.dy),
      paint,
    );
    
    // Price at crosshair
    final price = maxPrice - (crosshairPosition.dy / chartHeight) * (maxPrice - minPrice);
    
    final bgPaint = Paint()..color = AppColors.surfaceLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chartWidth, crosshairPosition.dy - 10, priceAxisWidth, 20),
        const Radius.circular(3),
      ),
      bgPaint,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: _formatPrice(price),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(chartWidth + 6, crosshairPosition.dy - 5),
    );
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.candleWidth != candleWidth ||
        oldDelegate.currentPrice != currentPrice ||
        oldDelegate.showCrosshair != showCrosshair ||
        oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.markers != markers ||
        oldDelegate.positionLines != positionLines ||
        oldDelegate.indicators != indicators ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.drawings != drawings ||
        oldDelegate.activeDrawing != activeDrawing;
  }
}

/// Volume bars painter
class _VolumePainter extends CustomPainter {
  final List<Candle> candles;
  final double scrollOffset;
  final double candleWidth;
  final double candleGap;

  static const double priceAxisWidth = 60.0;

  _VolumePainter({
    required this.candles,
    required this.scrollOffset,
    required this.candleWidth,
    required this.candleGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final chartWidth = size.width - priceAxisWidth;
    final chartHeight = size.height;
    final candleStep = candleWidth * (1 + candleGap);
    
    // Calculate visible range
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);
    
    // Get max volume for visible candles
    double maxVolume = 0;
    for (int i = math.max(0, candles.length - endIndex - 1).toInt();
         i < math.min(candles.length, candles.length - startIndex + 1).toInt(); i++) {
      maxVolume = math.max(maxVolume, candles[i].volume);
    }
    
    if (maxVolume == 0) return;
    
    // Draw volume bars
    for (int i = startIndex; i < endIndex; i++) {
      if (i < 0 || i >= candles.length) continue;
      
      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset - candleWidth / 2;
      
      if (x < -candleWidth * 2 || x > chartWidth + candleWidth * 2) continue;
      
      final isUp = candle.close >= candle.open;
      final barHeight = (candle.volume / maxVolume) * chartHeight * 0.8;
      
      final paint = Paint()
        ..color = (isUp ? AppColors.profit : AppColors.loss).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(x, chartHeight - barHeight, candleWidth, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VolumePainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.candleWidth != candleWidth;
  }
}

/// Time axis painter
class _TimeAxisPainter extends CustomPainter {
  final List<Candle> candles;
  final double scrollOffset;
  final double candleWidth;
  final double candleGap;

  static const double priceAxisWidth = 60.0;

  _TimeAxisPainter({
    required this.candles,
    required this.scrollOffset,
    required this.candleWidth,
    required this.candleGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final chartWidth = size.width - priceAxisWidth;
    final candleStep = candleWidth * (1 + candleGap);
    
    // Calculate label interval
    final minLabelSpacing = 70.0;
    final labelInterval = (minLabelSpacing / candleStep).ceil();
    
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);
    
    // Draw time labels
    for (int i = startIndex; i < endIndex; i += labelInterval) {
      if (i < 0 || i >= candles.length) continue;
      
      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset;
      
      if (x < 0 || x > chartWidth) continue;
      
      final label = _formatTime(candle.timestamp);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 4));
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year != now.year) {
      return DateFormat('MMM yy').format(time);
    }
    if (time.month != now.month || time.day != now.day) {
      return DateFormat('MMM d').format(time);
    }
    return DateFormat('HH:mm').format(time);
  }

  @override
  bool shouldRepaint(covariant _TimeAxisPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.candleWidth != candleWidth;
  }
}

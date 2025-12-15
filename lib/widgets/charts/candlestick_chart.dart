import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/candle.dart';
import '../../models/chart_drawing.dart';
import '../../models/chart_marker.dart';
import '../../theme/app_theme.dart';
import 'chart_coordinate_converter.dart';

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
/// - EMA/SMA/RSI indicators
/// - Drawing tools with accurate coordinate mapping
class CandlestickChart extends StatefulWidget {
  final List<Candle> candles;
  final double? currentPrice;
  final bool showVolume;
  final VoidCallback? onLoadMore;
  final List<ChartMarker> markers;
  final List<ChartLine> positionLines;
  final List<ChartIndicator> indicators;
  final bool showGrid;
  final bool showDebugOverlay;

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
    this.showDebugOverlay = false,
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
  static const double _candleGap = 0.2;
  static const double _priceAxisWidth = 60.0;

  // Crosshair state
  bool _showCrosshair = false;
  Offset _crosshairPosition = Offset.zero;
  Candle? _selectedCandle;

  // Gesture tracking for pan/zoom
  double? _panStartOffset;
  double? _scaleStartWidth;
  Offset? _scaleStartFocalPoint;
  Offset? _lastPointerPosition;
  bool _isPanning = false; // Track if we're actively panning

  // Drawing state
  bool _isDrawing = false;
  int? _selectedDrawingIndex; // Which drawing is selected
  int? _selectedAnchorIndex; // Which anchor is being dragged (-1 = body)
  ChartPoint? _dragStartDataPoint; // Data point where drag started

  // Animation
  late AnimationController _animController;

  // Coordinate converter (recreated on each build with current dimensions)
  ChartCoordinateConverter? _converter;
  double _chartWidth = 0; // Cache for gesture handlers
  double _chartHeight = 0;

  // Debug info
  String _debugText = '';

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
        final chartHeight =
            constraints.maxHeight * (widget.showVolume ? 0.78 : 0.92);
        final volumeHeight = constraints.maxHeight * 0.15;
        final timeAxisHeight = constraints.maxHeight * 0.07;
        final chartWidth = constraints.maxWidth - _priceAxisWidth;

        // Cache for gesture handlers
        _chartWidth = chartWidth;
        _chartHeight = chartHeight;

        // Create/update coordinate converter
        _converter = ChartCoordinateConverter(
          candles: widget.candles,
          scrollOffset: _scrollOffset,
          candleWidth: _candleWidth,
          candleGap: _candleGap,
          chartWidth: chartWidth,
          chartHeight: chartHeight,
          priceAxisWidth: _priceAxisWidth,
        );

        return Listener(
          // Mouse wheel zoom for desktop
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && !isDrawingMode) {
              _handleMouseScroll(event, constraints.maxWidth);
            }
          },
          onPointerHover: (event) {
            // Track pointer for debug overlay
            if (widget.showDebugOverlay) {
              setState(() {
                _lastPointerPosition = event.localPosition;
                _updateDebugText();
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Pan gestures: for chart panning, drawing creation, or drawing edit
            onPanStart: (details) =>
                _handlePanStart(details.localPosition, isDrawingMode),
            onPanUpdate: (details) => _handlePanUpdate(
              details.localPosition,
              details.delta,
              isDrawingMode,
            ),
            onPanEnd: (details) => _handlePanEnd(isDrawingMode),
            // Long press for crosshair in normal mode
            onLongPressStart: isDrawingMode
                ? null
                : (d) => _onCrosshairStart(d.localPosition),
            onLongPressMoveUpdate: isDrawingMode
                ? null
                : (d) => _onCrosshairMove(d.localPosition),
            onLongPressEnd: isDrawingMode ? null : (_) => _onCrosshairEnd(),
            // Single tap for single-click tools (horizontal/vertical line)
            onTapDown: isDrawingMode
                ? (d) => _onDrawingTap(d.localPosition)
                : null,
            child: MouseRegion(
              cursor: isDrawingMode
                  ? SystemMouseCursors.precise
                  : (_showCrosshair
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.grab),
              onHover: (event) {
                if (widget.showDebugOverlay) {
                  setState(() {
                    _lastPointerPosition = event.localPosition;
                    _updateDebugText();
                  });
                }
              },
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    Column(
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
                                    showCrosshair:
                                        _showCrosshair || isDrawingMode,
                                    crosshairPosition: _crosshairPosition,
                                    markers: widget.markers,
                                    positionLines: widget.positionLines,
                                    indicators: widget.indicators,
                                    showGrid: widget.showGrid,
                                    drawings: widget.drawings,
                                    activeDrawing: widget.activeDrawing,
                                    converter: _converter,
                                  ),
                                ),
                              ),

                              // Crosshair tooltip
                              if (_showCrosshair &&
                                  _selectedCandle != null &&
                                  !isDrawingMode)
                                _buildCrosshairTooltip(
                                  _selectedCandle!,
                                  constraints,
                                ),

                              // Drawing mode indicator
                              if (isDrawingMode)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.edit_rounded,
                                          size: 14,
                                          color: Colors.black,
                                        ),
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

                    // Debug overlay
                    if (widget.showDebugOverlay)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _debugText,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),

                    // Debug: draw anchor point at cursor
                    if (widget.showDebugOverlay && _lastPointerPosition != null)
                      Positioned(
                        left: _lastPointerPosition!.dx - 5,
                        top: _lastPointerPosition!.dy - 5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
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

  void _updateDebugText() {
    if (_converter == null) {
      _debugText = 'No converter';
      return;
    }

    // Use the converter's built-in debug info
    _debugText = _converter!.debugInfo(_lastPointerPosition);

    // Add panning state
    if (_isPanning) {
      _debugText += 'State: PANNING\n';
    } else if (_selectedDrawingIndex != null) {
      _debugText += 'State: EDITING #$_selectedDrawingIndex\n';
    }
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

  // ==================== DRAWING HANDLERS ====================

  void _onDrawingTap(Offset position) {
    if (_converter == null) return;

    // For single-click tools like horizontal/vertical lines
    if (widget.currentTool == DrawingToolType.horizontalLine ||
        widget.currentTool == DrawingToolType.verticalLine) {
      final point = _converter!.screenToChartPoint(position);
      if (point != null) {
        widget.onDrawingStart?.call(point);
      }
    }
  }

  void _onDrawingStart(Offset position) {
    if (_converter == null) return;

    // Only start drawing if in chart area
    if (!_converter!.isInChartArea(position)) return;

    _isDrawing = true;
    final point = _converter!.screenToChartPoint(position);
    if (point != null) {
      widget.onDrawingStart?.call(point);
    }
    setState(() {
      _crosshairPosition = position;
    });
  }

  void _onDrawingUpdate(Offset position) {
    if (!_isDrawing || _converter == null) return;

    final point = _converter!.screenToChartPoint(position);
    if (point != null) {
      widget.onDrawingUpdate?.call(point);
    }
    setState(() {
      _crosshairPosition = position;
    });
  }

  void _onDrawingEnd() {
    if (!_isDrawing || _converter == null) return;

    _isDrawing = false;
    final point = _converter!.screenToChartPoint(_crosshairPosition);
    widget.onDrawingComplete?.call(point);
  }

  Widget _buildCrosshairTooltip(Candle candle, BoxConstraints constraints) {
    final isUp = candle.close >= candle.open;
    final change = candle.close - candle.open;
    final changePercent = (change / candle.open) * 100;

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
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(candle.timestamp),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _TooltipRow('O', candle.open.toStringAsFixed(2)),
            _TooltipRow('H', candle.high.toStringAsFixed(2), AppColors.profit),
            _TooltipRow('L', candle.low.toStringAsFixed(2), AppColors.loss),
            _TooltipRow('C', candle.close.toStringAsFixed(2)),
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 4),
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
      final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      final newWidth = (_candleWidth * zoomFactor).clamp(
        _minCandleWidth,
        _maxCandleWidth,
      );

      final chartAreaWidth = chartWidth - _priceAxisWidth;
      final oldTotalWidth =
          widget.candles.length * (_candleWidth * (1 + _candleGap));
      final newTotalWidth =
          widget.candles.length * (newWidth * (1 + _candleGap));

      _candleWidth = newWidth;
      _scrollOffset = (_scrollOffset * (newTotalWidth / oldTotalWidth)).clamp(
        0,
        math.max(0, newTotalWidth - chartAreaWidth),
      );
    });
  }

  // ===========================================================================
  // UNIFIED GESTURE HANDLING
  // ===========================================================================

  /// Handle pan/drag start - determines what action to take
  void _handlePanStart(Offset localPosition, bool isDrawingMode) {
    if (_converter == null) return;

    // First, check if we're clicking on an existing drawing (for selection/move)
    if (!isDrawingMode) {
      for (int i = widget.drawings.length - 1; i >= 0; i--) {
        final drawing = widget.drawings[i];

        // Check anchors first (for resize)
        final anchorIndex = _converter!.hitTestAnchors(localPosition, drawing);
        if (anchorIndex >= 0) {
          setState(() {
            _selectedDrawingIndex = i;
            _selectedAnchorIndex = anchorIndex;
            _dragStartDataPoint = _converter!.screenToChartPoint(localPosition);
            _isPanning = false;
          });
          return;
        }

        // Check body (for move)
        if (_converter!.hitTestBody(localPosition, drawing)) {
          setState(() {
            _selectedDrawingIndex = i;
            _selectedAnchorIndex = -1; // -1 means dragging body
            _dragStartDataPoint = _converter!.screenToChartPoint(localPosition);
            _isPanning = false;
          });
          return;
        }
      }
    }

    // If we're in drawing mode, start a new drawing
    if (isDrawingMode) {
      _onDrawingStart(localPosition);
      return;
    }

    // Otherwise, start panning the chart
    setState(() {
      _isPanning = true;
      _panStartOffset = _scrollOffset;
      _scaleStartFocalPoint = localPosition;
      _selectedDrawingIndex = null;
      _selectedAnchorIndex = null;
    });
  }

  /// Handle pan/drag update
  void _handlePanUpdate(
    Offset localPosition,
    Offset delta,
    bool isDrawingMode,
  ) {
    if (_converter == null) return;

    // If editing a drawing anchor (resize)
    if (_selectedDrawingIndex != null &&
        _selectedAnchorIndex != null &&
        _selectedAnchorIndex! >= 0) {
      _handleDrawingResize(localPosition);
      return;
    }

    // If moving a drawing body
    if (_selectedDrawingIndex != null && _selectedAnchorIndex == -1) {
      _handleDrawingMove(localPosition);
      return;
    }

    // If creating a new drawing
    if (isDrawingMode && _isDrawing) {
      _onDrawingUpdate(localPosition);
      return;
    }

    // If panning the chart
    if (_isPanning &&
        _panStartOffset != null &&
        _scaleStartFocalPoint != null) {
      setState(() {
        // Calculate delta from start position
        final dx = _scaleStartFocalPoint!.dx - localPosition.dx;
        final totalWidth =
            widget.candles.length * (_candleWidth * (1 + _candleGap));

        // ALWAYS allow panning, even if all candles fit on screen
        // Min scroll: negative value to allow panning left (show future space)
        // Max scroll: positive value to pan right (show older candles)
        final minScroll = -_chartWidth * 0.5; // Allow 50% future space
        final maxScroll = math.max(
          totalWidth * 0.5,
          totalWidth - _chartWidth + _chartWidth * 0.5,
        );

        _scrollOffset = (_panStartOffset! + dx).clamp(minScroll, maxScroll);
        _updateDebugText();
      });
    }
  }

  /// Handle pan/drag end
  void _handlePanEnd(bool isDrawingMode) {
    if (isDrawingMode && _isDrawing) {
      _onDrawingEnd();
    }

    setState(() {
      _isPanning = false;
      _panStartOffset = null;
      _scaleStartFocalPoint = null;
      _selectedAnchorIndex = null;
      // Keep _selectedDrawingIndex to show selection
    });
  }

  /// Handle resizing a drawing by dragging an anchor
  void _handleDrawingResize(Offset localPosition) {
    if (_selectedDrawingIndex == null || _selectedAnchorIndex == null) return;
    if (_selectedDrawingIndex! >= widget.drawings.length) return;

    final newPoint = _converter!.screenToChartPoint(localPosition);
    if (newPoint == null) return;

    // TODO: Call back to update drawing anchor in provider
    // For now, we just update the debug
    _updateDebugText();
  }

  /// Handle moving an entire drawing
  void _handleDrawingMove(Offset localPosition) {
    if (_selectedDrawingIndex == null || _dragStartDataPoint == null) return;
    if (_selectedDrawingIndex! >= widget.drawings.length) return;

    final newPoint = _converter!.screenToChartPoint(localPosition);
    if (newPoint == null) return;

    // Calculate delta in data space
    final deltaPrice = newPoint.price - _dragStartDataPoint!.price;
    final deltaTime = newPoint.timestamp.difference(
      _dragStartDataPoint!.timestamp,
    );

    // TODO: Call back to update all anchor points in provider
    // For now, we just update the debug
    _updateDebugText();
  }

  // Legacy methods (kept for compatibility with mouse wheel zoom)
  void _onScaleStart(ScaleStartDetails details) {
    _panStartOffset = _scrollOffset;
    _scaleStartWidth = _candleWidth;
    _scaleStartFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double chartWidth) {
    setState(() {
      final chartAreaWidth = chartWidth - _priceAxisWidth;

      if (details.scale != 1.0 && _scaleStartWidth != null) {
        final newWidth = (_scaleStartWidth! * details.scale).clamp(
          _minCandleWidth,
          _maxCandleWidth,
        );
        _candleWidth = newWidth;
      }

      if (_panStartOffset != null && _scaleStartFocalPoint != null) {
        final dx = _scaleStartFocalPoint!.dx - details.localFocalPoint.dx;
        final totalWidth =
            widget.candles.length * (_candleWidth * (1 + _candleGap));
        final maxScroll = math.max(0.0, totalWidth - chartAreaWidth + 100);
        _scrollOffset = (_panStartOffset! + dx).clamp(0.0, maxScroll);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _panStartOffset = null;
    _scaleStartWidth = null;
    _scaleStartFocalPoint = null;
  }

  void _onCrosshairStart(Offset position) {
    _updateCrosshair(position);
  }

  void _onCrosshairMove(Offset position) {
    _updateCrosshair(position);
  }

  void _updateCrosshair(Offset position) {
    if (_converter == null) return;

    final candle = _converter!.candleAtX(position.dx);
    if (candle != null) {
      setState(() {
        _showCrosshair = true;
        _crosshairPosition = position;
        _selectedCandle = candle;
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
  final ChartCoordinateConverter? converter;

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
    this.converter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final chartWidth = size.width - priceAxisWidth;
    final chartHeight = size.height;
    final candleStep = candleWidth * (1 + candleGap);

    // Create converter if not provided
    final conv =
        converter ??
        ChartCoordinateConverter(
          candles: candles,
          scrollOffset: scrollOffset,
          candleWidth: candleWidth,
          candleGap: candleGap,
          chartWidth: chartWidth,
          chartHeight: chartHeight,
          priceAxisWidth: priceAxisWidth,
        );

    final minPrice = conv.minPrice;
    final maxPrice = conv.maxPrice;

    // Calculate visible range
    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);

    // Draw grid
    _drawGrid(canvas, size, chartWidth, chartHeight, minPrice, maxPrice);

    // Draw position lines (SL/TP)
    for (final line in positionLines) {
      _drawPriceLine(
        canvas,
        chartWidth,
        chartHeight,
        minPrice,
        maxPrice,
        line.price,
        line.color,
        line.label,
        line.isDashed,
      );
    }

    // Draw candles
    for (int i = startIndex; i < endIndex; i++) {
      if (i < 0 || i >= candles.length) continue;

      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset - candleWidth / 2;

      if (x < -candleWidth * 2 || x > chartWidth + candleWidth * 2) continue;

      _drawCandle(canvas, candle, x, chartHeight, minPrice, maxPrice);
    }

    // Draw indicators
    for (final indicator in indicators) {
      if (indicator.enabled) {
        _drawIndicator(
          canvas,
          chartWidth,
          chartHeight,
          minPrice,
          maxPrice,
          candleStep,
          startIndex,
          endIndex,
          indicator,
        );
      }
    }

    // Draw current price line
    if (currentPrice != null) {
      _drawCurrentPriceLine(
        canvas,
        chartWidth,
        chartHeight,
        minPrice,
        maxPrice,
      );
    }

    // Draw markers
    _drawMarkers(
      canvas,
      chartWidth,
      chartHeight,
      minPrice,
      maxPrice,
      startIndex,
      endIndex,
    );

    // Draw all drawings using converter
    for (final drawing in drawings) {
      _drawDrawing(canvas, conv, drawing);
    }

    // Draw active drawing
    if (activeDrawing != null) {
      _drawDrawing(canvas, conv, activeDrawing!);
    }

    // Draw price axis
    _drawPriceAxis(canvas, size, chartHeight, minPrice, maxPrice);

    // Draw crosshair
    if (showCrosshair) {
      _drawCrosshair(canvas, chartWidth, chartHeight, minPrice, maxPrice);
    }
  }

  /// Draw a chart drawing using the unified coordinate converter
  void _drawDrawing(
    Canvas canvas,
    ChartCoordinateConverter conv,
    ChartDrawing drawing,
  ) {
    switch (drawing.type) {
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
        final line = drawing as TrendLineDrawing;
        if (line.endPoint == null) return;

        final p1 = conv.chartPointToScreen(line.startPoint);
        final p2 = conv.chartPointToScreen(line.endPoint!);

        final paint = Paint()
          ..color = line.color
          ..strokeWidth = line.strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(p1, p2, paint);

        // Draw anchor points
        if (line.isSelected) {
          _drawAnchor(canvas, p1, line.color);
          _drawAnchor(canvas, p2, line.color);
        }
        // Always draw small dots on endpoints for visibility
        _drawSmallAnchor(canvas, p1, line.color);
        _drawSmallAnchor(canvas, p2, line.color);
        break;

      case DrawingToolType.horizontalLine:
        final hLine = drawing as HorizontalLineDrawing;
        final y = conv.priceToY(hLine.price);

        if (y < 0 || y > conv.chartHeight) return;

        final paint = Paint()
          ..color = hLine.color
          ..strokeWidth = hLine.strokeWidth;

        // Dashed line
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        double startX = 0;

        while (startX < conv.chartWidth) {
          canvas.drawLine(
            Offset(startX, y),
            Offset(math.min(startX + dashWidth, conv.chartWidth), y),
            paint,
          );
          startX += dashWidth + dashSpace;
        }

        // Price label
        final labelBg = Paint()..color = hLine.color;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(conv.chartWidth, y - 10, priceAxisWidth, 20),
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
          Offset(
            conv.chartWidth + (priceAxisWidth - textPainter.width) / 2,
            y - 5,
          ),
        );
        break;

      case DrawingToolType.fibonacciRetracement:
        final fib = drawing as FibonacciDrawing;
        if (fib.endPoint == null) return;

        final p1 = conv.chartPointToScreen(fib.startPoint);
        final p2 = conv.chartPointToScreen(fib.endPoint!);
        final minX = math.min(p1.dx, p2.dx);
        final maxX = math.max(p1.dx, p2.dx);

        final paint = Paint()
          ..color = fib.color
          ..strokeWidth = 0.8;

        // Draw each Fibonacci level
        for (final level in FibonacciDrawing.defaultLevels) {
          final price = fib.getPriceForLevel(level);
          if (price == null) continue;

          final y = conv.priceToY(price);
          if (y < 0 || y > conv.chartHeight) continue;

          canvas.drawLine(Offset(minX, y), Offset(maxX, y), paint);

          final labelText =
              '${(level * 100).toStringAsFixed(1)}% (${price.toStringAsFixed(2)})';
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

        // Draw boundary box fill
        final boxPaint = Paint()
          ..color = fib.color.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;

        canvas.drawRect(Rect.fromPoints(p1, p2), boxPaint);

        // Draw anchor points
        _drawAnchor(canvas, p1, fib.color);
        _drawAnchor(canvas, p2, fib.color);
        break;

      case DrawingToolType.rectangle:
        final rect = drawing as RectangleDrawing;
        if (rect.endPoint == null) return;

        final p1 = conv.chartPointToScreen(rect.startPoint);
        final p2 = conv.chartPointToScreen(rect.endPoint!);
        final rectBounds = Rect.fromPoints(p1, p2);

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

        // Draw anchor points at corners
        if (rect.isSelected) {
          _drawAnchor(canvas, Offset(p1.dx, p1.dy), rect.color);
          _drawAnchor(canvas, Offset(p2.dx, p2.dy), rect.color);
          _drawAnchor(canvas, Offset(p1.dx, p2.dy), rect.color);
          _drawAnchor(canvas, Offset(p2.dx, p1.dy), rect.color);
        }
        // Always show small anchors
        _drawSmallAnchor(canvas, p1, rect.color);
        _drawSmallAnchor(canvas, p2, rect.color);
        break;

      case DrawingToolType.verticalLine:
        // TODO: Implement vertical line
        break;

      case DrawingToolType.none:
        break;
    }
  }

  void _drawAnchor(Canvas canvas, Offset point, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 5, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(point, 5, borderPaint);
  }

  void _drawSmallAnchor(Canvas canvas, Offset point, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, 3, paint);
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) {
    if (!showGrid) return;

    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    final priceStep = _calculatePriceStep(maxPrice - minPrice);
    var price = (minPrice / priceStep).ceil() * priceStep;

    while (price < maxPrice) {
      final y =
          chartHeight -
          ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;
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

  List<double?> _calculateEMA(int period) {
    if (candles.length < period) return List.filled(candles.length, null);

    final emaValues = List<double?>.filled(candles.length, null);
    final multiplier = 2 / (period + 1);

    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    emaValues[period - 1] = sum / period;

    for (int i = period; i < candles.length; i++) {
      final prevEma = emaValues[i - 1]!;
      emaValues[i] = (candles[i].close - prevEma) * multiplier + prevEma;
    }

    return emaValues;
  }

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
      final y =
          chartHeight -
          ((emaValue - minPrice) / (maxPrice - minPrice)) * chartHeight;

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

  void _drawCandle(
    Canvas canvas,
    Candle candle,
    double x,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) {
    final isUp = candle.close >= candle.open;
    final color = isUp ? AppColors.profit : AppColors.loss;

    final openY =
        chartHeight -
        ((candle.open - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final closeY =
        chartHeight -
        ((candle.close - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final highY =
        chartHeight -
        ((candle.high - minPrice) / (maxPrice - minPrice)) * chartHeight;
    final lowY =
        chartHeight -
        ((candle.low - minPrice) / (maxPrice - minPrice)) * chartHeight;

    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(x + candleWidth / 2, highY),
      Offset(x + candleWidth / 2, lowY),
      wickPaint,
    );

    final bodyTop = math.min(openY, closeY);
    final bodyBottom = math.max(openY, closeY);
    // Ensure minimum body height for doji candles (where open ≈ close)
    final bodyHeight = math.max(2.0, bodyBottom - bodyTop);

    // FIXED: Both bullish and bearish candles should be FILLED
    // Using stroke for bullish made small bodies look like thin lines
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight),
      bodyPaint,
    );
    
    // Add a thin border for better visibility on small candles
    if (bodyHeight < 4) {
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(
        Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight),
        borderPaint,
      );
    }
  }

  void _drawCurrentPriceLine(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) {
    if (currentPrice == null) return;

    final y =
        chartHeight -
        ((currentPrice! - minPrice) / (maxPrice - minPrice)) * chartHeight;

    if (y < 0 || y > chartHeight) return;

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

  void _drawPriceLine(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
    double price,
    Color color,
    String? label,
    bool isDashed,
  ) {
    final y =
        chartHeight -
        ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;

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

  void _drawMarkers(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
    int startIndex,
    int endIndex,
  ) {
    if (markers.isEmpty || candles.isEmpty) return;

    final candleStep = candleWidth * (1 + candleGap);

    for (final marker in markers) {
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

      final y =
          chartHeight -
          ((marker.price - minPrice) / (maxPrice - minPrice)) * chartHeight;
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

  void _drawPriceAxis(
    Canvas canvas,
    Size size,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) {
    final chartWidth = size.width - priceAxisWidth;

    final bgPaint = Paint()..color = AppColors.surface;
    canvas.drawRect(
      Rect.fromLTWH(chartWidth, 0, priceAxisWidth, chartHeight),
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chartWidth, 0),
      Offset(chartWidth, chartHeight),
      borderPaint,
    );

    final priceStep = _calculatePriceStep(maxPrice - minPrice);
    var price = (minPrice / priceStep).ceil() * priceStep;

    while (price < maxPrice) {
      final y =
          chartHeight -
          ((price - minPrice) / (maxPrice - minPrice)) * chartHeight;

      final textPainter = TextPainter(
        text: TextSpan(
          text: _formatPrice(price),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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

  void _drawCrosshair(
    Canvas canvas,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) {
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    canvas.drawLine(
      Offset(crosshairPosition.dx, 0),
      Offset(crosshairPosition.dx, chartHeight),
      paint,
    );

    canvas.drawLine(
      Offset(0, crosshairPosition.dy),
      Offset(chartWidth, crosshairPosition.dy),
      paint,
    );

    final price =
        maxPrice - (crosshairPosition.dy / chartHeight) * (maxPrice - minPrice);

    final bgPaint = Paint()..color = AppColors.surfaceLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          chartWidth,
          crosshairPosition.dy - 10,
          priceAxisWidth,
          20,
        ),
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

    textPainter.paint(canvas, Offset(chartWidth + 6, crosshairPosition.dy - 5));
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

    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);

    double maxVolume = 0;
    for (
      int i = math.max(0, candles.length - endIndex - 1).toInt();
      i < math.min(candles.length, candles.length - startIndex + 1).toInt();
      i++
    ) {
      maxVolume = math.max(maxVolume, candles[i].volume);
    }

    if (maxVolume == 0) return;

    for (int i = startIndex; i < endIndex; i++) {
      if (i < 0 || i >= candles.length) continue;

      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset - candleWidth / 2;

      if (x < -candleWidth * 2 || x > chartWidth + candleWidth * 2) continue;

      final isUp = candle.close >= candle.open;
      final barHeight = (candle.volume / maxVolume) * chartHeight * 0.8;

      final paint = Paint()
        ..color = (isUp ? AppColors.profit : AppColors.loss).withValues(
          alpha: 0.4,
        )
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

    final minLabelSpacing = 70.0;
    final labelInterval = (minLabelSpacing / candleStep).ceil();

    final visibleCount = (chartWidth / candleStep).ceil() + 2;
    final startIndex = (scrollOffset / candleStep).floor();
    final endIndex = math.min(startIndex + visibleCount, candles.length);

    for (int i = startIndex; i < endIndex; i += labelInterval) {
      if (i < 0 || i >= candles.length) continue;

      final candle = candles[candles.length - 1 - i];
      final x = chartWidth - (i * candleStep) + scrollOffset;

      if (x < 0 || x > chartWidth) continue;

      final label = _formatTime(candle.timestamp);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 9),
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

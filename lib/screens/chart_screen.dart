import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/logger.dart';
import '../core/debug_trace.dart';
import '../core/responsive.dart';
import '../models/chart_drawing.dart';
import '../models/chart_marker.dart';
import '../models/paper_trading.dart';
import '../models/timeframe.dart';
import '../state/chart_drawing_provider.dart';
import '../state/market_data_provider.dart';
import '../state/paper_trading_provider.dart';
import '../state/trade_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/candlestick_chart.dart';
import '../widgets/position_size_calculator.dart';

export '../widgets/charts/candlestick_chart.dart' show ChartIndicator;

/// Main charting screen - Professional trading experience
///
/// Features:
/// - Symbol selector with search
/// - Timeframe buttons
/// - Interactive candlestick chart with crosshair
/// - OHLC stats bar
/// - Open positions panel
/// - Order entry with SL/TP
/// - Trade notifications
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  // Chart settings
  bool _showGrid = true;
  bool _showDebugOverlay = false;
  bool _showLeftPanel = false;

  // RSI panel visibility
  bool _showRsiPanel = false;

  final List<ChartIndicator> _indicators = [
    ChartIndicator(
      name: 'EMA',
      period: 9,
      color: const Color(0xFFFFD700),
      enabled: false,
    ),
    ChartIndicator(
      name: 'EMA',
      period: 21,
      color: const Color(0xFF00BFFF),
      enabled: false,
    ),
    ChartIndicator(
      name: 'SMA',
      period: 50,
      color: const Color(0xFFFF69B4),
      enabled: false,
    ),
    ChartIndicator(
      name: 'SMA',
      period: 200,
      color: const Color(0xFF9370DB),
      enabled: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final marketProvider = context.read<MarketDataProvider>();

      // IMPORTANT: Always call init() if not initialized
      // This handles hot restart recovery and initial load
      // Mock data will be used automatically if no API key is configured
      if (!marketProvider.isInitialized && !marketProvider.isLoading) {
        Log.d('ChartScreen: Triggering MarketDataProvider.init()');
        marketProvider.init();
      }

      // Wire up position tool cleanup callback
      // When a position closes, automatically remove/hide its linked tool
      final paperProvider = context.read<PaperTradingProvider>();
      final drawingProvider = context.read<ChartDrawingProvider>();

      paperProvider.onToolShouldBeRemoved = (toolId) {
        Log.d(
          'ChartScreen: Removing position tool $toolId after position closed',
        );
        drawingProvider.deleteDrawing(toolId);

        // Refresh trade list to show the new closed trade
        if (mounted) {
          context.read<TradeProvider>().refresh();
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<MarketDataProvider>(
          builder: (context, provider, _) {
            // Show loading while initializing
            if (!provider.isInitialized) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 16),
                    Text(
                      'Loading market data...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            // Sync price to paper trading provider
            if (provider.lastPrice != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.read<PaperTradingProvider>().updatePrice(
                    provider.lastPrice!,
                  );
                }
              });
            }

            final isMobile = Responsive.isMobile(context);

            return Row(
              children: [
                // Left sidebar with tools (desktop only)
                if (!isMobile) _buildLeftSidebar(),

                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Header bar (responsive)
                      _buildHeader(provider, isMobile: isMobile),

                      // OHLC stats + timeframes (responsive)
                      _buildStatsAndTimeframes(provider, isMobile: isMobile),

                      // Chart area + RSI panel
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            // Main chart
                            Expanded(
                              flex: _showRsiPanel ? 3 : 1,
                              child: _buildChartArea(provider),
                            ),

                            // RSI Panel (separate oscillator)
                            if (_showRsiPanel)
                              _RsiPanel(candles: provider.candles),
                          ],
                        ),
                      ),

                      // Replay controls
                      _ReplayControls(provider: provider),

                      // Trading panel (responsive)
                      _TradingPanel(isMobile: isMobile),
                    ],
                  ),
                ),

                // Position size calculator panel (right side when open, desktop only)
                if (_showLeftPanel && !isMobile) _buildPositionSizePanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(MarketDataProvider provider, {bool isMobile = false}) {
    final price = provider.lastPrice?.price;
    final candles = provider.candles;

    // Calculate change from previous close
    double? change;
    double? changePercent;
    if (candles.length >= 2 && price != null) {
      final prevClose = candles[candles.length - 2].close;
      change = price - prevClose;
      changePercent = (change / prevClose) * 100;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 12, 8, isMobile ? 8 : 12, 4),
      child: Row(
        children: [
          // Symbol selector
          GestureDetector(
            onTap: () => _showSymbolSearch(context, provider),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.currentSymbol,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: isMobile ? 18 : 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Price display
          if (price != null) ...[
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (change != null && !isMobile) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: change >= 0
                      ? AppColors.profit.withValues(alpha: 0.15)
                      : AppColors.loss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${change >= 0 ? '+' : ''}${changePercent!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: change >= 0 ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ),
            ],
          ],

          const Spacer(),

          // Drawing tools - Desktop: inline toolbar, Mobile: popup menu
          if (isMobile)
            _MobileDrawingToolsMenu(
              onShowPositionCalc: () => _showMobilePositionCalculator(context),
              onPositionToolTap: (isLong) =>
                  _showPositionToolSettingsSheet(context, isLong),
            )
          else
            _DrawingToolbar(
              onPositionToolTap: (isLong) =>
                  _showPositionToolSettingsSheet(context, isLong),
            ),

          const SizedBox(width: 4),

          // Mock mode indicator (hide on mobile to save space)
          if (provider.isMockMode && !isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),

          if (!isMobile) const SizedBox(width: 8),

          // Chart settings button
          GestureDetector(
            onTap: () => _showChartSettings(context),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: AppColors.textSecondary,
                size: isMobile ? 16 : 18,
              ),
            ),
          ),

          SizedBox(width: isMobile ? 4 : 8),

          // Connection status
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              provider.isConnected
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              color: provider.isConnected ? AppColors.profit : AppColors.loss,
              size: isMobile ? 16 : 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Show position size calculator in a bottom sheet on mobile
  void _showMobilePositionCalculator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Position Size Calculator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border),
            // Calculator
            const Expanded(child: PositionSizeCalculator()),
          ],
        ),
      ),
    );
  }

  /// Show position tool settings sheet before placing a Long/Short position
  void _showPositionToolSettingsSheet(BuildContext context, bool isLong) {
    final drawingProvider = context.read<ChartDrawingProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PositionToolSettingsSheet(
        isLong: isLong,
        initialSlPercent: drawingProvider.defaultSlPercent,
        initialRrRatio: drawingProvider.defaultRiskRewardRatio,
        initialQuantity: drawingProvider.defaultQuantity,
        onConfirm: (slPercent, rrRatio, quantity) {
          // Set the presets in the provider
          drawingProvider.setPositionToolDefaults(
            slPercent: slPercent,
            riskRewardRatio: rrRatio,
            quantity: quantity,
            useRatioMode: true,
          );
          // Activate the tool
          drawingProvider.setTool(
            isLong
                ? DrawingToolType.longPosition
                : DrawingToolType.shortPosition,
          );
        },
      ),
    );
  }

  void _showChartSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'Chart Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid toggle
              SwitchListTile(
                title: const Text('Show Grid'),
                value: _showGrid,
                onChanged: (v) {
                  setSheetState(() => _showGrid = v);
                  setState(() => _showGrid = v);
                },
                activeTrackColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
              ),

              const Divider(color: AppColors.border),
              const SizedBox(height: 8),

              const Text(
                'Indicators',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // EMA toggles
              ..._indicators.asMap().entries.map((entry) {
                final i = entry.key;
                final indicator = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: indicator.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${indicator.name} ${indicator.period}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: indicator.enabled,
                        onChanged: (v) {
                          setSheetState(() {
                            _indicators[i] = indicator.copyWith(enabled: v);
                          });
                          setState(() {
                            _indicators[i] = indicator.copyWith(enabled: v);
                          });
                        },
                        activeTrackColor: indicator.color,
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // RSI toggle
              SwitchListTile(
                title: const Text('RSI (14)'),
                subtitle: const Text('Relative Strength Index'),
                value: _showRsiPanel,
                onChanged: (v) {
                  setSheetState(() => _showRsiPanel = v);
                  setState(() => _showRsiPanel = v);
                },
                activeTrackColor: const Color(0xFFE91E63),
                contentPadding: EdgeInsets.zero,
              ),

              const Divider(color: AppColors.border),
              const SizedBox(height: 8),

              // Debug overlay toggle
              SwitchListTile(
                title: const Text('Debug Overlay'),
                subtitle: const Text('Show coordinate debug info'),
                value: _showDebugOverlay,
                onChanged: (v) {
                  setSheetState(() => _showDebugOverlay = v);
                  setState(() => _showDebugOverlay = v);
                },
                activeTrackColor: AppColors.warning,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Left sidebar with quick access tools
  Widget _buildLeftSidebar() {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Position size calculator
          _LeftSidebarButton(
            icon: Icons.calculate_rounded,
            label: 'Position Size',
            isSelected: _showLeftPanel,
            onTap: () => setState(() => _showLeftPanel = !_showLeftPanel),
          ),

          const SizedBox(height: 4),

          // RSI toggle
          _LeftSidebarButton(
            icon: Icons.show_chart_rounded,
            label: 'RSI',
            isSelected: _showRsiPanel,
            onTap: () => setState(() => _showRsiPanel = !_showRsiPanel),
          ),

          const SizedBox(height: 4),

          // Indicators quick access
          _LeftSidebarButton(
            icon: Icons.timeline_rounded,
            label: 'Indicators',
            isSelected: _indicators.any((i) => i.enabled),
            onTap: () => _showChartSettings(context),
          ),

          const Spacer(),

          // Debug toggle
          _LeftSidebarButton(
            icon: Icons.bug_report_outlined,
            label: 'Debug',
            isSelected: _showDebugOverlay,
            onTap: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
            small: true,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Position size calculator panel
  Widget _buildPositionSizePanel() {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Position Size Calculator',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showLeftPanel = false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Calculator
          const Expanded(child: PositionSizeCalculator()),
        ],
      ),
    );
  }

  Widget _buildStatsAndTimeframes(
    MarketDataProvider provider, {
    bool isMobile = false,
  }) {
    final candles = provider.candles;
    final lastCandle = candles.isNotEmpty ? candles.last : null;

    if (isMobile) {
      // Mobile layout: Compact OHLC + scrollable timeframes
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Compact OHLC in a single row
            if (lastCandle != null)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatChip(
                        'O',
                        lastCandle.open.toStringAsFixed(2),
                        compact: true,
                      ),
                      _StatChip(
                        'H',
                        lastCandle.high.toStringAsFixed(2),
                        color: AppColors.profit,
                        compact: true,
                      ),
                      _StatChip(
                        'L',
                        lastCandle.low.toStringAsFixed(2),
                        color: AppColors.loss,
                        compact: true,
                      ),
                      _StatChip(
                        'C',
                        lastCandle.close.toStringAsFixed(2),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(width: 4),

            // Timeframe selector - scrollable on mobile
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: Timeframe.quickSelect.map((tf) {
                    final isSelected = provider.currentTimeframe == tf;
                    return Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: GestureDetector(
                        onTap: () => provider.setTimeframe(tf),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            tf.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.background
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop layout (unchanged)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // OHLC stats
          if (lastCandle != null) ...[
            _StatChip('O', lastCandle.open.toStringAsFixed(2)),
            _StatChip(
              'H',
              lastCandle.high.toStringAsFixed(2),
              color: AppColors.profit,
            ),
            _StatChip(
              'L',
              lastCandle.low.toStringAsFixed(2),
              color: AppColors.loss,
            ),
            _StatChip('C', lastCandle.close.toStringAsFixed(2)),
          ],

          const Spacer(),

          // Timeframe selector
          ...Timeframe.quickSelect.map((tf) {
            final isSelected = provider.currentTimeframe == tf;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => provider.setTimeframe(tf),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    tf.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChartArea(MarketDataProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Loading chart...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (provider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.loss,
            ),
            const SizedBox(height: 16),
            Text(
              provider.error ?? 'Failed to load chart',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Consumer3<TradeProvider, PaperTradingProvider, ChartDrawingProvider>(
      builder: (context, tradeProvider, paperProvider, drawingProvider, _) {
        final markers = _buildChartMarkers(
          provider.currentSymbol,
          tradeProvider,
          paperProvider,
        );
        final positionLines = _buildPositionLines(
          provider.currentSymbol,
          paperProvider,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CandlestickChart(
            candles: provider.candles,
            currentPrice: provider.lastPrice?.price,
            showVolume: true,
            markers: markers,
            positionLines: positionLines,
            indicators: _indicators.where((i) => i.enabled).toList(),
            showGrid: _showGrid,
            showDebugOverlay: _showDebugOverlay,
            drawings: drawingProvider.drawings,
            activeDrawing: drawingProvider.activeDrawing,
            currentTool: drawingProvider.currentTool,
            onDrawingStart: drawingProvider.startDrawing,
            onDrawingUpdate: drawingProvider.updateDrawing,
            onDrawingComplete: drawingProvider.completeDrawing,
            onDrawingSelected: (id) {
              drawingProvider.selectDrawing(id);
            },
            onPositionToolStart: (point, isLong) {
              drawingProvider.startPositionTool(
                symbol: provider.currentSymbol,
                point: point,
                isLong: isLong,
              );
              // Show the position tool sheet after creation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final posTools = drawingProvider.positionTools;
                if (posTools.isNotEmpty) {
                  _showPositionToolSheet(context, posTools.last);
                }
              });
            },
          ),
        );
      },
    );
  }

  List<ChartMarker> _buildChartMarkers(
    String symbol,
    TradeProvider tradeProvider,
    PaperTradingProvider paperProvider,
  ) {
    final markers = <ChartMarker>[];

    for (final trade in tradeProvider.trades) {
      if (trade.symbol.toUpperCase() == symbol.toUpperCase()) {
        markers.addAll(ChartMarker.fromTrade(trade));
      }
    }

    for (final position in paperProvider.closedPositions) {
      if (position.symbol.toUpperCase() == symbol.toUpperCase()) {
        markers.addAll(ChartMarker.fromPosition(position));
      }
    }

    markers.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return markers;
  }

  List<ChartLine> _buildPositionLines(
    String symbol,
    PaperTradingProvider paperProvider,
  ) {
    final lines = <ChartLine>[];

    for (final position in paperProvider.openPositions) {
      if (position.symbol.toUpperCase() == symbol.toUpperCase()) {
        lines.addAll(ChartLine.fromPosition(position));
      }
    }

    return lines;
  }

  void _showSymbolSearch(BuildContext context, MarketDataProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SymbolSearchSheet(provider: provider),
    );
  }

  /// Show position tool management sheet
  void _showPositionToolSheet(BuildContext context, PositionToolDrawing tool) {
    final drawingProvider = Provider.of<ChartDrawingProvider>(
      context,
      listen: false,
    );
    final paperProvider = Provider.of<PaperTradingProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (tool.isLong ? AppColors.profit : AppColors.loss)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tool.isLong
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: tool.isLong ? AppColors.profit : AppColors.loss,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tool.isLong ? "LONG" : "SHORT"} ${tool.symbol}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _getStatusText(tool.status),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(tool.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Position details
                _PositionDetailRow(
                  label: 'Entry',
                  value: '\$${tool.entryPrice.toStringAsFixed(2)}',
                  color: AppColors.accent,
                ),
                _PositionDetailRow(
                  label: 'Stop Loss',
                  value: '\$${tool.stopLossPrice.toStringAsFixed(2)}',
                  subValue: '-\$${tool.riskPerShare.toStringAsFixed(2)}/share',
                  color: AppColors.loss,
                ),
                _PositionDetailRow(
                  label: 'Take Profit',
                  value: '\$${tool.takeProfitPrice.toStringAsFixed(2)}',
                  subValue:
                      '+\$${tool.rewardPerShare.toStringAsFixed(2)}/share',
                  color: AppColors.profit,
                ),
                const Divider(height: 24, color: AppColors.border),

                // Risk/Reward stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Risk:Reward',
                        value: '1:${tool.riskRewardRatio.toStringAsFixed(1)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Quantity',
                        value: tool.quantity.toStringAsFixed(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Risk Amount',
                        value: '\$${tool.totalRisk.toStringAsFixed(2)}',
                        color: AppColors.loss,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Actions based on status
                if (tool.status == PositionToolStatus.draft) ...[
                  // Activate button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Create actual position with linked tool ID
                        final positionId = await paperProvider
                            .openPositionFromTool(
                              symbol: tool.symbol,
                              isLong: tool.isLong,
                              entryPrice: tool.entryPrice,
                              quantity: tool.quantity,
                              stopLoss: tool.stopLossPrice,
                              takeProfit: tool.takeProfitPrice,
                              toolId: tool.id, // Link the tool to the position
                            );

                        if (positionId != null) {
                          // Link position tool to actual position
                          drawingProvider.activatePositionTool(
                            tool.id,
                            positionId,
                          );
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${tool.isLong ? "Long" : "Short"} position opened!',
                                ),
                                backgroundColor: tool.isLong
                                    ? AppColors.profit
                                    : AppColors.loss,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  paperProvider.error ??
                                      'Failed to open position',
                                ),
                                backgroundColor: AppColors.loss,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Activate Position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tool.isLong
                            ? AppColors.profit
                            : AppColors.loss,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (tool.status == PositionToolStatus.active) ...[
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (tool.linkedPositionId != null) {
                          JournalDebug.chartTrade(
                            'TOOL_SHEET_CLOSE_PRESSED',
                            positionId: tool.linkedPositionId,
                            toolId: tool.id,
                          );

                          final success = await paperProvider.closePosition(
                            tool.linkedPositionId!,
                          );

                          if (success) {
                            final result = paperProvider
                                .getClosedPositionResult(
                                  tool.linkedPositionId!,
                                );
                            if (result != null) {
                              drawingProvider.closePositionTool(
                                tool.id,
                                result.exitPrice,
                                result.pnl,
                              );
                            }

                            // CRITICAL: Refresh journal to show the newly closed trade
                            JournalDebug.journalLoad(
                              'TOOL_SHEET_TRIGGERING_JOURNAL_REFRESH',
                              userId: paperProvider.userId,
                            );
                            try {
                              await context.read<TradeProvider>().refresh();
                              JournalDebug.journalLoad(
                                'TOOL_SHEET_JOURNAL_REFRESH_COMPLETE',
                                userId: paperProvider.userId,
                              );
                            } catch (e) {
                              JournalDebug.journalLoad(
                                'TOOL_SHEET_JOURNAL_REFRESH_ERROR',
                                userId: paperProvider.userId,
                                error: e.toString(),
                              );
                            }

                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Position closed: ${result != null ? (result.pnl >= 0 ? "+\$${result.pnl.toStringAsFixed(2)}" : "-\$${result.pnl.abs().toStringAsFixed(2)}") : ""}',
                                  ),
                                  backgroundColor: (result?.pnl ?? 0) >= 0
                                      ? AppColors.profit
                                      : AppColors.loss,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close Position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loss,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (tool.status == PositionToolStatus.closed) ...[
                  // P&L Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          ((tool.realizedPnL ?? 0) >= 0
                                  ? AppColors.profit
                                  : AppColors.loss)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            ((tool.realizedPnL ?? 0) >= 0
                                    ? AppColors.profit
                                    : AppColors.loss)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'POSITION CLOSED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(tool.realizedPnL ?? 0) >= 0 ? "+" : ""}\$${(tool.realizedPnL ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: (tool.realizedPnL ?? 0) >= 0
                                ? AppColors.profit
                                : AppColors.loss,
                          ),
                        ),
                        Text(
                          'Exit: \$${tool.exitPrice?.toStringAsFixed(2) ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Delete button
                TextButton.icon(
                  onPressed: () {
                    drawingProvider.deleteDrawing(tool.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove from Chart'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.loss),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(PositionToolStatus status) {
    return switch (status) {
      PositionToolStatus.draft => 'Draft - Not active',
      PositionToolStatus.active => 'Active - Live position',
      PositionToolStatus.closed => 'Closed',
    };
  }

  Color _getStatusColor(PositionToolStatus status) {
    return switch (status) {
      PositionToolStatus.draft => AppColors.textTertiary,
      PositionToolStatus.active => AppColors.accent,
      PositionToolStatus.closed => AppColors.textSecondary,
    };
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool compact;

  const _StatChip(this.label, this.value, {this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 6 : 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Combined trading panel with positions and order entry
class _TradingPanel extends StatefulWidget {
  final bool isMobile;

  const _TradingPanel({this.isMobile = false});

  @override
  State<_TradingPanel> createState() => _TradingPanelState();
}

class _TradingPanelState extends State<_TradingPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _quantity = 1.0;
  double? _stopLossPercent;
  double? _takeProfitPercent;
  String? _syncedPositionToolId; // Track which position tool we're synced to
  bool _isSyncingFromTool = false; // Prevent circular updates

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Sync SL/TP from a selected position tool to this panel
  void _syncFromPositionTool(PositionToolDrawing? tool, double? currentPrice) {
    if (tool == null || currentPrice == null || currentPrice == 0) {
      _syncedPositionToolId = null;
      return;
    }

    // Calculate percentages from the tool's absolute prices
    final slPercent =
        ((tool.entryPrice - tool.stopLossPrice).abs() / tool.entryPrice) * 100;
    final tpPercent =
        ((tool.takeProfitPrice - tool.entryPrice).abs() / tool.entryPrice) *
        100;

    if (_syncedPositionToolId != tool.id ||
        _stopLossPercent?.toStringAsFixed(1) != slPercent.toStringAsFixed(1) ||
        _takeProfitPercent?.toStringAsFixed(1) !=
            tpPercent.toStringAsFixed(1)) {
      _isSyncingFromTool = true;
      setState(() {
        _stopLossPercent = slPercent;
        _takeProfitPercent = tpPercent;
        _quantity = tool.quantity;
        _syncedPositionToolId = tool.id;
      });
      _isSyncingFromTool = false;
    }
  }

  /// Sync SL/TP from this panel back to the selected position tool
  void _syncToPositionTool(
    ChartDrawingProvider drawingProvider,
    double? currentPrice,
  ) {
    if (_isSyncingFromTool ||
        _syncedPositionToolId == null ||
        currentPrice == null)
      return;

    final selectedId = drawingProvider.selectedDrawingId;
    if (selectedId == null || selectedId != _syncedPositionToolId) return;

    final tool = drawingProvider.positionTools
        .cast<PositionToolDrawing?>()
        .firstWhere((t) => t?.id == selectedId, orElse: () => null);

    if (tool == null) return;

    // Calculate new SL/TP prices from percentages
    if (_stopLossPercent != null) {
      final slDelta = tool.entryPrice * (_stopLossPercent! / 100);
      final newSlPrice = tool.isLong
          ? tool.entryPrice - slDelta
          : tool.entryPrice + slDelta;
      drawingProvider.updatePositionToolStopLoss(selectedId, newSlPrice);
    }

    if (_takeProfitPercent != null) {
      final tpDelta = tool.entryPrice * (_takeProfitPercent! / 100);
      final newTpPrice = tool.isLong
          ? tool.entryPrice + tpDelta
          : tool.entryPrice - tpDelta;
      drawingProvider.updatePositionToolTakeProfit(selectedId, newTpPrice);
    }

    if (_quantity != tool.quantity) {
      drawingProvider.updatePositionToolQuantity(selectedId, _quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.isMobile;

    return Consumer3<
      PaperTradingProvider,
      MarketDataProvider,
      ChartDrawingProvider
    >(
      builder: (context, paperProvider, marketProvider, drawingProvider, _) {
        final currentPrice = paperProvider.getCurrentPrice(
          marketProvider.currentSymbol,
        );
        final openPositions = paperProvider.openPositions
            .where((p) => p.symbol == marketProvider.currentSymbol)
            .toList();

        // Check for selected position tool and sync SL/TP
        final selectedId = drawingProvider.selectedDrawingId;
        PositionToolDrawing? selectedPositionTool;
        if (selectedId != null) {
          final drawing = drawingProvider.drawings
              .cast<ChartDrawing?>()
              .firstWhere((d) => d?.id == selectedId, orElse: () => null);
          if (drawing is PositionToolDrawing) {
            selectedPositionTool = drawing;
            // Sync from tool to panel (one-way during rebuild)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _syncFromPositionTool(selectedPositionTool, currentPrice);
              }
            });
          }
        } else if (_syncedPositionToolId != null) {
          // Position tool was deselected, clear sync
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _syncedPositionToolId = null);
            }
          });
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account summary bar (compact on mobile)
              _buildAccountBar(paperProvider, compact: isMobile),

              // Tabs
              Container(
                height: isMobile ? 32 : 36,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 2,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(
                      text:
                          'Order${openPositions.isNotEmpty ? ' (${openPositions.length})' : ''}',
                    ),
                    const Tab(text: 'Positions'),
                  ],
                ),
              ),

              // Tab content (more compact on mobile)
              SizedBox(
                height: isMobile ? 120 : 140,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderTab(
                      paperProvider,
                      marketProvider,
                      drawingProvider,
                      currentPrice,
                      compact: isMobile,
                    ),
                    _buildPositionsTab(
                      paperProvider,
                      marketProvider,
                      compact: isMobile,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountBar(
    PaperTradingProvider provider, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      child: Row(
        children: [
          _AccountStat(
            'Balance',
            '\$${provider.balance.toStringAsFixed(2)}',
            compact: compact,
          ),
          _AccountStat(
            compact ? 'Unreal' : 'Unrealized',
            '${provider.unrealizedPnL >= 0 ? '+' : ''}\$${provider.unrealizedPnL.toStringAsFixed(2)}',
            color: provider.unrealizedPnL >= 0
                ? AppColors.profit
                : AppColors.loss,
            compact: compact,
          ),
          if (!compact)
            _AccountStat(
              'Realized',
              '${provider.realizedPnL >= 0 ? '+' : ''}\$${provider.realizedPnL.toStringAsFixed(2)}',
              color: provider.realizedPnL >= 0
                  ? AppColors.profit
                  : AppColors.loss,
            ),
          const Spacer(),
          // Reset button
          IconButton(
            onPressed: () => _showResetDialog(context, provider),
            icon: Icon(Icons.refresh_rounded, size: compact ? 16 : 18),
            color: AppColors.textSecondary,
            tooltip: 'Reset Account',
            padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: compact
                ? const BoxConstraints(minWidth: 32, minHeight: 32)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab(
    PaperTradingProvider paperProvider,
    MarketDataProvider marketProvider,
    ChartDrawingProvider drawingProvider,
    double? currentPrice, {
    bool compact = false,
  }) {
    final symbol = marketProvider.currentSymbol;
    final hasPosition = paperProvider.hasPositionFor(symbol);

    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        children: [
          // Quantity and SL/TP row
          Row(
            children: [
              // Quantity selector
              Expanded(
                child: _QuantitySelector(
                  value: _quantity,
                  onChanged: (v) {
                    setState(() => _quantity = v);
                    _syncToPositionTool(drawingProvider, currentPrice);
                  },
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              // SL input
              SizedBox(
                width: compact ? 55 : 70,
                child: _PercentInput(
                  label: 'SL %',
                  value: _stopLossPercent,
                  onChanged: (v) {
                    setState(() => _stopLossPercent = v);
                    _syncToPositionTool(drawingProvider, currentPrice);
                  },
                  isLoss: true,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              // TP input
              SizedBox(
                width: compact ? 55 : 70,
                child: _PercentInput(
                  label: 'TP %',
                  value: _takeProfitPercent,
                  onChanged: (v) {
                    setState(() => _takeProfitPercent = v);
                    _syncToPositionTool(drawingProvider, currentPrice);
                  },
                  isLoss: false,
                  compact: compact,
                ),
              ),
            ],
          ),

          SizedBox(height: compact ? 8 : 12),

          // Buy/Sell buttons
          Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'BUY',
                  sublabel: currentPrice != null
                      ? '\$${currentPrice.toStringAsFixed(2)}'
                      : '--',
                  color: AppColors.profit,
                  onPressed: currentPrice != null
                      ? () => _placeTrade(
                          context,
                          paperProvider,
                          symbol,
                          currentPrice,
                          true,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TradeButton(
                  label: hasPosition ? 'CLOSE' : 'SELL',
                  sublabel: currentPrice != null
                      ? '\$${currentPrice.toStringAsFixed(2)}'
                      : '--',
                  color: AppColors.loss,
                  onPressed: currentPrice != null
                      ? () {
                          if (hasPosition) {
                            _closePosition(context, paperProvider, symbol);
                          } else {
                            _placeTrade(
                              context,
                              paperProvider,
                              symbol,
                              currentPrice,
                              false,
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsTab(
    PaperTradingProvider paperProvider,
    MarketDataProvider marketProvider, {
    bool compact = false,
  }) {
    final positions = paperProvider.openPositions;

    if (positions.isEmpty) {
      return Center(
        child: Text(
          'No open positions',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: compact ? 12 : 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: positions.length,
      itemBuilder: (context, index) {
        final position = positions[index];
        final currentPrice = paperProvider.getCurrentPrice(position.symbol);
        final unrealizedPnL = currentPrice != null
            ? position.unrealizedPnL(currentPrice)
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Side indicator
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: position.isLong ? AppColors.profit : AppColors.loss,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),

              // Position info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          position.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: position.isLong
                                ? AppColors.profit.withValues(alpha: 0.15)
                                : AppColors.loss.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            position.isLong ? 'LONG' : 'SHORT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: position.isLong
                                  ? AppColors.profit
                                  : AppColors.loss,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${position.quantity} @ \$${position.entryPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // P&L
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${unrealizedPnL >= 0 ? '+' : ''}\$${unrealizedPnL.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: unrealizedPnL >= 0
                          ? AppColors.profit
                          : AppColors.loss,
                    ),
                  ),
                  if (currentPrice != null)
                    Text(
                      '\$${currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),

              // Close button
              IconButton(
                onPressed: () =>
                    _closePositionById(context, paperProvider, position.id),
                icon: const Icon(Icons.close_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.loss.withValues(alpha: 0.15),
                  foregroundColor: AppColors.loss,
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
                tooltip: 'Close Position',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _placeTrade(
    BuildContext context,
    PaperTradingProvider provider,
    String symbol,
    double price,
    bool isBuy,
  ) async {
    // Set SL/TP if configured
    provider.setStopLossPercent(_stopLossPercent);
    provider.setTakeProfitPercent(_takeProfitPercent);
    provider.setOrderQuantity(_quantity);

    final success = isBuy
        ? await provider.buy(symbol, price)
        : await provider.sell(symbol, price);

    if (success) {
      _showSnackBar(
        context,
        '${isBuy ? 'Bought' : 'Sold'} $_quantity $symbol @ \$${price.toStringAsFixed(2)}',
        isBuy ? AppColors.profit : AppColors.loss,
      );
    } else if (provider.hasError) {
      _showSnackBar(context, provider.error!, AppColors.loss);
      provider.clearError();
    }
  }

  Future<void> _closePosition(
    BuildContext context,
    PaperTradingProvider provider,
    String symbol,
  ) async {
    final position = provider.getPositionForSymbol(symbol);
    if (position != null) {
      await _closePositionById(context, provider, position.id);
    }
  }

  Future<void> _closePositionById(
    BuildContext context,
    PaperTradingProvider provider,
    String positionId,
  ) async {
    // CRITICAL: Capture TradeProvider reference BEFORE any async operations
    // to avoid "deactivated widget" errors when accessing context later
    final tradeProvider = context.read<TradeProvider>();

    JournalDebug.chartTrade(
      'CHART_CLOSE_BUTTON_PRESSED',
      positionId: positionId,
    );

    // Find position BEFORE closing - it will be removed from openPositions after close
    // Use try-catch to handle double-clicks gracefully
    PaperPosition? position;
    try {
      position = provider.openPositions.firstWhere((p) => p.id == positionId);
    } catch (e) {
      // Position not found - likely already closed (double-click)
      JournalDebug.chartTrade(
        'CHART_POSITION_ALREADY_CLOSED',
        positionId: positionId,
        error: 'Position not in openPositions (double-click?)',
      );
      return; // Gracefully exit
    }

    JournalDebug.chartTrade(
      'CHART_CLOSING_POSITION',
      positionId: positionId,
      symbol: position.symbol,
      userId: provider.userId,
    );

    final success = await provider.closePosition(positionId);

    if (success) {
      JournalDebug.chartTrade(
        'CHART_POSITION_CLOSED_SUCCESS',
        positionId: positionId,
      );

      // CRITICAL: Refresh trades list FIRST, before any UI operations
      // This ensures journal updates even if SnackBar fails
      JournalDebug.journalLoad(
        'CHART_TRIGGERING_JOURNAL_REFRESH',
        userId: provider.userId,
      );
      try {
        await tradeProvider
            .refresh(); // Use captured reference, not context.read()
        JournalDebug.journalLoad(
          'CHART_JOURNAL_REFRESH_COMPLETE',
          userId: provider.userId,
        );
      } catch (refreshError) {
        // Log but don't crash if refresh fails
        JournalDebug.journalLoad(
          'CHART_JOURNAL_REFRESH_ERROR',
          userId: provider.userId,
          error: refreshError.toString(),
        );
        Log.e('Failed to refresh journal after trade close', refreshError);
      }

      // Show success message (after refresh, and only if widget still mounted)
      if (mounted) {
        final pnl = position.realizedPnL ?? 0;
        _showSnackBar(
          context,
          'Closed ${position.symbol} | P&L: ${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} → Logged to Journal',
          pnl >= 0 ? AppColors.profit : AppColors.loss,
        );
      }
    } else {
      JournalDebug.chartTrade(
        'CHART_POSITION_CLOSE_FAILED',
        positionId: positionId,
        error: provider.error,
      );
    }
  }

  void _showResetDialog(BuildContext context, PaperTradingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Paper Account?'),
        content: const Text(
          'This will reset your balance to \$10,000 and clear all positions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.resetAccount();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnackBar(
                  context,
                  'Account reset to \$10,000',
                  AppColors.accent,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _AccountStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool compact;

  const _AccountStat(
    this.label,
    this.value, {
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final bool compact;

  const _QuantitySelector({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Qty:',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: compact ? 11 : 12,
          ),
        ),
        SizedBox(width: compact ? 4 : 8),
        ...[1.0, 5.0, 10.0, 25.0].map((q) {
          final isSelected = value == q;
          return Padding(
            padding: EdgeInsets.only(right: compact ? 3 : 4),
            child: GestureDetector(
              onTap: () => onChanged(q),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 10,
                  vertical: compact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  q.toInt().toString(),
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PercentInput extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final bool isLoss;
  final bool compact;

  const _PercentInput({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isLoss,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPercentPicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: value != null
              ? (isLoss ? AppColors.loss : AppColors.profit).withValues(
                  alpha: 0.1,
                )
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value != null
                ? (isLoss ? AppColors.loss : AppColors.profit).withValues(
                    alpha: 0.3,
                  )
                : AppColors.border,
          ),
        ),
        child: Text(
          value != null ? '${value!.toStringAsFixed(1)}%' : label,
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w600,
            color: value != null
                ? (isLoss ? AppColors.loss : AppColors.profit)
                : AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showPercentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _PercentOption('Off', null, value, onChanged, context),
                _PercentOption('1%', 1.0, value, onChanged, context),
                _PercentOption('2%', 2.0, value, onChanged, context),
                _PercentOption('3%', 3.0, value, onChanged, context),
                _PercentOption('5%', 5.0, value, onChanged, context),
                _PercentOption('10%', 10.0, value, onChanged, context),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PercentOption extends StatelessWidget {
  final String label;
  final double? optionValue;
  final double? currentValue;
  final ValueChanged<double?> onChanged;
  final BuildContext parentContext;

  const _PercentOption(
    this.label,
    this.optionValue,
    this.currentValue,
    this.onChanged,
    this.parentContext,
  );

  @override
  Widget build(BuildContext context) {
    final isSelected = optionValue == currentValue;
    return GestureDetector(
      onTap: () {
        onChanged(optionValue);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.background : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onPressed;

  const _TradeButton({
    required this.label,
    required this.sublabel,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed != null ? color : color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onPressed != null ? Colors.white : Colors.white54,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: onPressed != null ? Colors.white70 : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Symbol search bottom sheet
class _SymbolSearchSheet extends StatefulWidget {
  final MarketDataProvider provider;

  const _SymbolSearchSheet({required this.provider});

  @override
  State<_SymbolSearchSheet> createState() => _SymbolSearchSheetState();
}

class _SymbolSearchSheetState extends State<_SymbolSearchSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;

  static const _popularSymbols = [
    'AAPL',
    'GOOGL',
    'MSFT',
    'AMZN',
    'TSLA',
    'META',
    'NVDA',
    'JPM',
    'V',
    'WMT',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    final results = await widget.provider.searchSymbols(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  void _selectSymbol(String symbol) {
    widget.provider.setSymbol(symbol);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search symbols (e.g., AAPL, TSLA)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: _search,
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildPopularSymbols(scrollController)
                  : _buildSearchResults(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularSymbols(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Text(
          'Popular Symbols',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSymbols.map((symbol) {
            final isSelected = widget.provider.currentSymbol == symbol;
            return GestureDetector(
              onTap: () => _selectSymbol(symbol),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.background
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          onTap: () => _selectSymbol(result.symbol),
          title: Text(
            result.symbol,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            result.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              result.type,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drawing tools toolbar
class _DrawingToolbar extends StatelessWidget {
  final void Function(bool isLong)? onPositionToolTap;

  const _DrawingToolbar({this.onPositionToolTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartDrawingProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tool buttons
            _DrawingToolButton(
              icon: Icons.remove_rounded,
              label: 'Line',
              isSelected: provider.currentTool == DrawingToolType.trendLine,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.trendLine
                    ? DrawingToolType.none
                    : DrawingToolType.trendLine,
              ),
            ),
            _DrawingToolButton(
              icon: Icons.horizontal_rule_rounded,
              label: 'H-Line',
              isSelected:
                  provider.currentTool == DrawingToolType.horizontalLine,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.horizontalLine
                    ? DrawingToolType.none
                    : DrawingToolType.horizontalLine,
              ),
            ),
            _DrawingToolButton(
              icon: Icons.show_chart_rounded,
              label: 'Fib',
              isSelected:
                  provider.currentTool == DrawingToolType.fibonacciRetracement,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.fibonacciRetracement
                    ? DrawingToolType.none
                    : DrawingToolType.fibonacciRetracement,
              ),
            ),
            _DrawingToolButton(
              icon: Icons.crop_square_rounded,
              label: 'Rect',
              isSelected: provider.currentTool == DrawingToolType.rectangle,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.rectangle
                    ? DrawingToolType.none
                    : DrawingToolType.rectangle,
              ),
            ),

            // Position tools separator
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.border,
            ),

            // Long Position tool - opens settings sheet on long press, direct select on tap
            _DrawingToolButton(
              icon: Icons.trending_up_rounded,
              label: 'Long',
              isSelected: provider.currentTool == DrawingToolType.longPosition,
              color: AppColors.profit,
              onTap: () {
                if (provider.currentTool == DrawingToolType.longPosition) {
                  provider.setTool(DrawingToolType.none);
                } else {
                  // Show settings sheet before selecting tool
                  onPositionToolTap?.call(true);
                }
              },
              onLongPress: () => onPositionToolTap?.call(true),
            ),

            // Short Position tool - opens settings sheet on long press, direct select on tap
            _DrawingToolButton(
              icon: Icons.trending_down_rounded,
              label: 'Short',
              isSelected: provider.currentTool == DrawingToolType.shortPosition,
              color: AppColors.loss,
              onTap: () {
                if (provider.currentTool == DrawingToolType.shortPosition) {
                  provider.setTool(DrawingToolType.none);
                } else {
                  // Show settings sheet before selecting tool
                  onPositionToolTap?.call(false);
                }
              },
              onLongPress: () => onPositionToolTap?.call(false),
            ),

            // Separator
            if (provider.drawings.isNotEmpty) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.border,
              ),
              // Clear all button
              _DrawingToolButton(
                icon: Icons.delete_outline_rounded,
                label: 'Clear',
                isSelected: false,
                onTap: () => _showClearConfirmation(context, provider),
                color: AppColors.loss,
              ),
            ],
          ],
        );
      },
    );
  }

  void _showClearConfirmation(
    BuildContext context,
    ChartDrawingProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All Drawings?'),
        content: Text(
          'This will remove all ${provider.drawings.length} drawings from the chart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

/// Mobile-friendly drawing tools menu (popup menu button)
class _MobileDrawingToolsMenu extends StatelessWidget {
  final VoidCallback onShowPositionCalc;
  final void Function(bool isLong)? onPositionToolTap;

  const _MobileDrawingToolsMenu({
    required this.onShowPositionCalc,
    this.onPositionToolTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartDrawingProvider>(
      builder: (context, provider, _) {
        final hasActiveTool = provider.currentTool != DrawingToolType.none;

        return PopupMenuButton<String>(
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.surface,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasActiveTool
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasActiveTool ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Icon(
              Icons.edit_rounded,
              size: 16,
              color: hasActiveTool ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          itemBuilder: (context) => [
            // Drawing tools section
            PopupMenuItem(
              enabled: false,
              height: 30,
              child: Text(
                'DRAWING TOOLS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
            ),
            _buildToolItem(
              context,
              provider,
              'line',
              Icons.remove_rounded,
              'Trend Line',
              DrawingToolType.trendLine,
            ),
            _buildToolItem(
              context,
              provider,
              'hline',
              Icons.horizontal_rule_rounded,
              'Horizontal Line',
              DrawingToolType.horizontalLine,
            ),
            _buildToolItem(
              context,
              provider,
              'rect',
              Icons.crop_square_rounded,
              'Rectangle',
              DrawingToolType.rectangle,
            ),
            _buildToolItem(
              context,
              provider,
              'fib',
              Icons.show_chart_rounded,
              'Fibonacci',
              DrawingToolType.fibonacciRetracement,
            ),
            const PopupMenuDivider(),
            // Position tools section
            PopupMenuItem(
              enabled: false,
              height: 30,
              child: Text(
                'POSITION TOOLS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'long',
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.profit,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Long Position',
                    style: TextStyle(color: AppColors.profit),
                  ),
                  const Spacer(),
                  if (provider.currentTool == DrawingToolType.longPosition)
                    Icon(
                      Icons.check_rounded,
                      color: AppColors.profit,
                      size: 16,
                    ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'short',
              child: Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    color: AppColors.loss,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Short Position',
                    style: TextStyle(color: AppColors.loss),
                  ),
                  const Spacer(),
                  if (provider.currentTool == DrawingToolType.shortPosition)
                    Icon(Icons.check_rounded, color: AppColors.loss, size: 16),
                ],
              ),
            ),
            const PopupMenuDivider(),
            // Utilities section
            PopupMenuItem<String>(
              value: 'calc',
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Position Calculator'),
                ],
              ),
            ),
            if (provider.drawings.isNotEmpty)
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.loss,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Clear All (${provider.drawings.length})',
                      style: TextStyle(color: AppColors.loss),
                    ),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'line':
                provider.setTool(
                  provider.currentTool == DrawingToolType.trendLine
                      ? DrawingToolType.none
                      : DrawingToolType.trendLine,
                );
                break;
              case 'hline':
                provider.setTool(
                  provider.currentTool == DrawingToolType.horizontalLine
                      ? DrawingToolType.none
                      : DrawingToolType.horizontalLine,
                );
                break;
              case 'rect':
                provider.setTool(
                  provider.currentTool == DrawingToolType.rectangle
                      ? DrawingToolType.none
                      : DrawingToolType.rectangle,
                );
                break;
              case 'fib':
                provider.setTool(
                  provider.currentTool == DrawingToolType.fibonacciRetracement
                      ? DrawingToolType.none
                      : DrawingToolType.fibonacciRetracement,
                );
                break;
              case 'long':
                if (provider.currentTool == DrawingToolType.longPosition) {
                  provider.setTool(DrawingToolType.none);
                } else {
                  onPositionToolTap?.call(true);
                }
                break;
              case 'short':
                if (provider.currentTool == DrawingToolType.shortPosition) {
                  provider.setTool(DrawingToolType.none);
                } else {
                  onPositionToolTap?.call(false);
                }
                break;
              case 'calc':
                onShowPositionCalc();
                break;
              case 'clear':
                _showClearConfirmation(context, provider);
                break;
            }
          },
        );
      },
    );
  }

  PopupMenuItem<String> _buildToolItem(
    BuildContext context,
    ChartDrawingProvider provider,
    String value,
    IconData icon,
    String label,
    DrawingToolType toolType,
  ) {
    final isSelected = provider.currentTool == toolType;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check_rounded, color: AppColors.accent, size: 16),
        ],
      ),
    );
  }

  void _showClearConfirmation(
    BuildContext context,
    ChartDrawingProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All Drawings?'),
        content: Text(
          'This will remove all ${provider.drawings.length} drawings from the chart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAll();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _PositionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color color;

  const _PositionDetailRow({
    required this.label,
    required this.value,
    this.subValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue!,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  const _DrawingToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                color ??
                (isSelected ? AppColors.accent : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Left sidebar button
class _LeftSidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool small;

  const _LeftSidebarButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: small ? 28 : 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: small ? 16 : 20,
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// RSI Panel - Separate oscillator panel below the main chart
class _RsiPanel extends StatelessWidget {
  final List<dynamic> candles;

  const _RsiPanel({required this.candles});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        children: [
          // RSI chart
          CustomPaint(
            size: const Size(double.infinity, 100),
            painter: _RsiPainter(candles: candles, period: 14),
          ),

          // Label
          Positioned(
            top: 4,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RSI (14)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ),

          // Level lines
          Positioned(
            right: 8,
            top: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RsiLevelLabel('70', const Color(0xFFE91E63)),
                const SizedBox(height: 24),
                _RsiLevelLabel('50', AppColors.textSecondary),
                const SizedBox(height: 24),
                _RsiLevelLabel('30', AppColors.profit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RsiLevelLabel extends StatelessWidget {
  final String level;
  final Color color;

  const _RsiLevelLabel(this.level, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      level,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
    );
  }
}

/// RSI Painter
class _RsiPainter extends CustomPainter {
  final List<dynamic> candles;
  final int period;

  _RsiPainter({required this.candles, this.period = 14});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.length < period + 1) return;

    // Calculate RSI values
    final rsiValues = _calculateRsi();
    if (rsiValues.isEmpty) return;

    final chartWidth = size.width - 40; // Reserve space for labels
    final chartHeight = size.height - 10;

    // Draw overbought/oversold zones
    final zonePaint = Paint()..style = PaintingStyle.fill;

    // Overbought zone (70-100)
    zonePaint.color = const Color(0xFFE91E63).withValues(alpha: 0.1);
    canvas.drawRect(
      Rect.fromLTRB(0, 0, chartWidth, chartHeight * 0.3),
      zonePaint,
    );

    // Oversold zone (0-30)
    zonePaint.color = AppColors.profit.withValues(alpha: 0.1);
    canvas.drawRect(
      Rect.fromLTRB(0, chartHeight * 0.7, chartWidth, chartHeight),
      zonePaint,
    );

    // Draw level lines
    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    // 70 line
    canvas.drawLine(
      Offset(0, chartHeight * 0.3),
      Offset(chartWidth, chartHeight * 0.3),
      linePaint,
    );

    // 50 line
    canvas.drawLine(
      Offset(0, chartHeight * 0.5),
      Offset(chartWidth, chartHeight * 0.5),
      linePaint,
    );

    // 30 line
    canvas.drawLine(
      Offset(0, chartHeight * 0.7),
      Offset(chartWidth, chartHeight * 0.7),
      linePaint,
    );

    // Draw RSI line
    final rsiPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool started = false;

    final step = chartWidth / rsiValues.length;

    for (int i = 0; i < rsiValues.length; i++) {
      final rsi = rsiValues[i];
      if (rsi == null) continue;

      final x = i * step;
      final y = chartHeight - (rsi / 100) * chartHeight;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, rsiPaint);

    // Draw current RSI value
    final lastRsi = rsiValues.lastWhere((r) => r != null, orElse: () => null);
    if (lastRsi != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: lastRsi.toStringAsFixed(1),
          style: TextStyle(
            color: lastRsi > 70
                ? const Color(0xFFE91E63)
                : lastRsi < 30
                ? AppColors.profit
                : AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(chartWidth + 4, chartHeight - (lastRsi / 100) * chartHeight - 6),
      );
    }
  }

  List<double?> _calculateRsi() {
    if (candles.length < period + 1) return [];

    final rsiValues = List<double?>.filled(candles.length, null);
    final gains = <double>[];
    final losses = <double>[];

    // Calculate initial gains and losses
    for (int i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change > 0) {
        gains.add(change);
        losses.add(0);
      } else {
        gains.add(0);
        losses.add(-change);
      }
    }

    double avgGain = gains.reduce((a, b) => a + b) / period;
    double avgLoss = losses.reduce((a, b) => a + b) / period;

    // First RSI value
    if (avgLoss == 0) {
      rsiValues[period] = 100;
    } else {
      final rs = avgGain / avgLoss;
      rsiValues[period] = 100 - (100 / (1 + rs));
    }

    // Calculate remaining RSI values using smoothed averages
    for (int i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final currentGain = change > 0 ? change : 0.0;
      final currentLoss = change < 0 ? -change : 0.0;

      avgGain = ((avgGain * (period - 1)) + currentGain) / period;
      avgLoss = ((avgLoss * (period - 1)) + currentLoss) / period;

      if (avgLoss == 0) {
        rsiValues[i] = 100;
      } else {
        final rs = avgGain / avgLoss;
        rsiValues[i] = 100 - (100 / (1 + rs));
      }
    }

    return rsiValues;
  }

  @override
  bool shouldRepaint(covariant _RsiPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.period != period;
  }
}

/// Replay Mode Controls
///
/// Features:
/// - Live/Replay toggle
/// - Timeline slider to scrub through history
/// - Play/Pause controls
/// - Playback speed selector
class _ReplayControls extends StatelessWidget {
  final MarketDataProvider provider;

  const _ReplayControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isReplay = provider.isReplayMode;
    final (startTime, endTime) = provider.getTimeRange();

    // Don't show if no data available
    if (startTime == null || endTime == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // Live/Replay toggle
          _buildModeToggle(isReplay),

          const SizedBox(width: 12),

          // Timeline slider (only in replay mode)
          if (isReplay) ...[
            // Play/Pause button
            _buildPlayPauseButton(),

            const SizedBox(width: 8),

            // Timeline slider
            Expanded(child: _buildTimelineSlider(startTime, endTime)),

            const SizedBox(width: 8),

            // Current time display
            _buildTimeDisplay(),

            const SizedBox(width: 8),

            // Speed selector
            _buildSpeedSelector(),
          ] else ...[
            // In live mode, show "Live" indicator
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.profit,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.profit.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Data',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeToggle(bool isReplay) {
    return GestureDetector(
      onTap: () {
        if (isReplay) {
          provider.exitReplayMode();
        } else {
          provider.enterReplayMode();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isReplay
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isReplay ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReplay ? Icons.history_rounded : Icons.live_tv_rounded,
              size: 16,
              color: isReplay ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isReplay ? 'REPLAY' : 'LIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isReplay ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    final isPlaying = provider.isPlaying;

    return GestureDetector(
      onTap: () {
        if (isPlaying) {
          provider.pauseReplay();
        } else {
          provider.playReplay();
        }
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTimelineSlider(DateTime startTime, DateTime endTime) {
    final cursorTime = provider.replayCursorTime ?? startTime;
    final totalDuration = endTime.difference(startTime).inSeconds.toDouble();
    final currentPosition = cursorTime
        .difference(startTime)
        .inSeconds
        .toDouble();

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: currentPosition.clamp(0, totalDuration),
        min: 0,
        max: totalDuration > 0 ? totalDuration : 1,
        onChanged: (value) {
          final newTime = startTime.add(Duration(seconds: value.toInt()));
          provider.setReplayCursor(newTime);
        },
      ),
    );
  }

  Widget _buildTimeDisplay() {
    final cursorTime = provider.replayCursorTime;
    if (cursorTime == null) return const SizedBox.shrink();

    final timeStr =
        '${cursorTime.month}/${cursorTime.day} ${cursorTime.hour.toString().padLeft(2, '0')}:${cursorTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        timeStr,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return PopupMenuButton<double>(
      initialValue: 1.0,
      onSelected: (speed) {
        // provider.setPlaybackSpeed(speed); // TODO: Add to provider
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0.5, child: Text('0.5x')),
        const PopupMenuItem(value: 1.0, child: Text('1x')),
        const PopupMenuItem(value: 2.0, child: Text('2x')),
        const PopupMenuItem(value: 5.0, child: Text('5x')),
        const PopupMenuItem(value: 10.0, child: Text('10x')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1x',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Position Tool Settings Sheet
/// Allows user to configure RR ratio, SL%, and quantity BEFORE placing the tool
class _PositionToolSettingsSheet extends StatefulWidget {
  final bool isLong;
  final double initialSlPercent;
  final double initialRrRatio;
  final double initialQuantity;
  final void Function(double slPercent, double rrRatio, double quantity)
  onConfirm;

  const _PositionToolSettingsSheet({
    required this.isLong,
    required this.initialSlPercent,
    required this.initialRrRatio,
    required this.initialQuantity,
    required this.onConfirm,
  });

  @override
  State<_PositionToolSettingsSheet> createState() =>
      _PositionToolSettingsSheetState();
}

class _PositionToolSettingsSheetState
    extends State<_PositionToolSettingsSheet> {
  late double _slPercent;
  late double _rrRatio;
  late double _quantity;

  // Common presets
  static const _slPresets = [1.0, 2.0, 3.0, 5.0];
  static const _rrPresets = [1.0, 1.5, 2.0, 3.0, 5.0];
  static const _qtyPresets = [1.0, 5.0, 10.0, 25.0, 100.0];

  @override
  void initState() {
    super.initState();
    _slPercent = widget.initialSlPercent;
    _rrRatio = widget.initialRrRatio;
    _quantity = widget.initialQuantity;
  }

  double get _tpPercent => _slPercent * _rrRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (widget.isLong ? AppColors.profit : AppColors.loss)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isLong
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: widget.isLong ? AppColors.profit : AppColors.loss,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.isLong ? "Long" : "Short"} Position Settings',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Set risk parameters before placing',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stop Loss Section
          const Text(
            'Stop Loss Distance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slPresets.map((sl) {
              final isSelected = _slPercent == sl;
              return GestureDetector(
                onTap: () => setState(() => _slPercent = sl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.loss.withValues(alpha: 0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.loss : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '${sl.toStringAsFixed(sl == sl.toInt() ? 0 : 1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.loss
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Risk:Reward Ratio Section
          const Text(
            'Risk : Reward Ratio',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _rrPresets.map((rr) {
              final isSelected = _rrRatio == rr;
              return GestureDetector(
                onTap: () => setState(() => _rrRatio = rr),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '1:${rr.toStringAsFixed(rr == rr.toInt() ? 0 : 1)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Quantity Section
          const Text(
            'Quantity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _qtyPresets.map((qty) {
              final isSelected = _quantity == qty;
              return GestureDetector(
                onTap: () => setState(() => _quantity = qty),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    qty.toInt().toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  label: 'Stop Loss',
                  value: '${_slPercent.toStringAsFixed(1)}%',
                  color: AppColors.loss,
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                _SummaryItem(
                  label: 'Take Profit',
                  value: '${_tpPercent.toStringAsFixed(1)}%',
                  color: AppColors.profit,
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                _SummaryItem(
                  label: 'R:R',
                  value: '1:${_rrRatio.toStringAsFixed(1)}',
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_slPercent, _rrRatio, _quantity);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isLong
                    ? AppColors.profit
                    : AppColors.loss,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isLong
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Place ${widget.isLong ? "Long" : "Short"} Position',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

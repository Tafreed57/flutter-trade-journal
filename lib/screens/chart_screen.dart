import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/logger.dart';
import '../models/chart_drawing.dart';
import '../models/chart_marker.dart';
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
    ChartIndicator(name: 'EMA', period: 9, color: const Color(0xFFFFD700), enabled: false),
    ChartIndicator(name: 'EMA', period: 21, color: const Color(0xFF00BFFF), enabled: false),
    ChartIndicator(name: 'SMA', period: 50, color: const Color(0xFFFF69B4), enabled: false),
    ChartIndicator(name: 'SMA', period: 200, color: const Color(0xFF9370DB), enabled: false),
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
        Log.d('ChartScreen: Removing position tool $toolId after position closed');
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
                    Text('Loading market data...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            
            // Sync price to paper trading provider
            if (provider.lastPrice != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.read<PaperTradingProvider>().updatePrice(provider.lastPrice!);
                }
              });
            }
            
            return Row(
              children: [
                // Left sidebar with tools
                _buildLeftSidebar(),
                
                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Header bar
                      _buildHeader(provider),
                      
                      // OHLC stats + timeframes
                      _buildStatsAndTimeframes(provider),
                      
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
                      
                      // Trading panel
                      const _TradingPanel(),
                    ],
                  ),
                ),
                
                // Position size calculator panel (right side when open)
                if (_showLeftPanel)
                  _buildPositionSizePanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildApiNotConfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.key_rounded,
                size: 40,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'API Key Required',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'To view live charts, you need to add your Finnhub API key.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Get a free key at finnhub.io',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '2. Create a .env file in project root',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FINNHUB_API_KEY=your_key_here',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.accent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '3. Restart the app',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MarketDataProvider provider) {
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Symbol selector
          GestureDetector(
            onTap: () => _showSymbolSearch(context, provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Price display
          if (price != null) ...[
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (change != null) ...[
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
          
          // Drawing tools
          const _DrawingToolbar(),
          
          const SizedBox(width: 8),
          
          // Mock mode indicator
          if (provider.isMockMode)
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
          
          const SizedBox(width: 8),
          
          // Chart settings button
          GestureDetector(
            onTap: () => _showChartSettings(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Connection status
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              provider.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: provider.isConnected ? AppColors.profit : AppColors.loss,
              size: 18,
            ),
          ),
        ],
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                const Icon(Icons.calculate_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Position Size Calculator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
          const Expanded(
            child: PositionSizeCalculator(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndTimeframes(MarketDataProvider provider) {
    final candles = provider.candles;
    final lastCandle = candles.isNotEmpty ? candles.last : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // OHLC stats
          if (lastCandle != null) ...[
            _StatChip('O', lastCandle.open.toStringAsFixed(2)),
            _StatChip('H', lastCandle.high.toStringAsFixed(2), color: AppColors.profit),
            _StatChip('L', lastCandle.low.toStringAsFixed(2), color: AppColors.loss),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      color: isSelected ? AppColors.background : AppColors.textSecondary,
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
            Text('Loading chart...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (provider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.loss),
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
    final drawingProvider = Provider.of<ChartDrawingProvider>(context, listen: false);
    final paperProvider = Provider.of<PaperTradingProvider>(context, listen: false);
    
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
                        tool.isLong ? Icons.trending_up_rounded : Icons.trending_down_rounded,
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
                  subValue: '+\$${tool.rewardPerShare.toStringAsFixed(2)}/share',
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
                      onPressed: () {
                        // Create actual position with linked tool ID
                        final positionId = paperProvider.openPositionFromTool(
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
                          drawingProvider.activatePositionTool(tool.id, positionId);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${tool.isLong ? "Long" : "Short"} position opened!'),
                              backgroundColor: tool.isLong ? AppColors.profit : AppColors.loss,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(paperProvider.error ?? 'Failed to open position'),
                              backgroundColor: AppColors.loss,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Activate Position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tool.isLong ? AppColors.profit : AppColors.loss,
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
                      onPressed: () {
                        if (tool.linkedPositionId != null) {
                          final success = paperProvider.closePosition(tool.linkedPositionId!);
                          if (success) {
                            final result = paperProvider.getClosedPositionResult(tool.linkedPositionId!);
                            if (result != null) {
                              drawingProvider.closePositionTool(
                                tool.id,
                                result.exitPrice,
                                result.pnl,
                              );
                            }
                            Navigator.pop(context);
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
                      color: ((tool.realizedPnL ?? 0) >= 0 ? AppColors.profit : AppColors.loss)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ((tool.realizedPnL ?? 0) >= 0 ? AppColors.profit : AppColors.loss)
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.loss,
                  ),
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

  const _StatChip(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
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
  const _TradingPanel();

  @override
  State<_TradingPanel> createState() => _TradingPanelState();
}

class _TradingPanelState extends State<_TradingPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _quantity = 1.0;
  double? _stopLossPercent;
  double? _takeProfitPercent;

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

  @override
  Widget build(BuildContext context) {
    return Consumer2<PaperTradingProvider, MarketDataProvider>(
      builder: (context, paperProvider, marketProvider, _) {
        final currentPrice = paperProvider.getCurrentPrice(marketProvider.currentSymbol);
        final openPositions = paperProvider.openPositions
            .where((p) => p.symbol == marketProvider.currentSymbol)
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account summary bar
              _buildAccountBar(paperProvider),
              
              // Tabs
              Container(
                height: 36,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 2,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Order${openPositions.isNotEmpty ? ' (${openPositions.length})' : ''}'),
                    const Tab(text: 'Positions'),
                  ],
                ),
              ),
              
              // Tab content
              SizedBox(
                height: 140,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderTab(paperProvider, marketProvider, currentPrice),
                    _buildPositionsTab(paperProvider, marketProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountBar(PaperTradingProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _AccountStat('Balance', '\$${provider.balance.toStringAsFixed(2)}'),
          _AccountStat(
            'Unrealized',
            '${provider.unrealizedPnL >= 0 ? '+' : ''}\$${provider.unrealizedPnL.toStringAsFixed(2)}',
            color: provider.unrealizedPnL >= 0 ? AppColors.profit : AppColors.loss,
          ),
          _AccountStat(
            'Realized',
            '${provider.realizedPnL >= 0 ? '+' : ''}\$${provider.realizedPnL.toStringAsFixed(2)}',
            color: provider.realizedPnL >= 0 ? AppColors.profit : AppColors.loss,
          ),
          const Spacer(),
          // Reset button
          IconButton(
            onPressed: () => _showResetDialog(context, provider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Reset Account',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab(
    PaperTradingProvider paperProvider,
    MarketDataProvider marketProvider,
    double? currentPrice,
  ) {
    final symbol = marketProvider.currentSymbol;
    final hasPosition = paperProvider.hasPositionFor(symbol);
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Quantity and SL/TP row
          Row(
            children: [
              // Quantity selector
              Expanded(
                child: _QuantitySelector(
                  value: _quantity,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ),
              const SizedBox(width: 8),
              // SL input
              SizedBox(
                width: 70,
                child: _PercentInput(
                  label: 'SL %',
                  value: _stopLossPercent,
                  onChanged: (v) => setState(() => _stopLossPercent = v),
                  isLoss: true,
                ),
              ),
              const SizedBox(width: 8),
              // TP input
              SizedBox(
                width: 70,
                child: _PercentInput(
                  label: 'TP %',
                  value: _takeProfitPercent,
                  onChanged: (v) => setState(() => _takeProfitPercent = v),
                  isLoss: false,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Buy/Sell buttons
          Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'BUY',
                  sublabel: currentPrice != null ? '\$${currentPrice.toStringAsFixed(2)}' : '--',
                  color: AppColors.profit,
                  onPressed: currentPrice != null ? () => _placeTrade(
                    context, paperProvider, symbol, currentPrice, true,
                  ) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TradeButton(
                  label: hasPosition ? 'CLOSE' : 'SELL',
                  sublabel: currentPrice != null ? '\$${currentPrice.toStringAsFixed(2)}' : '--',
                  color: AppColors.loss,
                  onPressed: currentPrice != null ? () {
                    if (hasPosition) {
                      _closePosition(context, paperProvider, symbol);
                    } else {
                      _placeTrade(context, paperProvider, symbol, currentPrice, false);
                    }
                  } : null,
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
    MarketDataProvider marketProvider,
  ) {
    final positions = paperProvider.openPositions;
    
    if (positions.isEmpty) {
      return const Center(
        child: Text(
          'No open positions',
          style: TextStyle(color: AppColors.textSecondary),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                              color: position.isLong ? AppColors.profit : AppColors.loss,
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
                      color: unrealizedPnL >= 0 ? AppColors.profit : AppColors.loss,
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
                onPressed: () => _closePositionById(context, paperProvider, position.id),
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

  void _placeTrade(
    BuildContext context,
    PaperTradingProvider provider,
    String symbol,
    double price,
    bool isBuy,
  ) {
    // Set SL/TP if configured
    provider.setStopLossPercent(_stopLossPercent);
    provider.setTakeProfitPercent(_takeProfitPercent);
    provider.setOrderQuantity(_quantity);
    
    final success = isBuy 
        ? provider.buy(symbol, price)
        : provider.sell(symbol, price);
    
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

  void _closePosition(BuildContext context, PaperTradingProvider provider, String symbol) {
    final position = provider.getPositionForSymbol(symbol);
    if (position != null) {
      _closePositionById(context, provider, position.id);
    }
  }

  void _closePositionById(BuildContext context, PaperTradingProvider provider, String positionId) {
    final position = provider.openPositions.firstWhere((p) => p.id == positionId);
    final success = provider.closePosition(positionId);
    
    if (success) {
      final pnl = position.realizedPnL ?? 0;
      _showSnackBar(
        context,
        'Closed ${position.symbol} | P&L: ${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} → Logged to Journal',
        pnl >= 0 ? AppColors.profit : AppColors.loss,
      );
      
      // Refresh trades list
      context.read<TradeProvider>().refresh();
    }
  }

  void _showResetDialog(BuildContext context, PaperTradingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Paper Account?'),
        content: const Text('This will reset your balance to \$10,000 and clear all positions.'),
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
                _showSnackBar(context, 'Account reset to \$10,000', AppColors.accent);
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

  const _AccountStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
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

class _QuantitySelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _QuantitySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Qty:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(width: 8),
        ...[ 1.0, 5.0, 10.0, 25.0].map((q) {
          final isSelected = value == q;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onChanged(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.background : AppColors.textSecondary,
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

  const _PercentInput({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isLoss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPercentPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: value != null 
              ? (isLoss ? AppColors.loss : AppColors.profit).withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value != null
                ? (isLoss ? AppColors.loss : AppColors.profit).withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Text(
          value != null ? '${value!.toStringAsFixed(1)}%' : label,
          style: TextStyle(
            fontSize: 12,
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
    'AAPL', 'GOOGL', 'MSFT', 'AMZN', 'TSLA',
    'META', 'NVDA', 'JPM', 'V', 'WMT',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    color: isSelected ? AppColors.background : AppColors.textPrimary,
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
  const _DrawingToolbar();

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
              isSelected: provider.currentTool == DrawingToolType.horizontalLine,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.horizontalLine
                    ? DrawingToolType.none
                    : DrawingToolType.horizontalLine,
              ),
            ),
            _DrawingToolButton(
              icon: Icons.show_chart_rounded,
              label: 'Fib',
              isSelected: provider.currentTool == DrawingToolType.fibonacciRetracement,
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
            
            // Long Position tool
            _DrawingToolButton(
              icon: Icons.trending_up_rounded,
              label: 'Long',
              isSelected: provider.currentTool == DrawingToolType.longPosition,
              color: AppColors.profit,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.longPosition
                    ? DrawingToolType.none
                    : DrawingToolType.longPosition,
              ),
            ),
            
            // Short Position tool
            _DrawingToolButton(
              icon: Icons.trending_down_rounded,
              label: 'Short',
              isSelected: provider.currentTool == DrawingToolType.shortPosition,
              color: AppColors.loss,
              onTap: () => provider.setTool(
                provider.currentTool == DrawingToolType.shortPosition
                    ? DrawingToolType.none
                    : DrawingToolType.shortPosition,
              ),
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

  void _showClearConfirmation(BuildContext context, ChartDrawingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All Drawings?'),
        content: Text('This will remove all ${provider.drawings.length} drawings from the chart.'),
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

  const _StatCard({
    required this.label,
    required this.value,
    this.color,
  });

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
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
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
  final Color? color;

  const _DrawingToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
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
            color: color ?? (isSelected ? AppColors.accent : AppColors.textSecondary),
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
            painter: _RsiPainter(
              candles: candles,
              period: 14,
            ),
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
      style: TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w500,
      ),
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
    final zonePaint = Paint()
      ..style = PaintingStyle.fill;
    
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
            Expanded(
              child: _buildTimelineSlider(startTime, endTime),
            ),
            
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
    final currentPosition = cursorTime.difference(startTime).inSeconds.toDouble();
    
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
    
    final timeStr = '${cursorTime.month}/${cursorTime.day} ${cursorTime.hour.toString().padLeft(2, '0')}:${cursorTime.minute.toString().padLeft(2, '0')}';
    
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

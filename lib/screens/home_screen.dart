import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trade.dart';
import '../services/export_service.dart';
import '../state/trade_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/trade_card.dart';
import 'add_trade_screen.dart';
import 'trade_detail_screen.dart';

/// Main home screen displaying the trade list
///
/// Shows all trades with filtering, search, and quick stats.
/// Handles empty states and loading states gracefully.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context),

            // Quick stats bar
            _buildQuickStats(context),

            // Trade list
            Expanded(child: _buildTradeList(context)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trading Journal',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Consumer<TradeProvider>(
                  builder: (context, provider, _) {
                    final stats = provider.tradeStats;
                    return Text(
                      stats.total == 0
                          ? 'Start tracking your trades'
                          : '${stats.total} trade${stats.total == 1 ? '' : 's'} logged',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  },
                ),
              ],
            ),
          ),

          // Search toggle
          IconButton(
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<TradeProvider>().setSearchQuery('');
                }
              });
            },
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
          ),

          // Filter button
          Consumer<TradeProvider>(
            builder: (context, provider, _) {
              final hasFilters = provider.hasActiveFilters;
              return IconButton(
                onPressed: () => _showFilterSheet(context),
                icon: Stack(
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      color: AppColors.textSecondary,
                    ),
                    if (hasFilters)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // More options menu (export, etc.)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Export to CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.code_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Export to JSON'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Consumer<TradeProvider>(
      builder: (context, provider, _) {
        if (provider.allTrades.isEmpty) {
          return const SizedBox(height: 16);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              // Search bar (animated)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _showSearch ? 56 : 0,
                child: AnimatedOpacity(
                  opacity: _showSearch ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      provider.setSearchQuery(value);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search trades...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),

              if (_showSearch) const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatCard(
                    label: 'Win Rate',
                    value: '${provider.winRate.toStringAsFixed(1)}%',
                    valueColor: provider.winRate >= 50
                        ? AppColors.profit
                        : AppColors.loss,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Total P&L',
                    value: _formatCurrency(provider.totalPnL),
                    valueColor: provider.totalPnL >= 0
                        ? AppColors.profit
                        : AppColors.loss,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Trades',
                    value: provider.tradeStats.closed.toString(),
                    valueColor: AppColors.textPrimary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTradeList(BuildContext context) {
    return Consumer<TradeProvider>(
      builder: (context, provider, _) {
        // Loading state
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 16),
                Text(
                  'Loading trades...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        // Error state with retry
        if (provider.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.loss,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Trades',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error ?? 'Check your connection and try again',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Empty state
        if (provider.allTrades.isEmpty) {
          return EmptyState.noTrades(
            onAddTrade: () => _navigateToAddTrade(context),
          );
        }

        // No results from filtering
        if (provider.trades.isEmpty && provider.hasActiveFilters) {
          return EmptyState.noResults(
            onClearFilters: () => provider.clearFilters(),
          );
        }

        // Trade list
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: provider.trades.length,
          itemBuilder: (context, index) {
            final trade = provider.trades[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnimatedTradeCard(
                index: index,
                child: TradeCard(
                  trade: trade,
                  onTap: () => _showTradeDetails(context, trade),
                  onLongPress: () => _showTradeActions(context, trade),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton(
        onPressed: () => _navigateToAddTrade(context),
        elevation: 4,
        tooltip: 'Add Trade',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _navigateToAddTrade(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AddTradeScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
  }

  void _showTradeDetails(BuildContext context, Trade trade) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TradeDetailScreen(trade: trade)),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final trades = context.read<TradeProvider>().allTrades;

    if (trades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trades to export'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      String filePath;
      String fileType;

      if (action == 'export_csv') {
        filePath = await ExportService.exportToCSV(trades);
        fileType = 'CSV';
      } else if (action == 'export_json') {
        filePath = await ExportService.exportToJSON(trades);
        fileType = 'JSON';
      } else {
        return;
      }

      if (!context.mounted) return;

      // Show success with share option
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.profit,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '$fileType Export Complete',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${trades.length} trades exported',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                filePath,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Share.shareXFiles([XFile(filePath)]);
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.loss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTradeActions(BuildContext context, Trade trade) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Trade summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        trade.symbol,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (trade.isClosed)
                        Text(
                          _formatCurrency(trade.profitLoss ?? 0),
                          style: TextStyle(
                            color: (trade.profitLoss ?? 0) >= 0
                                ? AppColors.profit
                                : AppColors.loss,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),

                // Actions
                if (!trade.isClosed)
                  ListTile(
                    leading: const Icon(
                      Icons.close_rounded,
                      color: AppColors.warning,
                    ),
                    title: const Text('Close Trade'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCloseTradeDialog(context, trade);
                    },
                  ),

                ListTile(
                  leading: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.accent,
                  ),
                  title: const Text('Edit Trade'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddTradeScreen(editTrade: trade),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.loss,
                  ),
                  title: const Text('Delete Trade'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, trade);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Trade trade) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Trade?'),
          content: Text(
            'Are you sure you want to delete the ${trade.symbol} trade? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<TradeProvider>().deleteTrade(trade.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Trade deleted')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseTradeDialog(BuildContext context, Trade trade) {
    final exitPriceController = TextEditingController();
    DateTime exitDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Close Trade'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: exitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Exit Price',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exit Date'),
                    subtitle: Text(
                      '${exitDate.month}/${exitDate.day}/${exitDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: exitDate,
                        firstDate: trade.entryDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => exitDate = date);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final exitPrice = double.tryParse(exitPriceController.text);
                    if (exitPrice == null || exitPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid exit price'),
                        ),
                      );
                      return;
                    }

                    context.read<TradeProvider>().closeTrade(
                      trade.id,
                      exitPrice,
                      exitDate,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trade closed')),
                    );
                  },
                  child: const Text('Close Trade'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return _FilterSheet(scrollController: scrollController);
          },
        );
      },
    );
  }

  String _formatCurrency(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign\$${value.abs().toStringAsFixed(2)}';
  }
}

/// Animated wrapper for trade cards with staggered entrance
class _AnimatedTradeCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedTradeCard({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Quick stat card widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter sheet widget
class _FilterSheet extends StatelessWidget {
  final ScrollController scrollController;

  const _FilterSheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<TradeProvider>(
      builder: (context, provider, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
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
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (provider.hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      provider.clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Outcome filter
            Text('Outcome', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: provider.outcomeFilter == null,
                  onTap: () => provider.setOutcomeFilter(null),
                ),
                _FilterChip(
                  label: 'Wins',
                  selected: provider.outcomeFilter == TradeOutcome.win,
                  onTap: () => provider.setOutcomeFilter(TradeOutcome.win),
                  color: AppColors.profit,
                ),
                _FilterChip(
                  label: 'Losses',
                  selected: provider.outcomeFilter == TradeOutcome.loss,
                  onTap: () => provider.setOutcomeFilter(TradeOutcome.loss),
                  color: AppColors.loss,
                ),
                _FilterChip(
                  label: 'Open',
                  selected: provider.outcomeFilter == TradeOutcome.open,
                  onTap: () => provider.setOutcomeFilter(TradeOutcome.open),
                  color: AppColors.warning,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Symbol filter
            if (provider.allSymbols.isNotEmpty) ...[
              Text('Symbol', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: provider.symbolFilter == null,
                    onTap: () => provider.setSymbolFilter(null),
                  ),
                  ...provider.allSymbols.map(
                    (symbol) => _FilterChip(
                      label: symbol,
                      selected: provider.symbolFilter == symbol,
                      onTap: () => provider.setSymbolFilter(symbol),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Tags filter
            if (provider.allTags.isNotEmpty) ...[
              Text('Tags', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: provider.tagFilter == null,
                    onTap: () => provider.setTagFilter(null),
                  ),
                  ...provider.allTags.map(
                    (tag) => _FilterChip(
                      label: '#$tag',
                      selected: provider.tagFilter == tag,
                      onTap: () => provider.setTagFilter(tag),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? chipColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? chipColor : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

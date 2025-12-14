import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trade.dart';
import '../state/trade_provider.dart';
import '../theme/app_theme.dart';
import 'add_trade_screen.dart';

/// Trade detail screen showing full trade information
/// 
/// Features:
/// - Full trade details display
/// - P&L visualization
/// - Edit capability
/// - Delete with confirmation
class TradeDetailScreen extends StatelessWidget {
  final Trade trade;

  const TradeDetailScreen({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    // Get the latest version of the trade from provider
    final tradeProvider = context.watch<TradeProvider>();
    final currentTrade = tradeProvider.trades.firstWhere(
      (t) => t.id == trade.id,
      orElse: () => trade,
    );

    final pnl = currentTrade.profitLoss ?? 0;
    final pnlPercent = currentTrade.profitLossPercent ?? 0;
    final isProfit = pnl >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTrade.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Trade',
            onPressed: () => _editTrade(context, currentTrade),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Trade',
            onPressed: () => _confirmDelete(context, currentTrade),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card with P&L
            _buildHeroCard(currentTrade, pnl, pnlPercent, isProfit),
            const SizedBox(height: 24),

            // Trade details section
            _buildSection(
              'Trade Details',
              [
                _DetailRow('Symbol', currentTrade.symbol),
                _DetailRow(
                  'Side',
                  currentTrade.side == TradeSide.long ? 'LONG' : 'SHORT',
                  valueColor: currentTrade.side == TradeSide.long
                      ? AppColors.profit
                      : AppColors.loss,
                ),
                _DetailRow('Quantity', currentTrade.quantity.toString()),
                _DetailRow(
                  'Status',
                  currentTrade.isClosed ? 'Closed' : 'Open',
                  valueColor: currentTrade.isClosed
                      ? AppColors.textSecondary
                      : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Entry/Exit section
            _buildSection(
              'Entry / Exit',
              [
                _DetailRow(
                  'Entry Price',
                  '\$${currentTrade.entryPrice.toStringAsFixed(2)}',
                ),
                _DetailRow(
                  'Entry Date',
                  DateFormat('MMM d, yyyy • HH:mm').format(currentTrade.entryDate),
                ),
                if (currentTrade.exitPrice != null) ...[
                  _DetailRow(
                    'Exit Price',
                    '\$${currentTrade.exitPrice!.toStringAsFixed(2)}',
                  ),
                ],
                if (currentTrade.exitDate != null) ...[
                  _DetailRow(
                    'Exit Date',
                    DateFormat('MMM d, yyyy • HH:mm').format(currentTrade.exitDate!),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // P&L section (if closed)
            if (currentTrade.isClosed) ...[
              _buildSection(
                'Performance',
                [
                  _DetailRow(
                    'P&L',
                    '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                    valueColor: isProfit ? AppColors.profit : AppColors.loss,
                  ),
                  _DetailRow(
                    'P&L %',
                    '${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
                    valueColor: isProfit ? AppColors.profit : AppColors.loss,
                  ),
                  _DetailRow(
                    'Outcome',
                    currentTrade.outcome.name.toUpperCase(),
                    valueColor: _getOutcomeColor(currentTrade.outcome),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Tags section
            if (currentTrade.tags.isNotEmpty) ...[
              _buildTagsSection(currentTrade.tags),
              const SizedBox(height: 16),
            ],

            // Notes section
            if (currentTrade.notes != null && currentTrade.notes!.isNotEmpty) ...[
              _buildNotesSection(currentTrade.notes!),
              const SizedBox(height: 16),
            ],

            // Metadata section
            _buildSection(
              'Metadata',
              [
                _DetailRow(
                  'Created',
                  DateFormat('MMM d, yyyy • HH:mm').format(currentTrade.createdAt),
                ),
                _DetailRow(
                  'Last Updated',
                  DateFormat('MMM d, yyyy • HH:mm').format(currentTrade.updatedAt),
                ),
                _DetailRow('Trade ID', currentTrade.id, isMonospace: true),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(Trade trade, double pnl, double pnlPercent, bool isProfit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: trade.isClosed
              ? [
                  isProfit
                      ? AppColors.profit.withValues(alpha: 0.15)
                      : AppColors.loss.withValues(alpha: 0.15),
                  AppColors.surface,
                ]
              : [
                  AppColors.warning.withValues(alpha: 0.15),
                  AppColors.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trade.isClosed
              ? (isProfit ? AppColors.profit : AppColors.loss).withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Symbol and side badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                trade.symbol,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: trade.side == TradeSide.long
                      ? AppColors.profit.withValues(alpha: 0.15)
                      : AppColors.loss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trade.side == TradeSide.long ? 'LONG' : 'SHORT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: trade.side == TradeSide.long
                        ? AppColors.profit
                        : AppColors.loss,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // P&L display
          if (trade.isClosed) ...[
            Text(
              '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: isProfit ? AppColors.profit : AppColors.loss,
              ),
            ),
            Text(
              '${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 16,
                color: isProfit ? AppColors.profit : AppColors.loss,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Position Open',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
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

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTagsSection(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection(String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            notes,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _getOutcomeColor(TradeOutcome outcome) {
    switch (outcome) {
      case TradeOutcome.win:
        return AppColors.profit;
      case TradeOutcome.loss:
        return AppColors.loss;
      case TradeOutcome.breakeven:
        return AppColors.textSecondary;
      case TradeOutcome.open:
        return AppColors.warning;
    }
  }

  void _editTrade(BuildContext context, Trade trade) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTradeScreen(editTrade: trade),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Trade trade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Trade?'),
        content: Text(
          'Are you sure you want to delete this ${trade.symbol} trade? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TradeProvider>().deleteTrade(trade.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to list
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${trade.symbol} trade deleted'),
                  backgroundColor: AppColors.loss,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMonospace;

  const _DetailRow(
    this.label,
    this.value, {
    this.valueColor,
    this.isMonospace = false,
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
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


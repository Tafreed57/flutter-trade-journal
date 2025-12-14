import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';

/// Card widget displaying a trade summary
/// 
/// Shows key trade info: symbol, side, P&L, dates.
/// Tappable for navigation to trade details.
class TradeCard extends StatelessWidget {
  final Trade trade;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const TradeCard({
    super.key,
    required this.trade,
    this.onTap,
    this.onLongPress,
  });
  
  @override
  Widget build(BuildContext context) {
    final pnl = trade.profitLoss;
    final pnlPercent = trade.profitLossPercent;
    final isProfit = pnl != null && pnl > 0;
    final isLoss = pnl != null && pnl < 0;
    
    final pnlColor = isProfit 
        ? AppColors.profit 
        : isLoss 
            ? AppColors.loss 
            : AppColors.textSecondary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Symbol + Side badge + P&L
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Symbol
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          trade.symbol,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SideBadge(side: trade.side),
                      ],
                    ),
                  ),
                  
                  // P&L
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (trade.isClosed) ...[
                        Text(
                          _formatCurrency(pnl ?? 0),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: pnlColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (pnlPercent != null)
                          Text(
                            '${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: pnlColor,
                            ),
                          ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'OPEN',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Trade details row
              Row(
                children: [
                  _DetailChip(
                    icon: Icons.attach_money_rounded,
                    label: _formatPrice(trade.entryPrice),
                    tooltip: 'Entry price',
                  ),
                  if (trade.exitPrice != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    _DetailChip(
                      icon: Icons.attach_money_rounded,
                      label: _formatPrice(trade.exitPrice!),
                      tooltip: 'Exit price',
                    ),
                  ],
                  const SizedBox(width: 12),
                  _DetailChip(
                    icon: Icons.layers_rounded,
                    label: _formatQuantity(trade.quantity),
                    tooltip: 'Quantity',
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Bottom row: Date + Tags
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(trade.entryDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (trade.tags.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TagsRow(tags: trade.tags),
                    ),
                  ] else
                    const Spacer(),
                  
                  // Chevron hint
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final formatted = formatter.format(value.abs());
    return value >= 0 ? '+$formatted' : '-$formatted';
  }
  
  String _formatPrice(double price) {
    if (price >= 1000) {
      return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(price);
    } else if (price >= 1) {
      return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(price);
    } else {
      // For penny stocks or crypto with small values
      return '\$${price.toStringAsFixed(4)}';
    }
  }
  
  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

/// Badge showing trade side (LONG/SHORT)
class _SideBadge extends StatelessWidget {
  final TradeSide side;
  
  const _SideBadge({required this.side});
  
  @override
  Widget build(BuildContext context) {
    final isLong = side == TradeSide.long;
    final color = isLong ? AppColors.profit : AppColors.loss;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        isLong ? 'LONG' : 'SHORT',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Small detail chip with icon and label
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  
  const _DetailChip({
    required this.icon,
    required this.label,
    this.tooltip,
  });
  
  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

/// Row of tag chips
class _TagsRow extends StatelessWidget {
  final List<String> tags;
  
  const _TagsRow({required this.tags});
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.take(3).map((tag) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$tag',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/trade_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stats_card.dart';
import '../widgets/charts/equity_curve_chart.dart';
import '../widgets/charts/win_loss_pie_chart.dart';
import '../widgets/charts/pnl_by_symbol_chart.dart';
import '../widgets/charts/calendar_heatmap.dart';
import '../services/analytics_service.dart';

/// Analytics dashboard showing trading performance metrics and charts
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<TradeProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            if (provider.allTrades.isEmpty) {
              return _buildEmptyState(context);
            }

            final stats = provider.tradeStats;
            final avgWin = AnalyticsService.calculateAverageWin(provider.allTrades);
            final avgLoss = AnalyticsService.calculateAverageLoss(provider.allTrades);
            final largestWin = AnalyticsService.calculateLargestWin(provider.allTrades);
            final largestLoss = AnalyticsService.calculateLargestLoss(provider.allTrades);
            final pnlBySymbol = AnalyticsService.getPnLBySymbol(provider.allTrades);

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your trading performance overview',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                // Key Stats Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      StatsCard(
                        label: 'Total P&L',
                        value: _formatCurrency(provider.totalPnL),
                        icon: Icons.account_balance_wallet_rounded,
                        valueColor: provider.totalPnL >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                        iconColor: provider.totalPnL >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                      ),
                      StatsCard(
                        label: 'Win Rate',
                        value: '${provider.winRate.toStringAsFixed(1)}%',
                        icon: Icons.pie_chart_rounded,
                        valueColor: provider.winRate >= 50
                            ? AppColors.profit
                            : AppColors.loss,
                        iconColor: AppColors.accent,
                        subtitle: '${stats.wins}W / ${stats.losses}L',
                      ),
                      StatsCard(
                        label: 'Profit Factor',
                        value: provider.profitFactor == double.infinity
                            ? '∞'
                            : provider.profitFactor.toStringAsFixed(2),
                        icon: Icons.trending_up_rounded,
                        valueColor: provider.profitFactor >= 1
                            ? AppColors.profit
                            : AppColors.loss,
                        iconColor: AppColors.accent,
                        subtitle: 'Gross profit / loss',
                      ),
                      StatsCard(
                        label: 'Total Trades',
                        value: stats.total.toString(),
                        icon: Icons.bar_chart_rounded,
                        iconColor: AppColors.accent,
                        subtitle: '${stats.open} open',
                      ),
                    ],
                  ),
                ),

                // Equity Curve Section
                SliverToBoxAdapter(
                  child: _buildSection(
                    context,
                    title: 'Equity Curve',
                    subtitle: 'Cumulative P&L over time',
                    child: EquityCurveChart(
                      data: provider.equityCurve,
                      height: 220,
                    ),
                  ),
                ),

                // Win/Loss Distribution
                SliverToBoxAdapter(
                  child: _buildSection(
                    context,
                    title: 'Win/Loss Distribution',
                    child: WinLossPieChart(
                      wins: stats.wins,
                      losses: stats.losses,
                      breakeven: stats.breakeven,
                      size: 140,
                    ),
                  ),
                ),

                // Detailed Stats
                SliverToBoxAdapter(
                  child: _buildSection(
                    context,
                    title: 'Performance Metrics',
                    child: Column(
                      children: [
                        _buildMetricRow(
                          context,
                          'Average Win',
                          _formatCurrency(avgWin),
                          AppColors.profit,
                        ),
                        _buildMetricRow(
                          context,
                          'Average Loss',
                          _formatCurrency(avgLoss),
                          AppColors.loss,
                        ),
                        _buildMetricRow(
                          context,
                          'Largest Win',
                          _formatCurrency(largestWin),
                          AppColors.profit,
                        ),
                        _buildMetricRow(
                          context,
                          'Largest Loss',
                          _formatCurrency(largestLoss),
                          AppColors.loss,
                        ),
                        _buildMetricRow(
                          context,
                          'Risk/Reward',
                          provider.riskRewardRatio == double.infinity
                              ? '∞'
                              : '1:${provider.riskRewardRatio.toStringAsFixed(2)}',
                          AppColors.accent,
                        ),
                        _buildMetricRow(
                          context,
                          'Avg P&L/Trade',
                          _formatCurrency(provider.averagePnL),
                          provider.averagePnL >= 0
                              ? AppColors.profit
                              : AppColors.loss,
                        ),
                      ],
                    ),
                  ),
                ),

                // P&L by Symbol
                if (pnlBySymbol.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSection(
                      context,
                      title: 'P&L by Symbol',
                      subtitle: 'Performance breakdown',
                      child: PnLBySymbolChart(
                        pnlBySymbol: pnlBySymbol,
                        height: 200,
                      ),
                    ),
                  ),

                // Calendar Heatmap
                SliverToBoxAdapter(
                  child: _buildSection(
                    context,
                    title: 'Trading Activity',
                    subtitle: 'Last 12 weeks',
                    child: CalendarHeatmap(
                      trades: provider.allTrades,
                      weeksToShow: 12,
                    ),
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No analytics yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Start logging trades to see your performance metrics and charts.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign\$${value.toStringAsFixed(2)}';
  }
}


import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Horizontal bar chart showing P&L by symbol
class PnLBySymbolChart extends StatefulWidget {
  final Map<String, double> pnlBySymbol;
  final double height;

  const PnLBySymbolChart({
    super.key,
    required this.pnlBySymbol,
    this.height = 200,
  });

  @override
  State<PnLBySymbolChart> createState() => _PnLBySymbolChartState();
}

class _PnLBySymbolChartState extends State<PnLBySymbolChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.pnlBySymbol.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No symbol data yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Sort by absolute P&L value
    final sortedEntries = widget.pnlBySymbol.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    
    // Take top 8 symbols
    final displayEntries = sortedEntries.take(8).toList();
    
    final maxAbsValue = displayEntries
        .map((e) => e.value.abs())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: widget.height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAbsValue * 1.2,
          minY: -maxAbsValue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceLight,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final entry = displayEntries[group.x];
                return BarTooltipItem(
                  '${entry.key}\n',
                  const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: _formatCurrency(entry.value),
                      style: TextStyle(
                        color: entry.value >= 0
                            ? AppColors.profit
                            : AppColors.loss,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
            touchCallback: (event, response) {
              setState(() {
                if (response?.spot != null) {
                  _touchedIndex = response!.spot!.touchedBarGroupIndex;
                } else {
                  _touchedIndex = -1;
                }
              });
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        '\$0',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= displayEntries.length) {
                    return const SizedBox.shrink();
                  }
                  final isTouched = index == _touchedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      displayEntries[index].key,
                      style: TextStyle(
                        color: isTouched
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight:
                            isTouched ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAbsValue / 2,
            getDrawingHorizontalLine: (value) => FlLine(
              color: value == 0
                  ? AppColors.textTertiary.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
              strokeWidth: value == 0 ? 1.5 : 1,
              dashArray: value == 0 ? null : [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _buildBarGroups(displayEntries, maxAbsValue),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    List<MapEntry<String, double>> entries,
    double maxAbsValue,
  ) {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final pnl = entry.value.value;
      final isTouched = index == _touchedIndex;
      final color = pnl >= 0 ? AppColors.profit : AppColors.loss;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: pnl,
            color: color,
            width: isTouched ? 20 : 16,
            borderRadius: BorderRadius.vertical(
              top: pnl >= 0 ? const Radius.circular(4) : Radius.zero,
              bottom: pnl < 0 ? const Radius.circular(4) : Radius.zero,
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: pnl >= 0 ? maxAbsValue * 1.1 : -maxAbsValue * 1.1,
              color: AppColors.surfaceLight,
            ),
          ),
        ],
      );
    }).toList();
  }

  String _formatCurrency(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign\$${value.toStringAsFixed(2)}';
  }
}


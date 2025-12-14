import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';

/// Equity curve line chart showing cumulative P&L over time
class EquityCurveChart extends StatefulWidget {
  final List<EquityPoint> data;
  final double height;

  const EquityCurveChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  @override
  State<EquityCurveChart> createState() => _EquityCurveChartState();
}

class _EquityCurveChartState extends State<EquityCurveChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No closed trades yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final spots = _createSpots();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return SizedBox(
      height: widget.height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateInterval(minY, maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _formatYAxis(value),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _calculateXInterval(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= widget.data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(widget.data[index].date),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
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
          borderData: FlBorderData(show: false),
          minY: minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceLight,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  final point = widget.data[index];
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(point.date)}\n',
                    const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: _formatCurrency(point.equity),
                        style: TextStyle(
                          color: point.equity >= 0
                              ? AppColors.profit
                              : AppColors.loss,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              setState(() {
                if (response?.lineBarSpots != null &&
                    response!.lineBarSpots!.isNotEmpty) {
                  _touchedIndex = response.lineBarSpots!.first.x.toInt();
                } else {
                  _touchedIndex = null;
                }
              });
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: _getLineColor(),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isLast = index == spots.length - 1;
                  final isTouched = index == _touchedIndex;
                  return FlDotCirclePainter(
                    radius: isLast || isTouched ? 4 : 0,
                    color: _getLineColor(),
                    strokeWidth: 2,
                    strokeColor: AppColors.background,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getLineColor().withValues(alpha: 0.3),
                    _getLineColor().withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // Zero line
            LineChartBarData(
              spots: [
                FlSpot(0, 0),
                FlSpot(spots.length.toDouble() - 1, 0),
              ],
              isCurved: false,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              barWidth: 1,
              dotData: const FlDotData(show: false),
              dashArray: [4, 4],
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  List<FlSpot> _createSpots() {
    return widget.data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.equity);
    }).toList();
  }

  Color _getLineColor() {
    if (widget.data.isEmpty) return AppColors.accent;
    final lastEquity = widget.data.last.equity;
    return lastEquity >= 0 ? AppColors.profit : AppColors.loss;
  }

  double _calculateInterval(double min, double max) {
    final range = max - min;
    if (range <= 100) return 20;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    if (range <= 5000) return 1000;
    return 2000;
  }

  double _calculateXInterval() {
    final length = widget.data.length;
    if (length <= 5) return 1;
    if (length <= 10) return 2;
    if (length <= 20) return 4;
    return (length / 5).ceilToDouble();
  }

  String _formatYAxis(double value) {
    if (value.abs() >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  String _formatCurrency(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign\$${value.toStringAsFixed(2)}';
  }
}


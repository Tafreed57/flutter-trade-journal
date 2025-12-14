import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trade.dart';
import '../../theme/app_theme.dart';

/// Calendar heatmap showing trading activity and P&L by day
class CalendarHeatmap extends StatelessWidget {
  final List<Trade> trades;
  final int weeksToShow;

  const CalendarHeatmap({
    super.key,
    required this.trades,
    this.weeksToShow = 12,
  });

  @override
  Widget build(BuildContext context) {
    // Group trades by date and calculate daily P&L
    final dailyPnL = <DateTime, double>{};
    final dailyCount = <DateTime, int>{};

    for (final trade in trades.where((t) => t.isClosed)) {
      final date = DateTime(
        trade.exitDate!.year,
        trade.exitDate!.month,
        trade.exitDate!.day,
      );
      dailyPnL[date] = (dailyPnL[date] ?? 0) + (trade.profitLoss ?? 0);
      dailyCount[date] = (dailyCount[date] ?? 0) + 1;
    }

    // Generate weeks
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: weeksToShow * 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        _buildMonthLabels(startDate, weeksToShow),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            _buildDayLabels(),
            const SizedBox(width: 8),
            // Calendar grid
            Expanded(
              child: _buildCalendarGrid(
                startDate,
                weeksToShow,
                dailyPnL,
                dailyCount,
                context,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Legend
        _buildLegend(context),
      ],
    );
  }

  Widget _buildMonthLabels(DateTime startDate, int weeks) {
    final months = <Widget>[];
    DateTime currentDate = startDate;
    String? lastMonth;

    for (int week = 0; week < weeks; week++) {
      final monthStr = DateFormat('MMM').format(currentDate);
      if (monthStr != lastMonth) {
        months.add(
          Padding(
            padding: EdgeInsets.only(left: week == 0 ? 24 : 0),
            child: Text(
              monthStr,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
        );
        lastMonth = monthStr;
      }
      currentDate = currentDate.add(const Duration(days: 7));
    }

    return Row(mainAxisAlignment: MainAxisAlignment.start, children: months);
  }

  Widget _buildDayLabels() {
    const days = ['', 'M', '', 'W', '', 'F', ''];
    return Column(
      children: days
          .map(
            (day) => SizedBox(
              height: 14,
              child: Text(
                day,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(
    DateTime startDate,
    int weeks,
    Map<DateTime, double> dailyPnL,
    Map<DateTime, int> dailyCount,
    BuildContext context,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(weeks, (weekIndex) {
          final weekStart = startDate.add(Duration(days: weekIndex * 7));
          return Column(
            children: List.generate(7, (dayIndex) {
              final date = weekStart.add(Duration(days: dayIndex));
              final pnl = dailyPnL[DateTime(date.year, date.month, date.day)];
              final count =
                  dailyCount[DateTime(date.year, date.month, date.day)] ?? 0;

              return Padding(
                padding: const EdgeInsets.all(1.5),
                child: Tooltip(
                  message: pnl != null
                      ? '${DateFormat('MMM d').format(date)}\n$count trade${count > 1 ? 's' : ''}\n${_formatCurrency(pnl)}'
                      : DateFormat('MMM d').format(date),
                  child: _CalendarCell(date: date, pnl: pnl, tradeCount: count),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Less',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
        const SizedBox(width: 4),
        _LegendCell(color: AppColors.surfaceLight),
        _LegendCell(color: AppColors.loss.withValues(alpha: 0.4)),
        _LegendCell(color: AppColors.loss),
        _LegendCell(color: AppColors.profit.withValues(alpha: 0.4)),
        _LegendCell(color: AppColors.profit),
        const SizedBox(width: 4),
        const Text(
          'More',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign\$${value.toStringAsFixed(2)}';
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final double? pnl;
  final int tradeCount;

  const _CalendarCell({required this.date, this.pnl, required this.tradeCount});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(date);
    final isFuture = date.isAfter(DateTime.now());

    Color cellColor;
    if (isFuture || pnl == null) {
      cellColor = AppColors.surfaceLight;
    } else if (pnl! > 100) {
      cellColor = AppColors.profit;
    } else if (pnl! > 0) {
      cellColor = AppColors.profit.withValues(alpha: 0.4);
    } else if (pnl! < -100) {
      cellColor = AppColors.loss;
    } else if (pnl! < 0) {
      cellColor = AppColors.loss.withValues(alpha: 0.4);
    } else {
      cellColor = AppColors.textTertiary.withValues(alpha: 0.3);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(2),
        border: isToday
            ? Border.all(color: AppColors.accent, width: 1.5)
            : null,
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _LegendCell extends StatelessWidget {
  final Color color;

  const _LegendCell({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

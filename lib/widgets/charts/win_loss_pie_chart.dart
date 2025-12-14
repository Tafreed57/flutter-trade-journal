import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Pie chart showing win/loss distribution
class WinLossPieChart extends StatefulWidget {
  final int wins;
  final int losses;
  final int breakeven;
  final double size;

  const WinLossPieChart({
    super.key,
    required this.wins,
    required this.losses,
    this.breakeven = 0,
    this.size = 150,
  });

  @override
  State<WinLossPieChart> createState() => _WinLossPieChartState();
}

class _WinLossPieChartState extends State<WinLossPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.wins + widget.losses + widget.breakeven;
    
    if (total == 0) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text(
            'No trades',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pie chart
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: widget.size * 0.25,
              sections: _buildSections(total),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Legend
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem(
              color: AppColors.profit,
              label: 'Wins',
              value: widget.wins,
              percentage: (widget.wins / total * 100).toStringAsFixed(1),
              isHighlighted: _touchedIndex == 0,
            ),
            const SizedBox(height: 8),
            _LegendItem(
              color: AppColors.loss,
              label: 'Losses',
              value: widget.losses,
              percentage: (widget.losses / total * 100).toStringAsFixed(1),
              isHighlighted: _touchedIndex == 1,
            ),
            if (widget.breakeven > 0) ...[
              const SizedBox(height: 8),
              _LegendItem(
                color: AppColors.textTertiary,
                label: 'B/E',
                value: widget.breakeven,
                percentage: (widget.breakeven / total * 100).toStringAsFixed(1),
                isHighlighted: _touchedIndex == 2,
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(int total) {
    final sections = <PieChartSectionData>[];
    
    // Wins
    if (widget.wins > 0) {
      final isTouched = _touchedIndex == 0;
      sections.add(PieChartSectionData(
        value: widget.wins.toDouble(),
        title: isTouched ? '${widget.wins}' : '',
        color: AppColors.profit,
        radius: isTouched ? widget.size * 0.28 : widget.size * 0.22,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        badgeWidget: isTouched
            ? _Badge(
                color: AppColors.profit,
                text: '${(widget.wins / total * 100).toStringAsFixed(0)}%',
              )
            : null,
        badgePositionPercentageOffset: 1.2,
      ));
    }
    
    // Losses
    if (widget.losses > 0) {
      final isTouched = _touchedIndex == 1;
      sections.add(PieChartSectionData(
        value: widget.losses.toDouble(),
        title: isTouched ? '${widget.losses}' : '',
        color: AppColors.loss,
        radius: isTouched ? widget.size * 0.28 : widget.size * 0.22,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ));
    }
    
    // Breakeven
    if (widget.breakeven > 0) {
      final isTouched = _touchedIndex == 2;
      sections.add(PieChartSectionData(
        value: widget.breakeven.toDouble(),
        title: isTouched ? '${widget.breakeven}' : '',
        color: AppColors.textTertiary,
        radius: isTouched ? widget.size * 0.28 : widget.size * 0.22,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ));
    }
    
    return sections;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final String percentage;
  final bool isHighlighted;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? color : AppColors.textSecondary,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value ($percentage%)',
            style: TextStyle(
              color: isHighlighted ? color : AppColors.textTertiary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final String text;

  const _Badge({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}


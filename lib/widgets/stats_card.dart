import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated stat card for displaying key metrics
class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? valueColor;
  final Color? iconColor;
  final bool animate;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.valueColor,
    this.iconColor,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.accent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          animate
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    return Opacity(
                      opacity: animValue,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - animValue)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildValue(context),
                )
              : _buildValue(context),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValue(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: valueColor ?? AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Compact inline stat for horizontal layouts
class InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InlineStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


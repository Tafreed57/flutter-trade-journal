import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable empty state widget with icon, message, and optional CTA
/// 
/// Use this when a list or screen has no data to display.
/// Provides a friendly, informative message and optional action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  
  /// Factory for the "no trades" state
  factory EmptyState.noTrades({VoidCallback? onAddTrade}) {
    return EmptyState(
      icon: Icons.show_chart_rounded,
      title: 'No trades yet',
      subtitle: 'Start logging your trades to track your performance and build your trading journal.',
      actionLabel: 'Add Your First Trade',
      onAction: onAddTrade,
    );
  }
  
  /// Factory for the "no results" state (when filtering)
  factory EmptyState.noResults({VoidCallback? onClearFilters}) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matching trades',
      subtitle: 'Try adjusting your filters or search query.',
      actionLabel: 'Clear Filters',
      onAction: onClearFilters,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container with gradient glow
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              
              // Subtitle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              
              // CTA Button
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


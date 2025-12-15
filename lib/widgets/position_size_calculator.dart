import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Position Size Calculator Widget
/// 
/// Calculates optimal position size based on:
/// - Account balance
/// - Risk percentage
/// - Entry price
/// - Stop loss price
class PositionSizeCalculator extends StatefulWidget {
  const PositionSizeCalculator({super.key});

  /// Show as a modal bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PositionSizeCalculator(),
    );
  }

  @override
  State<PositionSizeCalculator> createState() => _PositionSizeCalculatorState();
}

class _PositionSizeCalculatorState extends State<PositionSizeCalculator> {
  final _accountController = TextEditingController(text: '10000');
  final _riskPercentController = TextEditingController(text: '1');
  final _entryController = TextEditingController();
  final _stopLossController = TextEditingController();
  
  double? _positionSize;
  double? _shares;
  double? _riskAmount;
  double? _riskPerShare;

  @override
  void dispose() {
    _accountController.dispose();
    _riskPercentController.dispose();
    _entryController.dispose();
    _stopLossController.dispose();
    super.dispose();
  }

  void _calculate() {
    final account = double.tryParse(_accountController.text);
    final riskPercent = double.tryParse(_riskPercentController.text);
    final entry = double.tryParse(_entryController.text);
    final stopLoss = double.tryParse(_stopLossController.text);

    if (account == null || riskPercent == null || entry == null || stopLoss == null) {
      setState(() {
        _positionSize = null;
        _shares = null;
        _riskAmount = null;
        _riskPerShare = null;
      });
      return;
    }

    if (entry == stopLoss) {
      setState(() {
        _positionSize = null;
        _shares = null;
        _riskAmount = null;
        _riskPerShare = null;
      });
      return;
    }

    final riskAmount = account * (riskPercent / 100);
    final riskPerShare = (entry - stopLoss).abs();
    final shares = riskAmount / riskPerShare;
    final positionSize = shares * entry;

    setState(() {
      _riskAmount = riskAmount;
      _riskPerShare = riskPerShare;
      _shares = shares;
      _positionSize = positionSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calculate_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position Size Calculator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Calculate optimal position size based on risk',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.border),
          
          // Input fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Account balance & Risk %
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Account Balance',
                        controller: _accountController,
                        prefix: '\$',
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InputField(
                        label: 'Risk %',
                        controller: _riskPercentController,
                        suffix: '%',
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Entry & Stop Loss
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        label: 'Entry Price',
                        controller: _entryController,
                        prefix: '\$',
                        hint: '150.00',
                        onChanged: (_) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InputField(
                        label: 'Stop Loss',
                        controller: _stopLossController,
                        prefix: '\$',
                        hint: '145.00',
                        onChanged: (_) => _calculate(),
                        borderColor: AppColors.loss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results
          if (_positionSize != null) ...[
            const Divider(height: 1, color: AppColors.border),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.05),
              ),
              child: Column(
                children: [
                  // Main result - Position Size
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.2),
                          AppColors.accent.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'POSITION SIZE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_positionSize!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_shares!.toStringAsFixed(2)} shares',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Secondary results
                  Row(
                    children: [
                      Expanded(
                        child: _ResultCard(
                          label: 'Risk Amount',
                          value: '\$${_riskAmount!.toStringAsFixed(2)}',
                          color: AppColors.loss,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResultCard(
                          label: 'Risk/Share',
                          value: '\$${_riskPerShare!.toStringAsFixed(2)}',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Empty state hint
          if (_positionSize == null && _entryController.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Enter entry and stop loss to calculate',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final Color? borderColor;

  const _InputField({
    required this.label,
    required this.controller,
    this.prefix,
    this.suffix,
    this.hint,
    this.onChanged,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: borderColor != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: borderColor!.withValues(alpha: 0.3),
                    ),
                  )
                : null,
            focusedBorder: borderColor != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor!, width: 2),
                  )
                : null,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


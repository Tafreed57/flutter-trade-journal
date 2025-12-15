import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trade.dart';
import '../state/trade_provider.dart';
import '../theme/app_theme.dart';

/// Screen for adding or editing a trade
/// 
/// Provides a form with validation for all trade fields.
/// Supports both creating new trades and editing existing ones.
class AddTradeScreen extends StatefulWidget {
  final Trade? editTrade;

  const AddTradeScreen({super.key, this.editTrade});

  bool get isEditing => editTrade != null;

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _symbolController;
  late final TextEditingController _quantityController;
  late final TextEditingController _entryPriceController;
  late final TextEditingController _exitPriceController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagInputController;
  
  // TP/SL Controllers
  late final TextEditingController _stopLossController;
  late final TextEditingController _takeProfitController;
  late final TextEditingController _setupController;
  
  // Form state
  TradeSide _side = TradeSide.long;
  DateTime _entryDate = DateTime.now();
  DateTime? _exitDate;
  List<String> _tags = [];
  bool _isSubmitting = false;
  bool _isClosed = false;
  bool _showRiskManagement = false;
  
  @override
  void initState() {
    super.initState();
    
    final trade = widget.editTrade;
    
    _symbolController = TextEditingController(text: trade?.symbol ?? '');
    _quantityController = TextEditingController(
      text: trade?.quantity.toString() ?? '',
    );
    _entryPriceController = TextEditingController(
      text: trade?.entryPrice.toString() ?? '',
    );
    _exitPriceController = TextEditingController(
      text: trade?.exitPrice?.toString() ?? '',
    );
    _notesController = TextEditingController(text: trade?.notes ?? '');
    _tagInputController = TextEditingController();
    _stopLossController = TextEditingController(
      text: trade?.stopLoss?.toString() ?? '',
    );
    _takeProfitController = TextEditingController(
      text: trade?.takeProfit?.toString() ?? '',
    );
    _setupController = TextEditingController(text: trade?.setup ?? '');
    
    if (trade != null) {
      _side = trade.side;
      _entryDate = trade.entryDate;
      _exitDate = trade.exitDate;
      _tags = List.from(trade.tags);
      _isClosed = trade.isClosed;
      _showRiskManagement = trade.stopLoss != null || trade.takeProfit != null;
    }
  }
  
  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _entryPriceController.dispose();
    _exitPriceController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _setupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Trade' : 'Add Trade'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitForm,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : Text(widget.isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Symbol field
            _buildSectionTitle('Symbol'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _symbolController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'AAPL, TSLA, BTC...',
                prefixIcon: Icon(Icons.trending_up_rounded),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                UpperCaseTextFormatter(),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Symbol is required';
                }
                if (value.trim().isEmpty) {
                  return 'Symbol must be at least 1 character';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Side toggle
            _buildSectionTitle('Side'),
            const SizedBox(height: 8),
            _SideToggle(
              side: _side,
              onChanged: (side) => setState(() => _side = side),
            ),
            
            const SizedBox(height: 24),
            
            // Quantity and entry price row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Quantity'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: '100',
                          prefixIcon: Icon(Icons.layers_rounded),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Entry Price'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _entryPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: '150.00',
                          prefixText: '\$ ',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Risk Management Section (SL/TP)
            _buildRiskManagementSection(),
            
            const SizedBox(height: 24),
            
            // Entry date
            _buildSectionTitle('Entry Date'),
            const SizedBox(height: 8),
            _DatePickerField(
              date: _entryDate,
              onChanged: (date) => setState(() {
                _entryDate = date;
                // Reset exit date if it's before entry
                if (_exitDate != null && _exitDate!.isBefore(date)) {
                  _exitDate = null;
                }
              }),
            ),
            
            const SizedBox(height: 24),
            
            // Closed trade toggle
            Row(
              children: [
                _buildSectionTitle('Trade Closed'),
                const Spacer(),
                Switch(
                  value: _isClosed,
                  onChanged: (value) => setState(() {
                    _isClosed = value;
                    if (!value) {
                      _exitPriceController.clear();
                      _exitDate = null;
                    } else {
                      _exitDate ??= DateTime.now();
                    }
                  }),
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
            
            // Exit fields (only if closed)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Exit price
                  _buildSectionTitle('Exit Price'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _exitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: '155.00',
                      prefixText: '\$ ',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'),
                      ),
                    ],
                    validator: (value) {
                      if (!_isClosed) return null;
                      if (value == null || value.isEmpty) {
                        return 'Required for closed trades';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Exit date
                  _buildSectionTitle('Exit Date'),
                  const SizedBox(height: 8),
                  _DatePickerField(
                    date: _exitDate ?? DateTime.now(),
                    onChanged: (date) => setState(() => _exitDate = date),
                    firstDate: _entryDate,
                  ),
                ],
              ),
              crossFadeState: _isClosed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            
            const SizedBox(height: 24),
            
            // P&L Preview (if closed)
            if (_isClosed) _buildPnLPreview(),
            
            const SizedBox(height: 24),
            
            // Tags
            _buildSectionTitle('Tags'),
            const SizedBox(height: 8),
            _buildTagsInput(),
            
            const SizedBox(height: 24),
            
            // Notes
            _buildSectionTitle('Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Trade rationale, lessons learned...',
                alignLabelWithHint: true,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Submit button (for keyboard users)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : Text(widget.isEditing ? 'Save Changes' : 'Add Trade'),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildRiskManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle for risk management
        InkWell(
          onTap: () => setState(() => _showRiskManagement = !_showRiskManagement),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _showRiskManagement 
                  ? AppColors.accent.withValues(alpha: 0.1) 
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showRiskManagement ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: _showRiskManagement ? AppColors.accent : AppColors.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Management',
                        style: TextStyle(
                          color: _showRiskManagement 
                              ? AppColors.accent 
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Set Stop Loss & Take Profit levels',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showRiskManagement 
                      ? Icons.keyboard_arrow_up_rounded 
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        
        // Expandable SL/TP fields
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: 16),
              
              // Stop Loss and Take Profit row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.loss,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildSectionTitle('Stop Loss'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _stopLossController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '145.00',
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: AppColors.loss.withValues(alpha: 0.05),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.loss.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.loss,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.profit,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildSectionTitle('Take Profit'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _takeProfitController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '165.00',
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: AppColors.profit.withValues(alpha: 0.05),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.profit.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.profit,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Risk/Reward Preview
              _buildRiskRewardPreview(),
              
              const SizedBox(height: 16),
              
              // Setup type dropdown
              _buildSectionTitle('Trade Setup'),
              const SizedBox(height: 8),
              _SetupDropdown(
                value: _setupController.text.isEmpty ? null : _setupController.text,
                onChanged: (setup) => setState(() => _setupController.text = setup ?? ''),
              ),
            ],
          ),
          crossFadeState: _showRiskManagement
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildRiskRewardPreview() {
    final entryPrice = double.tryParse(_entryPriceController.text);
    final stopLoss = double.tryParse(_stopLossController.text);
    final takeProfit = double.tryParse(_takeProfitController.text);
    final quantity = double.tryParse(_quantityController.text);
    
    if (entryPrice == null || (stopLoss == null && takeProfit == null)) {
      return const SizedBox.shrink();
    }
    
    double? riskAmount;
    double? rewardAmount;
    double? rr;
    
    if (stopLoss != null && quantity != null) {
      riskAmount = (entryPrice - stopLoss).abs() * quantity;
    }
    if (takeProfit != null && quantity != null) {
      rewardAmount = (takeProfit - entryPrice).abs() * quantity;
    }
    if (stopLoss != null && takeProfit != null) {
      final risk = (entryPrice - stopLoss).abs();
      final reward = (takeProfit - entryPrice).abs();
      if (risk > 0) rr = reward / risk;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Risk/Reward Analysis',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Risk
              Expanded(
                child: _RRCard(
                  label: 'Risk',
                  value: riskAmount != null ? '\$${riskAmount.toStringAsFixed(2)}' : '--',
                  color: AppColors.loss,
                ),
              ),
              const SizedBox(width: 12),
              // Reward
              Expanded(
                child: _RRCard(
                  label: 'Reward',
                  value: rewardAmount != null ? '\$${rewardAmount.toStringAsFixed(2)}' : '--',
                  color: AppColors.profit,
                ),
              ),
              const SizedBox(width: 12),
              // R:R Ratio
              Expanded(
                child: _RRCard(
                  label: 'R:R',
                  value: rr != null ? '1:${rr.toStringAsFixed(2)}' : '--',
                  color: rr != null && rr >= 2 ? AppColors.profit : 
                         rr != null && rr >= 1 ? AppColors.warning : AppColors.loss,
                  highlight: rr != null && rr >= 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPnLPreview() {
    final entryPrice = double.tryParse(_entryPriceController.text);
    final exitPrice = double.tryParse(_exitPriceController.text);
    final quantity = double.tryParse(_quantityController.text);
    
    if (entryPrice == null || exitPrice == null || quantity == null) {
      return const SizedBox.shrink();
    }
    
    final priceDiff = exitPrice - entryPrice;
    final multiplier = _side == TradeSide.long ? 1 : -1;
    final pnl = priceDiff * quantity * multiplier;
    final pnlPercent = (priceDiff / entryPrice) * 100 * multiplier;
    
    final isProfit = pnl > 0;
    final color = isProfit ? AppColors.profit : AppColors.loss;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated P&L',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${isProfit ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isProfit ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current tags
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => _TagChip(
              label: tag,
              onRemove: () => setState(() => _tags.remove(tag)),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputController,
                decoration: const InputDecoration(
                  hintText: 'Add tag (e.g., swing, breakout)',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addTag(_tagInputController.text),
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
              ),
            ),
          ],
        ),
        
        // Suggested tags
        if (_tags.length < 3) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['swing', 'scalp', 'breakout', 'momentum', 'reversal']
                .where((t) => !_tags.contains(t))
                .take(4)
                .map((tag) => GestureDetector(
                  onTap: () => _addTag(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '+ $tag',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ))
                .toList(),
          ),
        ],
      ],
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed) && _tags.length < 10) {
      setState(() => _tags.add(trimmed));
      _tagInputController.clear();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    final provider = context.read<TradeProvider>();
    
    // Parse optional SL/TP values
    final stopLoss = _stopLossController.text.isNotEmpty 
        ? double.tryParse(_stopLossController.text) 
        : null;
    final takeProfit = _takeProfitController.text.isNotEmpty 
        ? double.tryParse(_takeProfitController.text) 
        : null;
    final setup = _setupController.text.trim().isEmpty 
        ? null 
        : _setupController.text.trim();
    
    bool success;
    
    if (widget.isEditing) {
      final updatedTrade = widget.editTrade!.copyWith(
        symbol: _symbolController.text.trim().toUpperCase(),
        side: _side,
        quantity: double.parse(_quantityController.text),
        entryPrice: double.parse(_entryPriceController.text),
        exitPrice: _isClosed ? double.parse(_exitPriceController.text) : null,
        entryDate: _entryDate,
        exitDate: _isClosed ? _exitDate : null,
        tags: _tags,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        setup: setup,
      );
      
      success = await provider.updateTrade(updatedTrade);
    } else {
      success = await provider.addTrade(
        symbol: _symbolController.text.trim(),
        side: _side,
        quantity: double.parse(_quantityController.text),
        entryPrice: double.parse(_entryPriceController.text),
        exitPrice: _isClosed ? double.parse(_exitPriceController.text) : null,
        entryDate: _entryDate,
        exitDate: _isClosed ? _exitDate : null,
        tags: _tags,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        setup: setup,
      );
    }
    
    if (!mounted) return;
    
    setState(() => _isSubmitting = false);
    
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Trade updated' : 'Trade added',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save trade'),
          backgroundColor: AppColors.loss,
        ),
      );
    }
  }
}

/// Toggle for selecting trade side (Long/Short)
class _SideToggle extends StatelessWidget {
  final TradeSide side;
  final ValueChanged<TradeSide> onChanged;

  const _SideToggle({
    required this.side,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SideOption(
              label: 'Long',
              icon: Icons.trending_up_rounded,
              color: AppColors.profit,
              selected: side == TradeSide.long,
              onTap: () => onChanged(TradeSide.long),
              isLeft: true,
            ),
          ),
          Expanded(
            child: _SideOption(
              label: 'Short',
              icon: Icons.trending_down_rounded,
              color: AppColors.loss,
              selected: side == TradeSide.short,
              onTap: () => onChanged(TradeSide.short),
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isLeft;

  const _SideOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(11) : Radius.zero,
            right: !isLeft ? const Radius.circular(11) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? color : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textTertiary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date picker field widget
class _DatePickerField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  const _DatePickerField({
    required this.date,
    required this.onChanged,
    this.firstDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.accent,
                  surface: AppColors.surface,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Removable tag chip
class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text input formatter for uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Risk/Reward card widget
class _RRCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _RRCard({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? color : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Setup type dropdown
class _SetupDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _SetupDropdown({
    required this.value,
    required this.onChanged,
  });

  static const List<String> setups = [
    'Breakout',
    'Breakdown',
    'Trend Continuation',
    'Reversal',
    'Support Bounce',
    'Resistance Rejection',
    'Range Trade',
    'Momentum',
    'Gap Fill',
    'News Trade',
    'Scalp',
    'Swing',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text(
            'Select trade setup...',
            style: TextStyle(color: AppColors.textTertiary),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          dropdownColor: AppColors.surface,
          items: setups.map((setup) {
            return DropdownMenuItem(
              value: setup,
              child: Text(setup),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}


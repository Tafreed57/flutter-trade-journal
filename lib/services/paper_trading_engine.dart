import 'package:uuid/uuid.dart';
import '../models/paper_trading.dart';
import '../models/trade.dart';
import '../core/debug_trace.dart';

/// Pure Dart paper trading engine
///
/// Handles:
/// - Order placement and execution
/// - Position management
/// - P&L calculations
/// - Stop loss / take profit triggers
///
/// This is decoupled from UI for testability.
class PaperTradingEngine {
  final Uuid _uuid = const Uuid();

  PaperAccount _account;
  final List<PaperPosition> _openPositions = [];
  final List<PaperPosition> _closedPositions = [];
  final List<PaperOrder> _orderHistory = [];

  // Callbacks for when trades close (to sync with journal)
  // Changed to Future to ensure async save is awaited
  Future<void> Function(Trade trade)? onTradeClosed;

  /// Callback when a position is closed (for cleaning up position tools)
  void Function(String positionId, String? linkedToolId)? onPositionClosed;

  PaperTradingEngine({double initialBalance = 10000.0})
    : _account = PaperAccount(
        id: const Uuid().v4(),
        balance: initialBalance,
        initialBalance: initialBalance,
      );

  // ==================== GETTERS ====================

  PaperAccount get account => _account;
  List<PaperPosition> get openPositions => List.unmodifiable(_openPositions);
  List<PaperPosition> get closedPositions =>
      List.unmodifiable(_closedPositions);
  List<PaperOrder> get orderHistory => List.unmodifiable(_orderHistory);

  double get balance => _account.balance;
  double get realizedPnL => _account.realizedPnL;

  /// Calculate total unrealized P&L across all open positions
  double unrealizedPnL(Map<String, double> currentPrices) {
    double total = 0;
    for (final position in _openPositions) {
      final price = currentPrices[position.symbol];
      if (price != null) {
        total += position.unrealizedPnL(price);
      }
    }
    return total;
  }

  /// Get equity (balance + unrealized P&L)
  double equity(Map<String, double> currentPrices) {
    return balance + unrealizedPnL(currentPrices);
  }

  /// Get position for a specific symbol (null if none)
  PaperPosition? getPositionForSymbol(String symbol) {
    try {
      return _openPositions.firstWhere((p) => p.symbol == symbol);
    } catch (_) {
      return null;
    }
  }

  // ==================== ORDER EXECUTION ====================

  /// Place a market order (executes immediately at current price)
  Future<PaperOrder> placeMarketOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    required double currentPrice,
    double? stopLoss,
    double? takeProfit,
    String? linkedToolId,
    String? userId,
  }) async {
    JournalDebug.chartTrade(
      'PLACE_MARKET_ORDER',
      symbol: symbol,
      userId: userId,
      toolId: linkedToolId,
    );

    final order = PaperOrder(
      id: _uuid.v4(),
      symbol: symbol,
      side: side,
      type: OrderType.market,
      quantity: quantity,
    );

    // Execute immediately
    await _executeOrder(
      order,
      currentPrice,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      linkedToolId: linkedToolId,
      userId: userId,
    );
    _orderHistory.add(order);

    return order;
  }

  /// Execute an order at the given price
  Future<void> _executeOrder(
    PaperOrder order,
    double price, {
    double? stopLoss,
    double? takeProfit,
    String? linkedToolId,
    String? userId,
  }) async {
    // Check if we have an existing position in this symbol
    final existingPosition = getPositionForSymbol(order.symbol);

    if (existingPosition != null) {
      // Handle position modification
      if (existingPosition.side == order.side) {
        // Adding to position (average up/down)
        _addToPosition(existingPosition, order.quantity, price);
      } else {
        // Reducing or closing position
        await _reducePosition(existingPosition, order.quantity, price);
      }
    } else {
      // Open new position
      _openNewPosition(
        order,
        price,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        linkedToolId: linkedToolId,
        userId: userId,
      );
    }

    // Update order status
    order.status = OrderStatus.filled;
    order.filledPrice = price;
    order.filledAt = DateTime.now();
  }

  /// Open a new position
  void _openNewPosition(
    PaperOrder order,
    double price, {
    double? stopLoss,
    double? takeProfit,
    String? linkedToolId,
    String? userId,
  }) {
    final cost = order.quantity * price;

    // Deduct from balance (for both long and short, we need margin)
    _account.balance -= cost;

    final position = PaperPosition(
      id: _uuid.v4(),
      symbol: order.symbol,
      side: order.side,
      quantity: order.quantity,
      entryPrice: price,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      linkedToolId: linkedToolId,
      userId: userId,
    );

    _openPositions.add(position);
  }

  /// Add to an existing position (same direction)
  void _addToPosition(PaperPosition position, double quantity, double price) {
    final totalQuantity = position.quantity + quantity;
    final totalCost =
        (position.quantity * position.entryPrice) + (quantity * price);
    final newAvgPrice = totalCost / totalQuantity;

    // Deduct additional cost
    _account.balance -= quantity * price;

    // Update position
    position.quantity = totalQuantity;
    position.entryPrice = newAvgPrice;
  }

  /// Reduce or close a position (opposite direction)
  Future<void> _reducePosition(
    PaperPosition position,
    double quantity,
    double price,
  ) async {
    final closeQuantity = quantity.clamp(0, position.quantity);
    final pnl =
        position.unrealizedPnL(price) * (closeQuantity / position.quantity);

    // Return capital + P&L
    final returnedCapital = closeQuantity * position.entryPrice;
    _account.balance += returnedCapital + pnl;
    _account.realizedPnL += pnl;

    if (closeQuantity >= position.quantity) {
      // Fully closed
      await _closePosition(position, price, pnl);
    } else {
      // Partially closed
      position.quantity -= closeQuantity;
    }
  }

  /// Close a position completely
  /// Made async to properly await journal entry creation
  Future<void> _closePosition(
    PaperPosition position,
    double exitPrice,
    double pnl,
  ) async {
    JournalDebug.chartTrade(
      'POSITION_CLOSE_START',
      positionId: position.id,
      symbol: position.symbol,
      userId: position.userId,
    );

    position.closedAt = DateTime.now();
    position.exitPrice = exitPrice;
    position.realizedPnL = pnl;

    _openPositions.remove(position);
    _closedPositions.add(position);

    // Create journal entry for the closed trade - AWAIT to ensure it saves
    await _createJournalEntry(position);

    // Notify listeners that position was closed (for cleaning up chart tools)
    onPositionClosed?.call(position.id, position.linkedToolId);

    JournalDebug.chartTrade(
      'POSITION_CLOSE_COMPLETE',
      positionId: position.id,
      symbol: position.symbol,
    );
  }

  /// Close position by ID
  Future<bool> closePosition(String positionId, double currentPrice) async {
    JournalDebug.chartTrade('CLOSE_POSITION_BY_ID', positionId: positionId);

    final position = _openPositions.firstWhere(
      (p) => p.id == positionId,
      orElse: () => throw Exception('Position not found'),
    );

    final pnl = position.unrealizedPnL(currentPrice);

    // Return capital + P&L
    final returnedCapital = position.quantity * position.entryPrice;
    _account.balance += returnedCapital + pnl;
    _account.realizedPnL += pnl;

    await _closePosition(position, currentPrice, pnl);
    return true;
  }

  /// Close all positions
  Future<void> closeAllPositions(Map<String, double> currentPrices) async {
    for (final position in _openPositions.toList()) {
      final price = currentPrices[position.symbol];
      if (price != null) {
        await closePosition(position.id, price);
      }
    }
  }

  // ==================== STOP LOSS / TAKE PROFIT ====================

  /// Check and execute SL/TP for all positions
  /// Call this on every price update
  Future<void> checkStopLossTakeProfit(
    String symbol,
    double currentPrice,
  ) async {
    final positionsForSymbol = _openPositions
        .where((p) => p.symbol == symbol)
        .toList();

    for (final position in positionsForSymbol) {
      if (position.shouldTriggerStopLoss(currentPrice)) {
        JournalDebug.chartTrade(
          'SL_TRIGGERED',
          positionId: position.id,
          symbol: symbol,
        );
        await closePosition(position.id, currentPrice);
      } else if (position.shouldTriggerTakeProfit(currentPrice)) {
        JournalDebug.chartTrade(
          'TP_TRIGGERED',
          positionId: position.id,
          symbol: symbol,
        );
        await closePosition(position.id, currentPrice);
      }
    }
  }

  /// Update stop loss for a position
  void updateStopLoss(String positionId, double? stopLoss) {
    final position = _openPositions.firstWhere((p) => p.id == positionId);
    position.stopLoss = stopLoss;
  }

  /// Update take profit for a position
  void updateTakeProfit(String positionId, double? takeProfit) {
    final position = _openPositions.firstWhere((p) => p.id == positionId);
    position.takeProfit = takeProfit;
  }

  // ==================== JOURNAL INTEGRATION ====================

  /// Create a Trade journal entry from a closed position
  /// This MUST await the callback to ensure the trade is saved before continuing
  Future<void> _createJournalEntry(PaperPosition position) async {
    JournalDebug.chartTrade(
      'CREATE_JOURNAL_ENTRY_START',
      symbol: position.symbol,
      positionId: position.id,
      userId: position.userId,
      toolId: position.linkedToolId,
    );

    final trade = Trade(
      id: _uuid.v4(),
      symbol: position.symbol,
      side: position.isLong ? TradeSide.long : TradeSide.short,
      quantity: position.quantity,
      entryPrice: position.entryPrice,
      exitPrice: position.exitPrice,
      entryDate: position.openedAt,
      exitDate: position.closedAt,
      tags: ['paper-trade'],
      notes: 'Paper trade - ${position.realizedPnL! >= 0 ? "WIN" : "LOSS"}',
      stopLoss: position.stopLoss,
      takeProfit: position.takeProfit,
      linkedToolId: position.linkedToolId,
      userId: position.userId,
    );

    JournalDebug.chartTrade(
      'TRADE_OBJECT_CREATED',
      tradeId: trade.id,
      symbol: trade.symbol,
      userId: trade.userId,
    );

    // Notify listeners to save to journal - AWAIT to ensure it completes
    if (onTradeClosed != null) {
      JournalDebug.chartTrade('CALLING_ON_TRADE_CLOSED', tradeId: trade.id);
      await onTradeClosed!(trade);
      JournalDebug.chartTrade('ON_TRADE_CLOSED_COMPLETE', tradeId: trade.id);
    } else {
      JournalDebug.warn(
        'onTradeClosed callback is null - trade will NOT be saved!',
      );
    }
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Reset account to initial state
  void resetAccount({double? newBalance}) {
    final balance = newBalance ?? _account.initialBalance;
    _account = PaperAccount(
      id: _uuid.v4(),
      balance: balance,
      initialBalance: balance,
    );
    _openPositions.clear();
    _closedPositions.clear();
    _orderHistory.clear();
  }

  /// Restore account from persisted state
  void restoreAccount(PaperAccount account) {
    _account = account;
  }

  /// Restore positions from persisted state
  void restorePositions(List<PaperPosition> positions) {
    _openPositions.clear();
    _closedPositions.clear();

    for (final position in positions) {
      if (position.isOpen) {
        _openPositions.add(position);
      } else {
        _closedPositions.add(position);
      }
    }
  }

  /// Restore orders from persisted state
  void restoreOrders(List<PaperOrder> orders) {
    _orderHistory.clear();
    _orderHistory.addAll(orders);
  }

  /// Add funds to account
  void deposit(double amount) {
    _account.balance += amount;
  }

  /// Withdraw funds from account
  bool withdraw(double amount) {
    if (amount > _account.balance) return false;
    _account.balance -= amount;
    return true;
  }

  // ==================== RISK CALCULATIONS ====================

  /// Calculate position size based on risk percentage
  ///
  /// [balance] - Account balance
  /// [riskPercent] - Risk per trade (e.g., 1.0 = 1%)
  /// [entryPrice] - Entry price
  /// [stopLossPrice] - Stop loss price
  static double calculatePositionSize({
    required double balance,
    required double riskPercent,
    required double entryPrice,
    required double stopLossPrice,
  }) {
    final riskAmount = balance * (riskPercent / 100);
    final stopLossDistance = (entryPrice - stopLossPrice).abs();

    if (stopLossDistance == 0) return 0;

    return riskAmount / stopLossDistance;
  }
}

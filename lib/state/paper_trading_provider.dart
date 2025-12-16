import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/logger.dart';
import '../models/live_price.dart';
import '../models/paper_trading.dart';
import '../models/trade.dart';
import '../services/paper_trading_engine.dart';
import '../services/trade_repository.dart';

/// State management for paper trading
///
/// Manages the paper trading engine and syncs with:
/// - Live price updates (for P&L calculation and SL/TP triggers)
/// - Trade journal (auto-logging closed positions)
class PaperTradingProvider extends ChangeNotifier {
  final PaperTradingEngine _engine;
  final TradeRepository _tradeRepository;

  // Current prices for P&L calculation
  final Map<String, double> _currentPrices = {};

  // UI state
  double _orderQuantity = 1.0;
  double? _stopLossPercent;
  double? _takeProfitPercent;
  String? _error;

  PaperTradingProvider(this._tradeRepository) : _engine = PaperTradingEngine() {
    // Set up callback to save closed trades to journal
    _engine.onTradeClosed = _onTradeClosed;
  }

  // ==================== GETTERS ====================

  PaperAccount get account => _engine.account;
  double get balance => _engine.balance;
  double get realizedPnL => _engine.realizedPnL;
  List<PaperPosition> get openPositions => _engine.openPositions;
  List<PaperPosition> get closedPositions => _engine.closedPositions;
  List<PaperOrder> get orderHistory => _engine.orderHistory;

  double get orderQuantity => _orderQuantity;
  double? get stopLossPercent => _stopLossPercent;
  double? get takeProfitPercent => _takeProfitPercent;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Total unrealized P&L
  double get unrealizedPnL => _engine.unrealizedPnL(_currentPrices);

  /// Account equity (balance + unrealized P&L)
  double get equity => _engine.equity(_currentPrices);

  /// Get current price for a symbol
  double? getCurrentPrice(String symbol) => _currentPrices[symbol];

  /// Get position for a symbol
  PaperPosition? getPositionForSymbol(String symbol) =>
      _engine.getPositionForSymbol(symbol);

  /// Check if there's an open position for a symbol
  bool hasPositionFor(String symbol) =>
      _engine.getPositionForSymbol(symbol) != null;

  // ==================== PRICE UPDATES ====================

  /// Update price for a symbol (call this on live price updates)
  void updatePrice(LivePrice price) {
    _currentPrices[price.symbol] = price.price;

    // Check SL/TP triggers
    _engine.checkStopLossTakeProfit(price.symbol, price.price);

    notifyListeners();
  }

  /// Batch update prices
  void updatePrices(Map<String, double> prices) {
    _currentPrices.addAll(prices);

    for (final entry in prices.entries) {
      _engine.checkStopLossTakeProfit(entry.key, entry.value);
    }

    notifyListeners();
  }

  // ==================== ORDER PLACEMENT ====================

  /// Place a buy order
  bool buy(String symbol, double currentPrice) {
    try {
      _error = null;

      // Calculate SL/TP prices if percentages are set
      double? stopLoss;
      double? takeProfit;

      if (_stopLossPercent != null) {
        stopLoss = currentPrice * (1 - _stopLossPercent! / 100);
      }
      if (_takeProfitPercent != null) {
        takeProfit = currentPrice * (1 + _takeProfitPercent! / 100);
      }

      _engine.placeMarketOrder(
        symbol: symbol,
        side: OrderSide.buy,
        quantity: _orderQuantity,
        currentPrice: currentPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
      );

      _currentPrices[symbol] = currentPrice;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Place a sell order
  bool sell(String symbol, double currentPrice) {
    try {
      _error = null;

      // Calculate SL/TP prices if percentages are set
      double? stopLoss;
      double? takeProfit;

      if (_stopLossPercent != null) {
        stopLoss = currentPrice * (1 + _stopLossPercent! / 100);
      }
      if (_takeProfitPercent != null) {
        takeProfit = currentPrice * (1 - _takeProfitPercent! / 100);
      }

      _engine.placeMarketOrder(
        symbol: symbol,
        side: OrderSide.sell,
        quantity: _orderQuantity,
        currentPrice: currentPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
      );

      _currentPrices[symbol] = currentPrice;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Close a specific position
  bool closePosition(String positionId) {
    try {
      _error = null;

      final position = openPositions.firstWhere((p) => p.id == positionId);
      final currentPrice = _currentPrices[position.symbol];

      if (currentPrice == null) {
        _error = 'No current price available';
        notifyListeners();
        return false;
      }

      _engine.closePosition(positionId, currentPrice);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Close all open positions
  void closeAllPositions() {
    _engine.closeAllPositions(_currentPrices);
    notifyListeners();
  }

  // ==================== ORDER SETTINGS ====================

  /// Set order quantity
  void setOrderQuantity(double quantity) {
    _orderQuantity = quantity.clamp(0.01, double.infinity);
    notifyListeners();
  }

  /// Set stop loss percentage
  void setStopLossPercent(double? percent) {
    _stopLossPercent = percent;
    notifyListeners();
  }

  /// Set take profit percentage
  void setTakeProfitPercent(double? percent) {
    _takeProfitPercent = percent;
    notifyListeners();
  }

  /// Update SL for an existing position
  void updatePositionStopLoss(String positionId, double? stopLoss) {
    _engine.updateStopLoss(positionId, stopLoss);
    notifyListeners();
  }

  /// Update TP for an existing position
  void updatePositionTakeProfit(String positionId, double? takeProfit) {
    _engine.updateTakeProfit(positionId, takeProfit);
    notifyListeners();
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Reset account to starting balance
  void resetAccount({double? newBalance}) {
    _engine.resetAccount(newBalance: newBalance);
    _currentPrices.clear();
    notifyListeners();
  }

  // ==================== JOURNAL INTEGRATION ====================

  /// Called when a position is closed - saves to journal
  Future<void> _onTradeClosed(Trade trade) async {
    try {
      await _tradeRepository.addTrade(trade);
      Log.trade('Paper trade saved to journal: ${trade.symbol}');
    } catch (e) {
      Log.e('Failed to save paper trade to journal', e);
    }
  }

  // ==================== HELPERS ====================

  /// Calculate estimated P&L for a potential trade
  double estimatePnL({
    required double entryPrice,
    required double exitPrice,
    required double quantity,
    required bool isLong,
  }) {
    final priceDiff = exitPrice - entryPrice;
    return priceDiff * quantity * (isLong ? 1 : -1);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // ==================== POSITION TOOL INTEGRATION ====================
  
  /// Create a position from a position tool
  /// Returns the position ID if successful
  String? openPositionFromTool({
    required String symbol,
    required bool isLong,
    required double entryPrice,
    required double quantity,
    required double stopLoss,
    required double takeProfit,
  }) {
    try {
      _error = null;
      
      _engine.placeMarketOrder(
        symbol: symbol,
        side: isLong ? OrderSide.buy : OrderSide.sell,
        quantity: quantity,
        currentPrice: entryPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
      );
      
      _currentPrices[symbol] = entryPrice;
      notifyListeners();
      
      // Return the newly created position ID
      final position = _engine.getPositionForSymbol(symbol);
      return position?.id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  /// Get position by ID
  PaperPosition? getPositionById(String positionId) {
    try {
      return openPositions.firstWhere((p) => p.id == positionId);
    } catch (_) {
      return null;
    }
  }
  
  /// Check if a position was closed (returns exit price and PnL if closed)
  ({double exitPrice, double pnl})? getClosedPositionResult(String positionId) {
    try {
      final closed = closedPositions.firstWhere((p) => p.id == positionId);
      return (
        exitPrice: closed.exitPrice ?? 0,
        pnl: closed.realizedPnL ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

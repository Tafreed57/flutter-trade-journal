import 'package:hive_flutter/hive_flutter.dart';
import '../core/logger.dart';
import '../models/paper_trading.dart';

/// Repository for persisting paper trading state using Hive
/// 
/// Persists:
/// - Account state (balance, realized P&L)
/// - Open positions
/// - Closed positions (for history)
/// - Order history
class PaperTradingRepository {
  static const String _accountBoxName = 'paper_account';
  static const String _positionsBoxName = 'paper_positions';
  static const String _ordersBoxName = 'paper_orders';
  
  Box<PaperAccount>? _accountBox;
  Box<PaperPosition>? _positionsBox;
  Box<PaperOrder>? _ordersBox;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the repository and open Hive boxes
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _accountBox = await Hive.openBox<PaperAccount>(_accountBoxName);
      _positionsBox = await Hive.openBox<PaperPosition>(_positionsBoxName);
      _ordersBox = await Hive.openBox<PaperOrder>(_ordersBoxName);
      
      _isInitialized = true;
      Log.i('PaperTradingRepository initialized');
    } catch (e) {
      Log.e('Failed to initialize PaperTradingRepository', e);
      rethrow;
    }
  }
  
  // ==================== ACCOUNT ====================
  
  /// Get the current paper trading account
  /// Returns null if no account exists yet
  PaperAccount? getAccount({String? userId}) {
    if (_accountBox == null) return null;
    
    // Get account for user (or default if no userId)
    final key = userId ?? 'default';
    return _accountBox!.get(key);
  }
  
  /// Save the paper trading account
  Future<void> saveAccount(PaperAccount account, {String? userId}) async {
    if (_accountBox == null) {
      throw StateError('PaperTradingRepository not initialized');
    }
    
    final key = userId ?? 'default';
    await _accountBox!.put(key, account);
    Log.trade('Saved paper account: balance=\$${account.balance.toStringAsFixed(2)}');
  }
  
  /// Delete the paper trading account (for reset)
  Future<void> deleteAccount({String? userId}) async {
    if (_accountBox == null) return;
    
    final key = userId ?? 'default';
    await _accountBox!.delete(key);
    Log.trade('Deleted paper account');
  }
  
  // ==================== POSITIONS ====================
  
  /// Get all positions (both open and closed)
  List<PaperPosition> getAllPositions({String? userId}) {
    if (_positionsBox == null) return [];
    
    var positions = _positionsBox!.values.toList();
    
    // Filter by userId if provided
    if (userId != null) {
      positions = positions.where((p) => p.userId == userId).toList();
    }
    
    return positions;
  }
  
  /// Get open positions only
  List<PaperPosition> getOpenPositions({String? userId}) {
    return getAllPositions(userId: userId)
        .where((p) => p.isOpen)
        .toList();
  }
  
  /// Get closed positions only
  List<PaperPosition> getClosedPositions({String? userId}) {
    return getAllPositions(userId: userId)
        .where((p) => p.isClosed)
        .toList()
      ..sort((a, b) => (b.closedAt ?? DateTime.now()).compareTo(a.closedAt ?? DateTime.now()));
  }
  
  /// Save a position
  Future<void> savePosition(PaperPosition position) async {
    if (_positionsBox == null) {
      throw StateError('PaperTradingRepository not initialized');
    }
    
    await _positionsBox!.put(position.id, position);
  }
  
  /// Save multiple positions
  Future<void> savePositions(List<PaperPosition> positions) async {
    if (_positionsBox == null) {
      throw StateError('PaperTradingRepository not initialized');
    }
    
    final map = {for (var p in positions) p.id: p};
    await _positionsBox!.putAll(map);
  }
  
  /// Delete a position
  Future<void> deletePosition(String id) async {
    if (_positionsBox == null) return;
    await _positionsBox!.delete(id);
  }
  
  /// Clear all positions (for reset)
  Future<void> clearPositions({String? userId}) async {
    if (_positionsBox == null) return;
    
    if (userId == null) {
      await _positionsBox!.clear();
    } else {
      // Only delete positions for this user
      final keysToDelete = _positionsBox!.values
          .where((p) => p.userId == userId)
          .map((p) => p.id)
          .toList();
      await _positionsBox!.deleteAll(keysToDelete);
    }
  }
  
  // ==================== ORDERS ====================
  
  /// Get all orders
  List<PaperOrder> getAllOrders() {
    if (_ordersBox == null) return [];
    return _ordersBox!.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  /// Save an order
  Future<void> saveOrder(PaperOrder order) async {
    if (_ordersBox == null) {
      throw StateError('PaperTradingRepository not initialized');
    }
    
    await _ordersBox!.put(order.id, order);
  }
  
  /// Save multiple orders
  Future<void> saveOrders(List<PaperOrder> orders) async {
    if (_ordersBox == null) {
      throw StateError('PaperTradingRepository not initialized');
    }
    
    final map = {for (var o in orders) o.id: o};
    await _ordersBox!.putAll(map);
  }
  
  /// Clear all orders
  Future<void> clearOrders() async {
    if (_ordersBox == null) return;
    await _ordersBox!.clear();
  }
  
  // ==================== LIFECYCLE ====================
  
  /// Close all boxes
  Future<void> close() async {
    await _accountBox?.close();
    await _positionsBox?.close();
    await _ordersBox?.close();
    _isInitialized = false;
  }
}


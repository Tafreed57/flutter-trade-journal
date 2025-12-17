import 'package:hive_flutter/hive_flutter.dart';
import '../models/trade.dart';

/// Repository for trade persistence using Hive
/// 
/// Handles all CRUD operations for trades. This abstracts the storage
/// implementation from the rest of the app, making it easy to swap
/// databases later if needed.
class TradeRepository {
  static const String _boxName = 'trades';
  
  Box<Trade>? _box;
  
  /// Initialize the repository and open the Hive box
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Trade>(_boxName);
  }
  
  /// Ensure the box is initialized before operations
  Box<Trade> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'TradeRepository not initialized. Call init() first.',
      );
    }
    return _box!;
  }
  
  /// Get all trades, sorted by entry date (newest first)
  /// If [userId] is provided, only returns trades for that user
  List<Trade> getAllTrades({String? userId}) {
    var trades = _safeBox.values.toList();
    
    // Filter by userId if provided
    if (userId != null) {
      trades = trades.where((t) => t.userId == userId || t.userId == null).toList();
    }
    
    trades.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    return trades;
  }
  
  /// Get a trade by its ID
  Trade? getTradeById(String id) {
    try {
      return _safeBox.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Add a new trade
  Future<void> addTrade(Trade trade) async {
    await _safeBox.put(trade.id, trade);
  }
  
  /// Update an existing trade
  Future<void> updateTrade(Trade trade) async {
    await _safeBox.put(trade.id, trade);
  }
  
  /// Delete a trade by ID
  Future<void> deleteTrade(String id) async {
    await _safeBox.delete(id);
  }
  
  /// Get trades filtered by symbol
  List<Trade> getTradesBySymbol(String symbol) {
    return _safeBox.values
        .where((t) => t.symbol.toUpperCase() == symbol.toUpperCase())
        .toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }
  
  /// Get trades within a date range
  List<Trade> getTradesByDateRange(DateTime start, DateTime end) {
    return _safeBox.values
        .where((t) => 
            t.entryDate.isAfter(start.subtract(const Duration(days: 1))) &&
            t.entryDate.isBefore(end.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }
  
  /// Get only winning trades
  List<Trade> getWinningTrades() {
    return _safeBox.values
        .where((t) => t.outcome == TradeOutcome.win)
        .toList();
  }
  
  /// Get only losing trades
  List<Trade> getLosingTrades() {
    return _safeBox.values
        .where((t) => t.outcome == TradeOutcome.loss)
        .toList();
  }
  
  /// Get open (unclosed) trades
  List<Trade> getOpenTrades() {
    return _safeBox.values
        .where((t) => !t.isClosed)
        .toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }
  
  /// Get trades with a specific tag
  List<Trade> getTradesByTag(String tag) {
    return _safeBox.values
        .where((t) => t.tags.contains(tag))
        .toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }
  
  /// Get all unique tags used across trades
  Set<String> getAllTags() {
    final tags = <String>{};
    for (final trade in _safeBox.values) {
      tags.addAll(trade.tags);
    }
    return tags;
  }
  
  /// Get all unique symbols used across trades
  Set<String> getAllSymbols() {
    return _safeBox.values.map((t) => t.symbol.toUpperCase()).toSet();
  }
  
  /// Close the Hive box
  Future<void> close() async {
    await _box?.close();
  }
}


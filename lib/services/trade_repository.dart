import 'package:hive_flutter/hive_flutter.dart';
import '../core/logger.dart';
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
      throw StateError('TradeRepository not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Get all trades, sorted by entry date (newest first)
  /// If [userId] is provided, only returns trades for that user (strict matching)
  /// Trades without userId are NOT returned to logged-in users to prevent leakage
  List<Trade> getAllTrades({String? userId}) {
    var allTradesInBox = _safeBox.values.toList();
    Log.d(
      'TradeRepository.getAllTrades: Total trades in Hive box: ${allTradesInBox.length}',
    );

    // Log each trade's userId for debugging
    for (var trade in allTradesInBox) {
      Log.d(
        '  Trade ${trade.id.substring(0, 8)}... userId: ${trade.userId}, symbol: ${trade.symbol}',
      );
    }

    List<Trade> trades;
    // STRICT filtering by userId - only return trades that belong to this user
    if (userId != null) {
      trades = allTradesInBox.where((t) => t.userId == userId).toList();
      Log.d(
        'TradeRepository.getAllTrades: Filtered to ${trades.length} trades for userId: $userId',
      );
    } else {
      // If no userId provided (offline/no auth), only return trades without userId
      trades = allTradesInBox.where((t) => t.userId == null).toList();
      Log.d(
        'TradeRepository.getAllTrades: Filtered to ${trades.length} trades with null userId',
      );
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
        .where(
          (t) =>
              t.entryDate.isAfter(start.subtract(const Duration(days: 1))) &&
              t.entryDate.isBefore(end.add(const Duration(days: 1))),
        )
        .toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  /// Get only winning trades
  List<Trade> getWinningTrades() {
    return _safeBox.values.where((t) => t.outcome == TradeOutcome.win).toList();
  }

  /// Get only losing trades
  List<Trade> getLosingTrades() {
    return _safeBox.values
        .where((t) => t.outcome == TradeOutcome.loss)
        .toList();
  }

  /// Get open (unclosed) trades
  List<Trade> getOpenTrades() {
    return _safeBox.values.where((t) => !t.isClosed).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
  }

  /// Get trades with a specific tag
  List<Trade> getTradesByTag(String tag) {
    return _safeBox.values.where((t) => t.tags.contains(tag)).toList()
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

  /// Clear all trades from the database
  Future<void> clearAll() async {
    await _safeBox.clear();
  }

  /// Clear only trades for a specific user
  /// Used on logout to prevent data leakage
  Future<void> clearUserTrades(String userId) async {
    final keysToDelete = <String>[];
    for (final trade in _safeBox.values) {
      if (trade.userId == userId) {
        keysToDelete.add(trade.id);
      }
    }
    await _safeBox.deleteAll(keysToDelete);
    Log.d('Cleared ${keysToDelete.length} trades for user: $userId');
  }

  /// Replace all trades for a user (used for Firestore sync)
  /// This ensures Hive matches Firestore exactly
  Future<void> replaceUserTrades(String userId, List<Trade> trades) async {
    // First clear existing trades for this user
    await clearUserTrades(userId);

    // Then add the new trades
    for (final trade in trades) {
      await _safeBox.put(trade.id, trade);
    }
    Log.d('Replaced with ${trades.length} trades for user: $userId');
  }

  /// Close the Hive box
  Future<void> close() async {
    await _box?.close();
  }
}

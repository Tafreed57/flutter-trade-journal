import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/logger.dart';
import '../core/debug_trace.dart';
import '../main.dart' show isFirebaseAvailable;
import '../models/trade.dart';
import '../services/trade_repository.dart';
import '../services/trade_sync_service.dart';
import '../services/analytics_service.dart';

/// State management for trades using ChangeNotifier
///
/// Provides access to trade data and operations throughout the app.
/// Uses Firebase Firestore for cross-device sync (source of truth),
/// with local Hive storage as a cache for offline access.
class TradeProvider extends ChangeNotifier {
  final TradeRepository _repository;
  final TradeSyncService _syncService;
  final Uuid _uuid = const Uuid();

  List<Trade> _trades = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;
  bool _isSyncing = false;

  // Filter state
  String? _symbolFilter;
  String? _tagFilter;
  TradeOutcome? _outcomeFilter;
  DateTimeRange? _dateRangeFilter;
  String _searchQuery = '';

  /// Current user ID for multi-user support
  String? get userId => _userId;

  /// Whether trades are currently syncing with cloud
  bool get isSyncing => _isSyncing;

  TradeProvider(this._repository, {TradeSyncService? syncService})
    : _syncService = syncService ?? TradeSyncService();

  // --- Getters ---

  List<Trade> get trades => _getFilteredTrades();
  List<Trade> get allTrades => List.unmodifiable(_trades);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => _trades.isEmpty;

  // Filter getters
  String? get symbolFilter => _symbolFilter;
  String? get tagFilter => _tagFilter;
  TradeOutcome? get outcomeFilter => _outcomeFilter;
  DateTimeRange? get dateRangeFilter => _dateRangeFilter;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters =>
      _symbolFilter != null ||
      _tagFilter != null ||
      _outcomeFilter != null ||
      _dateRangeFilter != null ||
      _searchQuery.isNotEmpty;

  // Quick access to filtered lists
  List<Trade> get openTrades => _trades.where((t) => !t.isClosed).toList();
  List<Trade> get closedTrades => _trades.where((t) => t.isClosed).toList();

  // Unique values for filters
  Set<String> get allSymbols => _repository.getAllSymbols();
  Set<String> get allTags => _repository.getAllTags();

  // --- Analytics getters (convenience accessors) ---

  double get winRate => AnalyticsService.calculateWinRate(_trades);
  double get totalPnL => AnalyticsService.calculateTotalPnL(_trades);
  double get averagePnL => AnalyticsService.calculateAveragePnL(_trades);
  double get profitFactor => AnalyticsService.calculateProfitFactor(_trades);
  double get riskRewardRatio =>
      AnalyticsService.calculateRiskRewardRatio(_trades);
  TradeCountStats get tradeStats =>
      AnalyticsService.getTradeCountStats(_trades);
  List<EquityPoint> get equityCurve =>
      AnalyticsService.generateEquityCurve(_trades);

  // --- Initialization ---

  /// Initialize the provider and load trades from storage
  /// LOCAL-FIRST STRATEGY: Show local cache immediately, then sync from Firestore in background
  /// This ensures fast UI while maintaining cloud sync for cross-device consistency.
  Future<void> init({String? userId}) async {
    JournalDebug.start('TradeProvider.init');
    JournalDebug.journalLoad('INIT_START', userId: userId);
    JournalDebug.state(
      'TradeProvider',
      'init',
      data: {
        'newUserId': userId?.substring(0, 8),
        'previousUserId': _userId?.substring(0, 8),
        'firebaseAvailable': isFirebaseAvailable,
      },
    );

    _isLoading = true;
    _error = null;
    _userId = userId;
    _trades = [];

    // DON'T call notifyListeners() here - we're about to load data

    try {
      await _repository.init();

      // If user logged out (null userId), don't load any trades
      if (userId == null) {
        JournalDebug.journalLoad('INIT_NO_USER', source: 'cleared');
        JournalDebug.end('TradeProvider.init', details: 'no user');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // STEP 1: Load from LOCAL CACHE first (FAST - shows UI immediately)
      JournalDebug.start('LocalCache.load');
      _trades = _repository.getAllTrades(userId: userId);
      _isLoading = false; // Stop loading indicator - we have data!
      JournalDebug.end('LocalCache.load', details: '${_trades.length} trades');
      JournalDebug.journalLoad(
        'LOCAL_CACHE_LOADED',
        userId: userId,
        tradeCount: _trades.length,
        source: 'Hive',
      );
      notifyListeners(); // Show local data immediately

      // STEP 2: Sync from Firestore in BACKGROUND (non-blocking)
      if (isFirebaseAvailable) {
        JournalDebug.journalLoad('STARTING_BACKGROUND_SYNC', userId: userId);
        // Don't await - let it run in background
        _syncFromFirestoreInBackground(userId);
      }

      JournalDebug.end(
        'TradeProvider.init',
        details: '${_trades.length} trades (local), background sync started',
      );
      JournalDebug.journalLoad(
        'INIT_SUCCESS',
        userId: userId,
        tradeCount: _trades.length,
      );
    } catch (e) {
      _error = 'Failed to load trades. Tap to retry.';
      JournalDebug.end('TradeProvider.init', details: 'FAILED');
      JournalDebug.journalLoad(
        'INIT_ERROR',
        userId: userId,
        error: e.toString(),
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Background sync from Firestore - doesn't block UI
  /// This runs after local cache is already displayed
  Future<void> _syncFromFirestoreInBackground(String userId) async {
    if (_isSyncing) {
      JournalDebug.warn('Background sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    // Don't notifyListeners here - we're syncing in background, UI already has local data
    JournalDebug.start('BackgroundSync');

    try {
      final cloudTrades = await _syncService.fetchTrades(userId);
      JournalDebug.journalLoad(
        'BACKGROUND_SYNC_COMPLETE',
        userId: userId,
        tradeCount: cloudTrades.length,
        source: 'Firestore',
      );

      // Only update if user hasn't changed during fetch
      if (_userId == userId) {
        if (cloudTrades.isNotEmpty) {
          // Replace local cache with cloud data
          await _repository.replaceUserTrades(userId, cloudTrades);
          _trades = cloudTrades;
          JournalDebug.end(
            'BackgroundSync',
            details: '${cloudTrades.length} trades synced',
          );
        } else {
          // Cloud returned empty - keep local data as-is
          JournalDebug.end(
            'BackgroundSync',
            details: 'cloud empty, keeping local',
          );
        }
        notifyListeners(); // Update UI
      } else {
        JournalDebug.end('BackgroundSync', details: 'skipped - user changed');
      }
    } catch (e) {
      // Background sync failed - that's okay, we still have local data
      JournalDebug.end('BackgroundSync', details: 'FAILED: $e');
      JournalDebug.warn(
        'Background Firestore sync failed (keeping local data): $e',
      );
      // Don't set error - we have local data displayed
    } finally {
      _isSyncing = false;
      // Only notify if we're still on same user
      if (_userId == userId) {
        notifyListeners();
      }
    }
  }

  // --- CRUD Operations ---

  /// Add a new trade
  /// Saves to both local storage and Firestore (if online)
  /// userId is REQUIRED - rejects trades without userId
  Future<bool> addTrade({
    required String symbol,
    required TradeSide side,
    required double quantity,
    required double entryPrice,
    double? exitPrice,
    required DateTime entryDate,
    DateTime? exitDate,
    List<String>? tags,
    String? notes,
    double? stopLoss,
    double? takeProfit,
    String? setup,
  }) async {
    // Reject trades without userId to prevent data leakage
    if (_userId == null) {
      _error = 'Cannot add trade: No user logged in';
      Log.w('Attempted to add trade without userId');
      notifyListeners();
      return false;
    }

    try {
      final trade = Trade(
        id: _uuid.v4(),
        symbol: symbol.toUpperCase().trim(),
        side: side,
        quantity: quantity,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        entryDate: entryDate,
        exitDate: exitDate,
        tags: tags,
        notes: notes?.trim(),
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        setup: setup,
        userId: _userId, // Associate trade with current user (REQUIRED)
      );

      Log.d('Adding trade ${trade.id} for userId: $_userId');

      // Save to local storage first
      await _repository.addTrade(trade);

      // Update in-memory list immediately for responsive UI
      _trades.insert(0, trade);
      notifyListeners();

      // Sync to Firestore (non-blocking)
      if (isFirebaseAvailable) {
        _syncService.saveTrade(trade).then((success) {
          if (success) {
            Log.d('Trade synced to cloud: ${trade.id}');
          } else {
            Log.w('Failed to sync trade to cloud: ${trade.id}');
          }
        });
      }

      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to add trade: ${e.toString()}';
      Log.e('Failed to add trade', e);
      notifyListeners();
      return false;
    }
  }

  /// Update an existing trade
  /// Updates both local storage and Firestore (if online)
  Future<bool> updateTrade(Trade trade) async {
    try {
      final updatedTrade = trade.copyWith(updatedAt: DateTime.now());

      // Update local storage
      await _repository.updateTrade(updatedTrade);

      // Sync to Firestore
      if (_userId != null && isFirebaseAvailable) {
        _syncService.updateTrade(updatedTrade).then((success) {
          if (success) {
            Log.d('Trade update synced to cloud: ${trade.id}');
          }
        });
      }

      _trades = _repository.getAllTrades(userId: _userId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update trade: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Delete a trade
  /// Deletes from both local storage and Firestore (if online)
  Future<bool> deleteTrade(String id) async {
    try {
      // Delete from local storage
      await _repository.deleteTrade(id);

      // Sync deletion to Firestore
      if (_userId != null && isFirebaseAvailable) {
        _syncService.deleteTrade(id, _userId!).then((success) {
          if (success) {
            Log.d('Trade deletion synced to cloud: $id');
          }
        });
      }

      _trades = _repository.getAllTrades(userId: _userId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete trade: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Close an open trade
  Future<bool> closeTrade(
    String id,
    double exitPrice,
    DateTime exitDate,
  ) async {
    final trade = _trades.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Trade not found'),
    );

    final closedTrade = trade.copyWith(
      exitPrice: exitPrice,
      exitDate: exitDate,
    );

    return updateTrade(closedTrade);
  }

  // --- Filtering ---

  /// Set symbol filter
  void setSymbolFilter(String? symbol) {
    _symbolFilter = symbol;
    notifyListeners();
  }

  /// Set tag filter
  void setTagFilter(String? tag) {
    _tagFilter = tag;
    notifyListeners();
  }

  /// Set outcome filter
  void setOutcomeFilter(TradeOutcome? outcome) {
    _outcomeFilter = outcome;
    notifyListeners();
  }

  /// Set date range filter
  void setDateRangeFilter(DateTimeRange? range) {
    _dateRangeFilter = range;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _symbolFilter = null;
    _tagFilter = null;
    _outcomeFilter = null;
    _dateRangeFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Get filtered trades based on current filter state
  List<Trade> _getFilteredTrades() {
    var filtered = List<Trade>.from(_trades);

    // Symbol filter
    if (_symbolFilter != null) {
      filtered = filtered
          .where((t) => t.symbol.toUpperCase() == _symbolFilter!.toUpperCase())
          .toList();
    }

    // Tag filter
    if (_tagFilter != null) {
      filtered = filtered.where((t) => t.tags.contains(_tagFilter)).toList();
    }

    // Outcome filter
    if (_outcomeFilter != null) {
      filtered = filtered.where((t) => t.outcome == _outcomeFilter).toList();
    }

    // Date range filter
    if (_dateRangeFilter != null) {
      filtered = filtered.where((t) {
        return t.entryDate.isAfter(
              _dateRangeFilter!.start.subtract(const Duration(days: 1)),
            ) &&
            t.entryDate.isBefore(
              _dateRangeFilter!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.symbol.toLowerCase().contains(_searchQuery) ||
            (t.notes?.toLowerCase().contains(_searchQuery) ?? false) ||
            t.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    return filtered;
  }

  // --- Error handling ---

  /// Clear the current error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh data - ALWAYS reload from local cache first (picks up chart trades immediately),
  /// then optionally sync from Firestore in background
  Future<void> refresh() async {
    if (_userId == null) {
      JournalDebug.journalLoad('REFRESH_SKIPPED', error: 'No user');
      return;
    }

    try {
      JournalDebug.start('TradeProvider.refresh');
      JournalDebug.journalLoad('REFRESH_START', userId: _userId);

      // STEP 1: ALWAYS reload from local Hive first (FAST - < 5ms)
      // This ensures chart trades that were just saved to Hive appear immediately
      final oldCount = _trades.length;
      _trades = _repository.getAllTrades(userId: _userId);
      final newCount = _trades.length;

      JournalDebug.journalLoad(
        'REFRESH_LOCAL_RELOAD',
        userId: _userId,
        tradeCount: newCount,
        source: 'Hive',
      );

      if (newCount != oldCount) {
        JournalDebug.journalLoad(
          'REFRESH_TRADE_COUNT_CHANGED',
          userId: _userId,
          tradeCount: newCount,
        );
      }

      notifyListeners(); // Update UI immediately with local data

      // STEP 2: Optionally sync from Firestore in background (if online)
      if (isFirebaseAvailable) {
        JournalDebug.journalLoad(
          'REFRESH_STARTING_BACKGROUND_SYNC',
          userId: _userId,
        );
        // Don't await - let it run in background
        _syncFromFirestoreInBackground(_userId!);
      }

      JournalDebug.end('TradeProvider.refresh', details: '$newCount trades');
      JournalDebug.journalLoad(
        'REFRESH_SUCCESS',
        userId: _userId,
        tradeCount: newCount,
      );
    } catch (e) {
      JournalDebug.end('TradeProvider.refresh', details: 'FAILED');
      JournalDebug.journalLoad(
        'REFRESH_ERROR',
        userId: _userId,
        error: e.toString(),
      );
    }
  }

  /// Full sync from Firestore (blocking)
  Future<void> fullSync() async {
    if (_userId != null && isFirebaseAvailable) {
      await _syncFromFirestoreInBackground(_userId!);
    }
  }

  /// Add a trade directly to the in-memory list and notify
  /// Used by PaperTradingProvider to immediately update UI
  void addTradeLocally(Trade trade) {
    _trades.insert(0, trade);
    notifyListeners();
  }

  /// Clear all trades from the database (admin function)
  Future<bool> clearAllTrades() async {
    try {
      await _repository.clearAll();
      _trades = [];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to clear trades: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Migrate orphan trades (trades without userId) to current user
  /// Returns the number of trades migrated
  Future<int> migrateOrphanTrades() async {
    if (_userId == null) {
      Log.w('Cannot migrate trades: no user logged in');
      return 0;
    }

    try {
      await _repository.init();

      // Find trades without userId
      final orphanTrades = _repository.getAllTrades(userId: null);
      Log.d('Found ${orphanTrades.length} orphan trades to migrate');

      if (orphanTrades.isEmpty) return 0;

      int migratedCount = 0;
      for (final trade in orphanTrades) {
        // Assign current user as owner
        final migratedTrade = trade.copyWith(userId: _userId);

        // Update in local storage
        await _repository.updateTrade(migratedTrade);

        // Sync to Firestore
        if (isFirebaseAvailable) {
          await _syncService.saveTrade(migratedTrade);
        }

        migratedCount++;
      }

      Log.i('Migrated $migratedCount orphan trades to user: $_userId');

      // Refresh to show migrated trades
      await refresh();

      return migratedCount;
    } catch (e) {
      Log.e('Failed to migrate orphan trades', e);
      return 0;
    }
  }

  /// Delete all orphan trades (trades without userId)
  /// Use this to clean up test/demo data
  Future<int> deleteOrphanTrades() async {
    try {
      await _repository.init();

      final orphanTrades = _repository.getAllTrades(userId: null);
      Log.d('Found ${orphanTrades.length} orphan trades to delete');

      for (final trade in orphanTrades) {
        await _repository.deleteTrade(trade.id);
      }

      Log.i('Deleted ${orphanTrades.length} orphan trades');
      return orphanTrades.length;
    } catch (e) {
      Log.e('Failed to delete orphan trades', e);
      return 0;
    }
  }
}

/// Date range for filtering
class DateTimeRange {
  final DateTime start;
  final DateTime end;

  const DateTimeRange({required this.start, required this.end});
}

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/trade.dart';
import '../services/trade_repository.dart';
import '../services/analytics_service.dart';

/// State management for trades using ChangeNotifier
/// 
/// Provides access to trade data and operations throughout the app.
/// Notifies listeners when data changes for automatic UI updates.
class TradeProvider extends ChangeNotifier {
  final TradeRepository _repository;
  final Uuid _uuid = const Uuid();
  
  List<Trade> _trades = [];
  bool _isLoading = false;
  String? _error;
  
  // Filter state
  String? _symbolFilter;
  String? _tagFilter;
  TradeOutcome? _outcomeFilter;
  DateTimeRange? _dateRangeFilter;
  String _searchQuery = '';
  
  TradeProvider(this._repository);
  
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
  double get riskRewardRatio => AnalyticsService.calculateRiskRewardRatio(_trades);
  TradeCountStats get tradeStats => AnalyticsService.getTradeCountStats(_trades);
  List<EquityPoint> get equityCurve => AnalyticsService.generateEquityCurve(_trades);
  
  // --- Initialization ---
  
  /// Initialize the provider and load trades from storage
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _repository.init();
      _trades = _repository.getAllTrades();
      _error = null;
    } catch (e) {
      _error = 'Failed to load trades: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // --- CRUD Operations ---
  
  /// Add a new trade
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
      );
      
      await _repository.addTrade(trade);
      _trades = _repository.getAllTrades();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add trade: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  /// Update an existing trade
  Future<bool> updateTrade(Trade trade) async {
    try {
      final updatedTrade = trade.copyWith(updatedAt: DateTime.now());
      await _repository.updateTrade(updatedTrade);
      _trades = _repository.getAllTrades();
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
  Future<bool> deleteTrade(String id) async {
    try {
      await _repository.deleteTrade(id);
      _trades = _repository.getAllTrades();
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
  Future<bool> closeTrade(String id, double exitPrice, DateTime exitDate) async {
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
              _dateRangeFilter!.start.subtract(const Duration(days: 1))) &&
            t.entryDate.isBefore(
              _dateRangeFilter!.end.add(const Duration(days: 1)));
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
  
  /// Refresh data from storage
  Future<void> refresh() async {
    await init();
  }
}

/// Date range for filtering
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  
  const DateTimeRange({required this.start, required this.end});
}


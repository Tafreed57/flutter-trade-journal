import '../models/trade.dart';

/// Analytics calculations for trade data
/// 
/// Pure functions that calculate various trading metrics.
/// Designed to be testable and decoupled from UI.
class AnalyticsService {
  /// Calculate win rate as a percentage (0-100)
  /// Only considers closed trades (excludes open positions)
  static double calculateWinRate(List<Trade> trades) {
    final closedTrades = trades.where((t) => t.isClosed).toList();
    if (closedTrades.isEmpty) return 0;
    
    final wins = closedTrades.where((t) => t.outcome == TradeOutcome.win).length;
    return (wins / closedTrades.length) * 100;
  }
  
  /// Calculate total P&L across all closed trades
  static double calculateTotalPnL(List<Trade> trades) {
    return trades
        .where((t) => t.isClosed)
        .fold(0.0, (sum, t) => sum + (t.profitLoss ?? 0));
  }
  
  /// Calculate average P&L per trade
  static double calculateAveragePnL(List<Trade> trades) {
    final closedTrades = trades.where((t) => t.isClosed).toList();
    if (closedTrades.isEmpty) return 0;
    
    final totalPnL = calculateTotalPnL(closedTrades);
    return totalPnL / closedTrades.length;
  }
  
  /// Calculate average winning trade
  static double calculateAverageWin(List<Trade> trades) {
    final winningTrades = trades
        .where((t) => t.outcome == TradeOutcome.win)
        .toList();
    if (winningTrades.isEmpty) return 0;
    
    final totalWins = winningTrades.fold(0.0, (sum, t) => sum + (t.profitLoss ?? 0));
    return totalWins / winningTrades.length;
  }
  
  /// Calculate average losing trade
  static double calculateAverageLoss(List<Trade> trades) {
    final losingTrades = trades
        .where((t) => t.outcome == TradeOutcome.loss)
        .toList();
    if (losingTrades.isEmpty) return 0;
    
    final totalLosses = losingTrades.fold(0.0, (sum, t) => sum + (t.profitLoss ?? 0));
    return totalLosses / losingTrades.length;
  }
  
  /// Calculate profit factor (gross profit / gross loss)
  /// Returns infinity if no losses, 0 if no profits
  static double calculateProfitFactor(List<Trade> trades) {
    final grossProfit = trades
        .where((t) => t.outcome == TradeOutcome.win)
        .fold(0.0, (sum, t) => sum + (t.profitLoss ?? 0));
    
    final grossLoss = trades
        .where((t) => t.outcome == TradeOutcome.loss)
        .fold(0.0, (sum, t) => sum + (t.profitLoss ?? 0).abs());
    
    if (grossLoss == 0) return grossProfit > 0 ? double.infinity : 0;
    return grossProfit / grossLoss;
  }
  
  /// Calculate risk-reward ratio based on average win/loss
  static double calculateRiskRewardRatio(List<Trade> trades) {
    final avgWin = calculateAverageWin(trades);
    final avgLoss = calculateAverageLoss(trades).abs();
    
    if (avgLoss == 0) return avgWin > 0 ? double.infinity : 0;
    return avgWin / avgLoss;
  }
  
  /// Calculate largest winning trade
  static double calculateLargestWin(List<Trade> trades) {
    final winningTrades = trades.where((t) => t.outcome == TradeOutcome.win);
    if (winningTrades.isEmpty) return 0;
    
    return winningTrades
        .map((t) => t.profitLoss ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }
  
  /// Calculate largest losing trade
  static double calculateLargestLoss(List<Trade> trades) {
    final losingTrades = trades.where((t) => t.outcome == TradeOutcome.loss);
    if (losingTrades.isEmpty) return 0;
    
    return losingTrades
        .map((t) => t.profitLoss ?? 0)
        .reduce((a, b) => a < b ? a : b);
  }
  
  /// Get trade count statistics
  static TradeCountStats getTradeCountStats(List<Trade> trades) {
    final closed = trades.where((t) => t.isClosed).toList();
    return TradeCountStats(
      total: trades.length,
      open: trades.length - closed.length,
      wins: closed.where((t) => t.outcome == TradeOutcome.win).length,
      losses: closed.where((t) => t.outcome == TradeOutcome.loss).length,
      breakeven: closed.where((t) => t.outcome == TradeOutcome.breakeven).length,
    );
  }
  
  /// Generate equity curve data points (cumulative P&L over time)
  /// Returns list of (date, cumulative P&L) pairs
  static List<EquityPoint> generateEquityCurve(List<Trade> trades) {
    final closedTrades = trades
        .where((t) => t.isClosed && t.exitDate != null)
        .toList()
      ..sort((a, b) => a.exitDate!.compareTo(b.exitDate!));
    
    if (closedTrades.isEmpty) return [];
    
    final points = <EquityPoint>[];
    double cumulative = 0;
    
    for (final trade in closedTrades) {
      cumulative += trade.profitLoss ?? 0;
      points.add(EquityPoint(
        date: trade.exitDate!,
        equity: cumulative,
      ));
    }
    
    return points;
  }
  
  /// Get P&L breakdown by symbol
  static Map<String, double> getPnLBySymbol(List<Trade> trades) {
    final pnlBySymbol = <String, double>{};
    
    for (final trade in trades.where((t) => t.isClosed)) {
      final symbol = trade.symbol.toUpperCase();
      pnlBySymbol[symbol] = (pnlBySymbol[symbol] ?? 0) + (trade.profitLoss ?? 0);
    }
    
    return pnlBySymbol;
  }
  
  /// Get trade count by symbol
  static Map<String, int> getTradeCountBySymbol(List<Trade> trades) {
    final countBySymbol = <String, int>{};
    
    for (final trade in trades) {
      final symbol = trade.symbol.toUpperCase();
      countBySymbol[symbol] = (countBySymbol[symbol] ?? 0) + 1;
    }
    
    return countBySymbol;
  }
}

/// Trade count statistics
class TradeCountStats {
  final int total;
  final int open;
  final int wins;
  final int losses;
  final int breakeven;
  
  const TradeCountStats({
    required this.total,
    required this.open,
    required this.wins,
    required this.losses,
    required this.breakeven,
  });
  
  int get closed => wins + losses + breakeven;
}

/// Point on the equity curve
class EquityPoint {
  final DateTime date;
  final double equity;
  
  const EquityPoint({
    required this.date,
    required this.equity,
  });
}


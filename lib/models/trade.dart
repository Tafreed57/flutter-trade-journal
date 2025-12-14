import 'package:hive/hive.dart';

part 'trade.g.dart';

/// Represents the side of a trade (buy/sell or long/short)
@HiveType(typeId: 0)
enum TradeSide {
  @HiveField(0)
  long,
  
  @HiveField(1)
  short,
}

/// Represents the outcome of a trade
@HiveType(typeId: 1)
enum TradeOutcome {
  @HiveField(0)
  win,
  
  @HiveField(1)
  loss,
  
  @HiveField(2)
  breakeven,
  
  @HiveField(3)
  open, // Trade still in progress
}

/// Core trade model for the journal
/// 
/// Stores all relevant information about a single trade including
/// entry/exit prices, dates, and calculated P&L.
@HiveType(typeId: 2)
class Trade extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String symbol;
  
  @HiveField(2)
  final TradeSide side;
  
  @HiveField(3)
  final double quantity;
  
  @HiveField(4)
  final double entryPrice;
  
  @HiveField(5)
  final double? exitPrice;
  
  @HiveField(6)
  final DateTime entryDate;
  
  @HiveField(7)
  final DateTime? exitDate;
  
  @HiveField(8)
  final List<String> tags;
  
  @HiveField(9)
  final String? notes;
  
  @HiveField(10)
  final DateTime createdAt;
  
  @HiveField(11)
  final DateTime updatedAt;
  
  Trade({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    this.exitPrice,
    required this.entryDate,
    this.exitDate,
    List<String>? tags,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Whether the trade has been closed (has exit price)
  bool get isClosed => exitPrice != null;
  
  /// Calculate P&L in absolute terms
  /// Returns null if trade is still open
  double? get profitLoss {
    if (exitPrice == null) return null;
    
    final priceDiff = exitPrice! - entryPrice;
    final multiplier = side == TradeSide.long ? 1 : -1;
    return priceDiff * quantity * multiplier;
  }
  
  /// Calculate P&L as percentage
  double? get profitLossPercent {
    if (exitPrice == null) return null;
    
    final priceDiff = exitPrice! - entryPrice;
    final percentChange = (priceDiff / entryPrice) * 100;
    return side == TradeSide.long ? percentChange : -percentChange;
  }
  
  /// Determine the outcome of the trade
  TradeOutcome get outcome {
    if (!isClosed) return TradeOutcome.open;
    
    final pnl = profitLoss!;
    if (pnl > 0) return TradeOutcome.win;
    if (pnl < 0) return TradeOutcome.loss;
    return TradeOutcome.breakeven;
  }
  
  /// Create a copy of this trade with updated fields
  Trade copyWith({
    String? id,
    String? symbol,
    TradeSide? side,
    double? quantity,
    double? entryPrice,
    double? exitPrice,
    DateTime? entryDate,
    DateTime? exitDate,
    List<String>? tags,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trade(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      entryPrice: entryPrice ?? this.entryPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      entryDate: entryDate ?? this.entryDate,
      exitDate: exitDate ?? this.exitDate,
      tags: tags ?? List.from(this.tags),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  @override
  String toString() {
    return 'Trade(id: $id, symbol: $symbol, side: $side, qty: $quantity, '
           'entry: $entryPrice, exit: $exitPrice, pnl: $profitLoss)';
  }
}


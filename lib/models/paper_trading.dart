import 'package:hive/hive.dart';

part 'paper_trading.g.dart';

/// Paper trading account holding balance and P&L tracking
@HiveType(typeId: 10)
class PaperAccount extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  double balance;

  @HiveField(2)
  final double initialBalance;

  @HiveField(3)
  double realizedPnL;

  @HiveField(4)
  final DateTime createdAt;

  PaperAccount({
    required this.id,
    required this.balance,
    required this.initialBalance,
    this.realizedPnL = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Total return as percentage
  double get totalReturnPercent =>
      ((balance - initialBalance) / initialBalance) * 100;

  /// Account equity (balance + unrealized P&L from positions)
  double equity(double unrealizedPnL) => balance + unrealizedPnL;

  PaperAccount copyWith({
    String? id,
    double? balance,
    double? initialBalance,
    double? realizedPnL,
    DateTime? createdAt,
  }) {
    return PaperAccount(
      id: id ?? this.id,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      realizedPnL: realizedPnL ?? this.realizedPnL,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Order side (buy or sell)
@HiveType(typeId: 11)
enum OrderSide {
  @HiveField(0)
  buy,

  @HiveField(1)
  sell,
}

/// Order type
@HiveType(typeId: 12)
enum OrderType {
  @HiveField(0)
  market,

  @HiveField(1)
  limit,
}

/// Order status
@HiveType(typeId: 13)
enum OrderStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  filled,

  @HiveField(2)
  cancelled,

  @HiveField(3)
  rejected,
}

/// A paper trading order
@HiveType(typeId: 14)
class PaperOrder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String symbol;

  @HiveField(2)
  final OrderSide side;

  @HiveField(3)
  final OrderType type;

  @HiveField(4)
  final double quantity;

  @HiveField(5)
  final double? limitPrice;

  @HiveField(6)
  OrderStatus status;

  @HiveField(7)
  double? filledPrice;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  DateTime? filledAt;

  PaperOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    this.limitPrice,
    this.status = OrderStatus.pending,
    this.filledPrice,
    DateTime? createdAt,
    this.filledAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Total value of the order (quantity * price)
  double get value => quantity * (filledPrice ?? limitPrice ?? 0);

  bool get isBuy => side == OrderSide.buy;
  bool get isSell => side == OrderSide.sell;
  bool get isMarket => type == OrderType.market;
  bool get isLimit => type == OrderType.limit;
  bool get isFilled => status == OrderStatus.filled;
  bool get isPending => status == OrderStatus.pending;
}

/// An open paper trading position
@HiveType(typeId: 15)
class PaperPosition extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String symbol;

  @HiveField(2)
  final OrderSide side;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  double entryPrice;

  @HiveField(5)
  double? stopLoss;

  @HiveField(6)
  double? takeProfit;

  @HiveField(7)
  final DateTime openedAt;

  @HiveField(8)
  DateTime? closedAt;

  @HiveField(9)
  double? exitPrice;

  @HiveField(10)
  double? realizedPnL;

  PaperPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    this.stopLoss,
    this.takeProfit,
    DateTime? openedAt,
    this.closedAt,
    this.exitPrice,
    this.realizedPnL,
  }) : openedAt = openedAt ?? DateTime.now();

  /// Whether this is a long position
  bool get isLong => side == OrderSide.buy;

  /// Whether this is a short position
  bool get isShort => side == OrderSide.sell;

  /// Whether the position is still open
  bool get isOpen => closedAt == null;

  /// Whether the position has been closed
  bool get isClosed => closedAt != null;

  /// Calculate unrealized P&L given current price
  double unrealizedPnL(double currentPrice) {
    final priceDiff = currentPrice - entryPrice;
    final multiplier = isLong ? 1 : -1;
    return priceDiff * quantity * multiplier;
  }

  /// Calculate unrealized P&L as percentage
  double unrealizedPnLPercent(double currentPrice) {
    final pnl = unrealizedPnL(currentPrice);
    return (pnl / (entryPrice * quantity)) * 100;
  }

  /// Calculate the notional value of the position
  double get notionalValue => entryPrice * quantity;

  /// Check if stop loss should trigger
  bool shouldTriggerStopLoss(double currentPrice) {
    if (stopLoss == null) return false;
    if (isLong) return currentPrice <= stopLoss!;
    return currentPrice >= stopLoss!;
  }

  /// Check if take profit should trigger
  bool shouldTriggerTakeProfit(double currentPrice) {
    if (takeProfit == null) return false;
    if (isLong) return currentPrice >= takeProfit!;
    return currentPrice <= takeProfit!;
  }

  PaperPosition copyWith({
    String? id,
    String? symbol,
    OrderSide? side,
    double? quantity,
    double? entryPrice,
    double? stopLoss,
    double? takeProfit,
    DateTime? openedAt,
    DateTime? closedAt,
    double? exitPrice,
    double? realizedPnL,
  }) {
    return PaperPosition(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      quantity: quantity ?? this.quantity,
      entryPrice: entryPrice ?? this.entryPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      exitPrice: exitPrice ?? this.exitPrice,
      realizedPnL: realizedPnL ?? this.realizedPnL,
    );
  }
}

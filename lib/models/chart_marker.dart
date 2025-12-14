import 'package:flutter/material.dart';
import 'trade.dart';
import 'paper_trading.dart';

/// Types of markers that can appear on the chart
enum MarkerType {
  /// Buy entry (long position opened)
  buyEntry,
  
  /// Sell entry (short position opened)
  sellEntry,
  
  /// Position closed with profit
  exitProfit,
  
  /// Position closed with loss
  exitLoss,
  
  /// Stop loss triggered
  stopLoss,
  
  /// Take profit triggered
  takeProfit,
}

/// A marker to be displayed on the chart at a specific price/time
class ChartMarker {
  final String id;
  final DateTime timestamp;
  final double price;
  final MarkerType type;
  final String? label;
  final String? tradeId;
  final double? pnl;

  const ChartMarker({
    required this.id,
    required this.timestamp,
    required this.price,
    required this.type,
    this.label,
    this.tradeId,
    this.pnl,
  });

  /// Get the color for this marker type
  Color get color {
    switch (type) {
      case MarkerType.buyEntry:
        return const Color(0xFF00E676); // Green
      case MarkerType.sellEntry:
        return const Color(0xFFFF5252); // Red
      case MarkerType.exitProfit:
      case MarkerType.takeProfit:
        return const Color(0xFF00E676); // Green
      case MarkerType.exitLoss:
      case MarkerType.stopLoss:
        return const Color(0xFFFF5252); // Red
    }
  }

  /// Get the icon for this marker type
  IconData get icon {
    switch (type) {
      case MarkerType.buyEntry:
        return Icons.arrow_upward_rounded;
      case MarkerType.sellEntry:
        return Icons.arrow_downward_rounded;
      case MarkerType.exitProfit:
      case MarkerType.takeProfit:
        return Icons.check_circle_rounded;
      case MarkerType.exitLoss:
      case MarkerType.stopLoss:
        return Icons.cancel_rounded;
    }
  }

  /// Whether this is an entry marker
  bool get isEntry => type == MarkerType.buyEntry || type == MarkerType.sellEntry;

  /// Whether this is an exit marker
  bool get isExit => !isEntry;

  /// Create markers from a closed Trade
  static List<ChartMarker> fromTrade(Trade trade) {
    final markers = <ChartMarker>[];
    
    // Entry marker
    markers.add(ChartMarker(
      id: '${trade.id}_entry',
      timestamp: trade.entryDate,
      price: trade.entryPrice,
      type: trade.side == TradeSide.long ? MarkerType.buyEntry : MarkerType.sellEntry,
      label: trade.side == TradeSide.long ? 'BUY' : 'SELL',
      tradeId: trade.id,
    ));
    
    // Exit marker (if trade is closed)
    if (trade.isClosed && trade.exitDate != null && trade.exitPrice != null) {
      final isProfit = (trade.profitLoss ?? 0) >= 0;
      markers.add(ChartMarker(
        id: '${trade.id}_exit',
        timestamp: trade.exitDate!,
        price: trade.exitPrice!,
        type: isProfit ? MarkerType.exitProfit : MarkerType.exitLoss,
        label: isProfit ? 'TP' : 'SL',
        tradeId: trade.id,
        pnl: trade.profitLoss,
      ));
    }
    
    return markers;
  }

  /// Create markers from an open PaperPosition
  static List<ChartMarker> fromPosition(PaperPosition position) {
    final markers = <ChartMarker>[];
    
    // Entry marker
    markers.add(ChartMarker(
      id: '${position.id}_entry',
      timestamp: position.openedAt,
      price: position.entryPrice,
      type: position.isLong ? MarkerType.buyEntry : MarkerType.sellEntry,
      label: position.isLong ? 'LONG' : 'SHORT',
      tradeId: position.id,
    ));
    
    // Exit marker (if closed)
    if (position.isClosed && position.exitPrice != null) {
      final isProfit = (position.realizedPnL ?? 0) >= 0;
      markers.add(ChartMarker(
        id: '${position.id}_exit',
        timestamp: position.closedAt!,
        price: position.exitPrice!,
        type: isProfit ? MarkerType.exitProfit : MarkerType.exitLoss,
        label: isProfit ? 'WIN' : 'LOSS',
        tradeId: position.id,
        pnl: position.realizedPnL,
      ));
    }
    
    return markers;
  }
}

/// Horizontal line to be drawn on the chart (for SL/TP visualization)
class ChartLine {
  final String id;
  final double price;
  final Color color;
  final String? label;
  final bool isDashed;

  const ChartLine({
    required this.id,
    required this.price,
    required this.color,
    this.label,
    this.isDashed = true,
  });

  /// Create lines from an open position (entry, SL, TP)
  static List<ChartLine> fromPosition(PaperPosition position) {
    final lines = <ChartLine>[];
    
    // Entry line
    lines.add(ChartLine(
      id: '${position.id}_entry',
      price: position.entryPrice,
      color: position.isLong 
          ? const Color(0xFF00E676) 
          : const Color(0xFFFF5252),
      label: 'Entry ${position.entryPrice.toStringAsFixed(2)}',
      isDashed: false,
    ));
    
    // Stop loss line
    if (position.stopLoss != null) {
      lines.add(ChartLine(
        id: '${position.id}_sl',
        price: position.stopLoss!,
        color: const Color(0xFFFF5252),
        label: 'SL ${position.stopLoss!.toStringAsFixed(2)}',
      ));
    }
    
    // Take profit line
    if (position.takeProfit != null) {
      lines.add(ChartLine(
        id: '${position.id}_tp',
        price: position.takeProfit!,
        color: const Color(0xFF00E676),
        label: 'TP ${position.takeProfit!.toStringAsFixed(2)}',
      ));
    }
    
    return lines;
  }
}


import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trade.dart';

/// Service for exporting trade data to various formats
/// 
/// Currently supports:
/// - CSV export (for spreadsheets)
/// - JSON export (for backups/imports)
class ExportService {
  /// Export trades to CSV format
  /// 
  /// Returns the file path of the exported file
  static Future<String> exportToCSV(List<Trade> trades) async {
    final buffer = StringBuffer();
    
    // Header row
    buffer.writeln(
      'ID,Symbol,Side,Quantity,Entry Price,Exit Price,'
      'Entry Date,Exit Date,P&L,P&L %,Outcome,Tags,Notes,Created,Updated'
    );
    
    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    for (final trade in trades) {
      final row = [
        _escapeCSV(trade.id),
        _escapeCSV(trade.symbol),
        trade.side == TradeSide.long ? 'LONG' : 'SHORT',
        trade.quantity.toString(),
        trade.entryPrice.toStringAsFixed(2),
        trade.exitPrice?.toStringAsFixed(2) ?? '',
        dateFormat.format(trade.entryDate),
        trade.exitDate != null ? dateFormat.format(trade.exitDate!) : '',
        trade.profitLoss?.toStringAsFixed(2) ?? '',
        trade.profitLossPercent?.toStringAsFixed(2) ?? '',
        trade.outcome.name.toUpperCase(),
        _escapeCSV(trade.tags.join('; ')),
        _escapeCSV(trade.notes ?? ''),
        dateFormat.format(trade.createdAt),
        dateFormat.format(trade.updatedAt),
      ];
      
      buffer.writeln(row.join(','));
    }
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/trades_export_$timestamp.csv';
    
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    
    return filePath;
  }
  
  /// Export trades to JSON format
  /// 
  /// Returns the file path of the exported file
  static Future<String> exportToJSON(List<Trade> trades) async {
    final jsonList = trades.map((t) => _tradeToJson(t)).toList();
    final jsonString = '{\n  "trades": ${_jsonEncode(jsonList)}\n}';
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/trades_export_$timestamp.json';
    
    final file = File(filePath);
    await file.writeAsString(jsonString);
    
    return filePath;
  }
  
  /// Generate summary statistics as text
  static String generateSummary(List<Trade> trades) {
    final closed = trades.where((t) => t.isClosed).toList();
    final wins = closed.where((t) => t.outcome == TradeOutcome.win).length;
    final losses = closed.where((t) => t.outcome == TradeOutcome.loss).length;
    
    double totalPnL = 0;
    double grossProfit = 0;
    double grossLoss = 0;
    
    for (final t in closed) {
      final pnl = t.profitLoss ?? 0;
      totalPnL += pnl;
      if (pnl > 0) {
        grossProfit += pnl;
      } else {
        grossLoss += pnl.abs();
      }
    }
    
    final winRate = closed.isNotEmpty ? (wins / closed.length) * 100 : 0;
    final profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;
    
    return '''
Trading Journal Summary
=======================
Generated: ${DateFormat('MMMM d, yyyy HH:mm').format(DateTime.now())}

Total Trades: ${trades.length}
Closed Trades: ${closed.length}
Open Trades: ${trades.length - closed.length}

Performance:
- Wins: $wins
- Losses: $losses
- Win Rate: ${winRate.toStringAsFixed(1)}%
- Total P&L: \$${totalPnL.toStringAsFixed(2)}
- Profit Factor: ${profitFactor.toStringAsFixed(2)}
''';
  }
  
  // Helper to escape CSV values
  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
  
  // Simple JSON encoding
  static Map<String, dynamic> _tradeToJson(Trade t) {
    return {
      'id': t.id,
      'symbol': t.symbol,
      'side': t.side == TradeSide.long ? 'long' : 'short',
      'quantity': t.quantity,
      'entryPrice': t.entryPrice,
      'exitPrice': t.exitPrice,
      'entryDate': t.entryDate.toIso8601String(),
      'exitDate': t.exitDate?.toIso8601String(),
      'pnl': t.profitLoss,
      'pnlPercent': t.profitLossPercent,
      'outcome': t.outcome.name,
      'tags': t.tags,
      'notes': t.notes,
      'createdAt': t.createdAt.toIso8601String(),
      'updatedAt': t.updatedAt.toIso8601String(),
    };
  }
  
  static String _jsonEncode(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer('[\n');
    for (int i = 0; i < list.length; i++) {
      buffer.write('    ${_mapToJson(list[i])}');
      if (i < list.length - 1) buffer.write(',');
      buffer.writeln();
    }
    buffer.write('  ]');
    return buffer.toString();
  }
  
  static String _mapToJson(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final value = e.value;
      String jsonValue;
      if (value == null) {
        jsonValue = 'null';
      } else if (value is String) {
        jsonValue = '"${value.replaceAll('"', '\\"')}"';
      } else if (value is List) {
        jsonValue = '[${value.map((v) => '"$v"').join(', ')}]';
      } else {
        jsonValue = value.toString();
      }
      return '"${e.key}": $jsonValue';
    });
    return '{${entries.join(', ')}}';
  }
}


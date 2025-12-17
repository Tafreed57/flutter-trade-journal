import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/logger.dart';
import '../models/chart_drawing.dart';

/// Repository for persisting chart drawings using Hive with JSON serialization
/// 
/// Since drawings have complex nested types (ChartPoint, Color, etc.),
/// we serialize them to JSON for storage rather than creating Hive adapters
/// for all nested types.
class DrawingRepository {
  static const String _boxName = 'chart_drawings';
  
  Box<String>? _box; // Store as JSON strings
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the repository
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _box = await Hive.openBox<String>(_boxName);
      _isInitialized = true;
      Log.i('DrawingRepository initialized');
    } catch (e) {
      Log.e('Failed to initialize DrawingRepository', e);
      rethrow;
    }
  }
  
  /// Get all saved position tools
  List<PositionToolDrawing> getPositionTools({String? userId, String? symbol}) {
    if (_box == null) return [];
    
    final tools = <PositionToolDrawing>[];
    
    for (final json in _box!.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        final tool = _positionToolFromJson(map);
        
        // Filter by userId if provided
        if (userId != null && map['userId'] != userId) continue;
        
        // Filter by symbol if provided
        if (symbol != null && tool.symbol != symbol) continue;
        
        tools.add(tool);
      } catch (e) {
        Log.e('Failed to deserialize drawing', e);
      }
    }
    
    return tools;
  }
  
  /// Save a position tool
  Future<void> savePositionTool(PositionToolDrawing tool, {String? userId}) async {
    if (_box == null) {
      throw StateError('DrawingRepository not initialized');
    }
    
    final json = jsonEncode(_positionToolToJson(tool, userId: userId));
    await _box!.put(tool.id, json);
    Log.trade('Saved position tool: ${tool.id}');
  }
  
  /// Save multiple position tools
  Future<void> savePositionTools(List<PositionToolDrawing> tools, {String? userId}) async {
    for (final tool in tools) {
      await savePositionTool(tool, userId: userId);
    }
  }
  
  /// Delete a position tool
  Future<void> deletePositionTool(String id) async {
    if (_box == null) return;
    await _box!.delete(id);
    Log.trade('Deleted position tool: $id');
  }
  
  /// Clear all position tools
  Future<void> clearAll({String? userId}) async {
    if (_box == null) return;
    
    if (userId == null) {
      await _box!.clear();
    } else {
      // Only delete drawings for this user
      final keysToDelete = <String>[];
      for (final entry in _box!.toMap().entries) {
        try {
          final map = jsonDecode(entry.value) as Map<String, dynamic>;
          if (map['userId'] == userId) {
            keysToDelete.add(entry.key);
          }
        } catch (_) {}
      }
      await _box!.deleteAll(keysToDelete);
    }
    Log.trade('Cleared position tools');
  }
  
  /// Close the repository
  Future<void> close() async {
    await _box?.close();
    _isInitialized = false;
  }
  
  // ==================== JSON SERIALIZATION ====================
  
  Map<String, dynamic> _positionToolToJson(PositionToolDrawing tool, {String? userId}) {
    return {
      'id': tool.id,
      'type': 'positionTool',
      'symbol': tool.symbol,
      'isLong': tool.isLong,
      'entryTimestamp': tool.entryPoint.timestamp.toIso8601String(),
      'entryPrice': tool.entryPrice,
      'endTime': tool.endTime.toIso8601String(),
      'stopLossPrice': tool.stopLossPrice,
      'takeProfitPrice': tool.takeProfitPrice,
      'quantity': tool.quantity,
      'status': tool.status.index,
      'linkedPositionId': tool.linkedPositionId,
      'exitPrice': tool.exitPrice,
      'realizedPnL': tool.realizedPnL,
      'createdAt': tool.createdAt.toIso8601String(),
      'updatedAt': tool.updatedAt.toIso8601String(),
      'isSelected': tool.isSelected,
      'isComplete': tool.isComplete,
      'userId': userId,
    };
  }
  
  PositionToolDrawing _positionToolFromJson(Map<String, dynamic> json) {
    return PositionToolDrawing(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      isLong: json['isLong'] as bool,
      entryPoint: ChartPoint(
        timestamp: DateTime.parse(json['entryTimestamp'] as String),
        price: (json['entryPrice'] as num).toDouble(),
      ),
      endTime: DateTime.parse(json['endTime'] as String),
      stopLossPrice: (json['stopLossPrice'] as num).toDouble(),
      takeProfitPrice: (json['takeProfitPrice'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      status: PositionToolStatus.values[json['status'] as int? ?? 0],
      linkedPositionId: json['linkedPositionId'] as String?,
      exitPrice: (json['exitPrice'] as num?)?.toDouble(),
      realizedPnL: (json['realizedPnL'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isSelected: json['isSelected'] as bool? ?? false,
      isComplete: json['isComplete'] as bool? ?? true,
    );
  }
}


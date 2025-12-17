import 'package:flutter/material.dart';
import '../core/logger.dart';
import '../models/chart_drawing.dart';
import '../services/drawing_repository.dart';

/// State management for chart drawing tools
/// 
/// Manages:
/// - Current selected tool
/// - All drawings on the chart
/// - Drawing in progress
/// - Selection state
/// - Position tools (Long/Short with SL/TP)
/// - Persistence of position tools across restarts
class ChartDrawingProvider extends ChangeNotifier {
  final DrawingRepository _repository = DrawingRepository();
  
  DrawingToolType _currentTool = DrawingToolType.none;
  final List<ChartDrawing> _drawings = [];
  ChartDrawing? _activeDrawing;
  String? _selectedDrawingId;
  Color _currentColor = const Color(0xFF00E5FF);
  double _currentStrokeWidth = 1.5;
  
  // Position tool settings
  double _defaultSlPercent = 2.0;  // Default stop loss percentage
  double _defaultTpPercent = 4.0;  // Default take profit percentage (2:1 R:R)
  double _defaultQuantity = 1.0;
  
  // State
  bool _isInitialized = false;
  String? _userId;
  
  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Initialize the provider and load saved drawings
  Future<void> init({String? userId}) async {
    if (_isInitialized) return;
    
    try {
      _userId = userId;
      await _repository.init();
      
      // Load saved position tools
      final savedTools = _repository.getPositionTools(userId: userId);
      if (savedTools.isNotEmpty) {
        _drawings.addAll(savedTools);
        Log.i('Restored ${savedTools.length} position tools from storage');
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      Log.e('Failed to initialize ChartDrawingProvider', e);
    }
  }
  
  /// Save all position tools to storage
  Future<void> _savePositionTools() async {
    if (!_repository.isInitialized) return;
    
    try {
      // Clear existing and save current position tools
      await _repository.clearAll(userId: _userId);
      await _repository.savePositionTools(positionTools, userId: _userId);
    } catch (e) {
      Log.e('Failed to save position tools', e);
    }
  }

  // Getters
  DrawingToolType get currentTool => _currentTool;
  List<ChartDrawing> get drawings => List.unmodifiable(_drawings);
  ChartDrawing? get activeDrawing => _activeDrawing;
  String? get selectedDrawingId => _selectedDrawingId;
  Color get currentColor => _currentColor;
  double get currentStrokeWidth => _currentStrokeWidth;
  bool get isDrawing => _currentTool != DrawingToolType.none;
  
  // Position tool getters
  double get defaultSlPercent => _defaultSlPercent;
  double get defaultTpPercent => _defaultTpPercent;
  double get defaultQuantity => _defaultQuantity;
  
  /// Get all position tool drawings
  List<PositionToolDrawing> get positionTools => 
      _drawings.whereType<PositionToolDrawing>().toList();
  
  /// Get active position tools only
  List<PositionToolDrawing> get activePositionTools =>
      positionTools.where((p) => p.status == PositionToolStatus.active).toList();

  /// Set the current drawing tool
  void setTool(DrawingToolType tool) {
    _currentTool = tool;
    _activeDrawing = null;
    _selectedDrawingId = null;
    notifyListeners();
  }

  /// Set drawing color
  void setColor(Color color) {
    _currentColor = color;
    
    // Update selected drawing if any
    if (_selectedDrawingId != null) {
      final index = _drawings.indexWhere((d) => d.id == _selectedDrawingId);
      if (index != -1) {
        _drawings[index] = _drawings[index].copyWith(color: color);
      }
    }
    
    notifyListeners();
  }

  /// Set stroke width
  void setStrokeWidth(double width) {
    _currentStrokeWidth = width;
    
    // Update selected drawing if any
    if (_selectedDrawingId != null) {
      final index = _drawings.indexWhere((d) => d.id == _selectedDrawingId);
      if (index != -1) {
        _drawings[index] = _drawings[index].copyWith(strokeWidth: width);
      }
    }
    
    notifyListeners();
  }

  /// Start a new drawing at the given point
  void startDrawing(ChartPoint point) {
    switch (_currentTool) {
      case DrawingToolType.none:
        return;
        
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
        _activeDrawing = TrendLineDrawing(
          startPoint: point,
          color: _currentColor,
          strokeWidth: _currentStrokeWidth,
        );
        break;
        
      case DrawingToolType.horizontalLine:
        _activeDrawing = HorizontalLineDrawing(
          price: point.price,
          color: _currentColor,
          strokeWidth: _currentStrokeWidth,
          isComplete: true,
        );
        _completeDrawing();
        return;
        
      case DrawingToolType.verticalLine:
        _activeDrawing = VerticalLineDrawing(
          timestamp: point.timestamp,
          color: _currentColor,
          strokeWidth: _currentStrokeWidth,
          isComplete: true,
        );
        _completeDrawing();
        return;
        
      case DrawingToolType.fibonacciRetracement:
        _activeDrawing = FibonacciDrawing(
          startPoint: point,
          color: _currentColor,
          strokeWidth: _currentStrokeWidth,
        );
        break;
        
      case DrawingToolType.rectangle:
        _activeDrawing = RectangleDrawing(
          startPoint: point,
          color: _currentColor,
          strokeWidth: _currentStrokeWidth,
        );
        break;
        
      case DrawingToolType.longPosition:
      case DrawingToolType.shortPosition:
        // Position tools are handled separately via startPositionTool
        return;
    }
    
    notifyListeners();
  }
  
  /// Start a position tool at the given point
  /// [symbol] - The trading symbol
  /// [point] - Entry point (price and time)
  /// [isLong] - True for long, false for short
  void startPositionTool({
    required String symbol,
    required ChartPoint point,
    required bool isLong,
    double? slPercent,
    double? tpPercent,
    double? quantity,
  }) {
    final sl = slPercent ?? _defaultSlPercent;
    final tp = tpPercent ?? _defaultTpPercent;
    final qty = quantity ?? _defaultQuantity;
    
    final positionTool = isLong
        ? PositionToolDrawing.createLong(
            symbol: symbol,
            entryPoint: point,
            slPercent: sl,
            tpPercent: tp,
            quantity: qty,
          )
        : PositionToolDrawing.createShort(
            symbol: symbol,
            entryPoint: point,
            slPercent: sl,
            tpPercent: tp,
            quantity: qty,
          );
    
    _drawings.add(positionTool);
    _selectedDrawingId = positionTool.id;
    
    // Mark as selected
    final index = _drawings.indexWhere((d) => d.id == positionTool.id);
    if (index != -1) {
      _drawings[index] = _drawings[index].copyWith(isSelected: true);
    }
    
    // Reset tool
    _currentTool = DrawingToolType.none;
    
    // Persist position tools
    _savePositionTools();
    
    notifyListeners();
  }

  /// Update the active drawing with a new point (while dragging)
  void updateDrawing(ChartPoint point) {
    if (_activeDrawing == null) return;
    
    switch (_activeDrawing!.type) {
      case DrawingToolType.trendLine:
      case DrawingToolType.ray:
        _activeDrawing = (_activeDrawing as TrendLineDrawing).copyWith(
          endPoint: point,
        );
        break;
        
      case DrawingToolType.fibonacciRetracement:
        _activeDrawing = (_activeDrawing as FibonacciDrawing).copyWith(
          endPoint: point,
        );
        break;
        
      case DrawingToolType.rectangle:
        _activeDrawing = (_activeDrawing as RectangleDrawing).copyWith(
          endPoint: point,
        );
        break;
        
      default:
        break;
    }
    
    notifyListeners();
  }

  /// Complete the current drawing
  void completeDrawing(ChartPoint? endPoint) {
    if (_activeDrawing == null) return;
    
    // Update with final end point if provided
    if (endPoint != null) {
      updateDrawing(endPoint);
    }
    
    _completeDrawing();
  }

  void _completeDrawing() {
    if (_activeDrawing == null) return;
    
    final completed = _activeDrawing!.copyWith(isComplete: true);
    _drawings.add(completed);
    _activeDrawing = null;
    
    // Reset tool after single-click tools
    if (_currentTool == DrawingToolType.horizontalLine ||
        _currentTool == DrawingToolType.verticalLine) {
      // Keep tool active for multiple lines
    }
    
    notifyListeners();
  }

  /// Cancel the current drawing
  void cancelDrawing() {
    _activeDrawing = null;
    notifyListeners();
  }

  /// Select a drawing by ID
  void selectDrawing(String? id) {
    // Deselect previous
    for (var i = 0; i < _drawings.length; i++) {
      if (_drawings[i].isSelected) {
        _drawings[i] = _drawings[i].copyWith(isSelected: false);
      }
    }
    
    _selectedDrawingId = id;
    
    // Select new
    if (id != null) {
      final index = _drawings.indexWhere((d) => d.id == id);
      if (index != -1) {
        _drawings[index] = _drawings[index].copyWith(isSelected: true);
      }
    }
    
    notifyListeners();
  }

  /// Delete the selected drawing
  void deleteSelected() {
    if (_selectedDrawingId == null) return;
    
    _drawings.removeWhere((d) => d.id == _selectedDrawingId);
    _selectedDrawingId = null;
    notifyListeners();
  }

  /// Delete a specific drawing
  void deleteDrawing(String id) {
    // Check if this is a position tool for persistence
    final wasPositionTool = _drawings.any((d) => d.id == id && d is PositionToolDrawing);
    
    _drawings.removeWhere((d) => d.id == id);
    if (_selectedDrawingId == id) {
      _selectedDrawingId = null;
    }
    
    // Persist if a position tool was deleted
    if (wasPositionTool) {
      _savePositionTools();
    }
    
    notifyListeners();
  }

  /// Clear all drawings
  void clearAll() {
    _drawings.clear();
    _activeDrawing = null;
    _selectedDrawingId = null;
    
    // Clear persisted position tools
    _repository.clearAll(userId: _userId);
    
    notifyListeners();
  }

  /// Find drawing at a point
  ChartDrawing? findDrawingAt(ChartPoint point, double tolerance) {
    for (final drawing in _drawings.reversed) {
      if (drawing.isNearPoint(point, tolerance)) {
        return drawing;
      }
    }
    return null;
  }
  
  // ==================== POSITION TOOL METHODS ====================
  
  /// Update position tool entry price
  void updatePositionToolEntry(String id, double newPrice) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    final newEntryPoint = ChartPoint(
      timestamp: drawing.entryPoint.timestamp,
      price: newPrice,
    );
    
    _drawings[index] = drawing.copyWith(entryPoint: newEntryPoint);
    notifyListeners();
  }
  
  /// Update position tool stop loss
  void updatePositionToolStopLoss(String id, double newPrice) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    _drawings[index] = drawing.copyWith(stopLossPrice: newPrice);
    notifyListeners();
  }
  
  /// Update position tool take profit
  void updatePositionToolTakeProfit(String id, double newPrice) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    _drawings[index] = drawing.copyWith(takeProfitPrice: newPrice);
    notifyListeners();
  }
  
  /// Update position tool quantity
  void updatePositionToolQuantity(String id, double newQuantity) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    _drawings[index] = drawing.copyWith(quantity: newQuantity);
    notifyListeners();
  }
  
  /// Activate a position tool (creates an actual trading position)
  /// Returns the updated position tool with linked position ID
  PositionToolDrawing? activatePositionTool(String id, String linkedPositionId) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return null;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return null;
    if (drawing.status != PositionToolStatus.draft) return null;
    
    final activated = drawing.copyWith(
      status: PositionToolStatus.active,
      linkedPositionId: linkedPositionId,
    );
    
    _drawings[index] = activated;
    
    // Persist the status change
    _savePositionTools();
    
    notifyListeners();
    
    return activated;
  }
  
  /// Mark a position tool as closed
  void closePositionTool(String id, double exitPrice, double realizedPnL) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    _drawings[index] = drawing.copyWith(
      status: PositionToolStatus.closed,
      exitPrice: exitPrice,
      realizedPnL: realizedPnL,
    );
    
    // Persist the status change
    _savePositionTools();
    
    notifyListeners();
  }
  
  /// Find position tool by linked position ID
  PositionToolDrawing? findPositionToolByPositionId(String positionId) {
    try {
      return positionTools.firstWhere((p) => p.linkedPositionId == positionId);
    } catch (_) {
      return null;
    }
  }
  
  /// Set default SL/TP percentages for new position tools
  void setPositionToolDefaults({
    double? slPercent,
    double? tpPercent,
    double? quantity,
  }) {
    if (slPercent != null) _defaultSlPercent = slPercent;
    if (tpPercent != null) _defaultTpPercent = tpPercent;
    if (quantity != null) _defaultQuantity = quantity;
    notifyListeners();
  }
  
  /// Move entire position tool (entry + SL + TP) by a price delta
  void movePositionTool(String id, double priceDelta) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    final newEntryPoint = ChartPoint(
      timestamp: drawing.entryPoint.timestamp,
      price: drawing.entryPrice + priceDelta,
    );
    
    _drawings[index] = drawing.copyWith(
      entryPoint: newEntryPoint,
      stopLossPrice: drawing.stopLossPrice + priceDelta,
      takeProfitPrice: drawing.takeProfitPrice + priceDelta,
    );
    notifyListeners();
  }
  
  /// Update position tool end time (width)
  void updatePositionToolEndTime(String id, DateTime newEndTime) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    // Ensure end time is after start time
    if (!newEndTime.isAfter(drawing.startTime)) return;
    
    _drawings[index] = drawing.copyWith(endTime: newEndTime);
    notifyListeners();
  }
  
  /// Move entire position tool in time (horizontal move)
  void movePositionToolInTime(String id, Duration timeDelta) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    final newEntryPoint = ChartPoint(
      timestamp: drawing.entryPoint.timestamp.add(timeDelta),
      price: drawing.entryPrice,
    );
    final newEndTime = drawing.endTime.add(timeDelta);
    
    _drawings[index] = drawing.copyWith(
      entryPoint: newEntryPoint,
      endTime: newEndTime,
    );
    notifyListeners();
  }
  
  /// Move position tool both in price and time
  void movePositionToolFull(String id, double priceDelta, Duration timeDelta) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    final newEntryPoint = ChartPoint(
      timestamp: drawing.entryPoint.timestamp.add(timeDelta),
      price: drawing.entryPrice + priceDelta,
    );
    final newEndTime = drawing.endTime.add(timeDelta);
    
    _drawings[index] = drawing.copyWith(
      entryPoint: newEntryPoint,
      endTime: newEndTime,
      stopLossPrice: drawing.stopLossPrice + priceDelta,
      takeProfitPrice: drawing.takeProfitPrice + priceDelta,
    );
    notifyListeners();
  }
  
  /// Get active handle type for hit-testing
  PositionToolHandle? getPositionToolHandleAt(
    String id, 
    ChartPoint point, 
    double priceTolerance, 
    double timeTolerance,
  ) {
    final drawing = _drawings.firstWhere(
      (d) => d.id == id,
      orElse: () => throw Exception('Drawing not found'),
    );
    
    if (drawing is! PositionToolDrawing) return null;
    
    return drawing.getHandleAt(point, priceTolerance, timeTolerance);
  }
  
  /// Set position tool to absolute position (prevents drift during drag)
  void setPositionToolAbsolute(
    String id,
    double entryPrice,
    double stopLossPrice,
    double takeProfitPrice,
    DateTime startTime,
    DateTime endTime,
  ) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index == -1) return;
    
    final drawing = _drawings[index];
    if (drawing is! PositionToolDrawing) return;
    
    // Ensure end time is after start time
    final validEndTime = endTime.isAfter(startTime) ? endTime : startTime.add(const Duration(hours: 1));
    
    _drawings[index] = drawing.copyWith(
      entryPoint: ChartPoint(timestamp: startTime, price: entryPrice),
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
      endTime: validEndTime,
    );
    notifyListeners();
  }
}


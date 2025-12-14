import 'package:flutter/material.dart';
import '../models/chart_drawing.dart';

/// State management for chart drawing tools
/// 
/// Manages:
/// - Current selected tool
/// - All drawings on the chart
/// - Drawing in progress
/// - Selection state
class ChartDrawingProvider extends ChangeNotifier {
  DrawingToolType _currentTool = DrawingToolType.none;
  final List<ChartDrawing> _drawings = [];
  ChartDrawing? _activeDrawing;
  String? _selectedDrawingId;
  Color _currentColor = const Color(0xFF00E5FF);
  double _currentStrokeWidth = 1.5;

  // Getters
  DrawingToolType get currentTool => _currentTool;
  List<ChartDrawing> get drawings => List.unmodifiable(_drawings);
  ChartDrawing? get activeDrawing => _activeDrawing;
  String? get selectedDrawingId => _selectedDrawingId;
  Color get currentColor => _currentColor;
  double get currentStrokeWidth => _currentStrokeWidth;
  bool get isDrawing => _currentTool != DrawingToolType.none;

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
    }
    
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
    _drawings.removeWhere((d) => d.id == id);
    if (_selectedDrawingId == id) {
      _selectedDrawingId = null;
    }
    notifyListeners();
  }

  /// Clear all drawings
  void clearAll() {
    _drawings.clear();
    _activeDrawing = null;
    _selectedDrawingId = null;
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
}


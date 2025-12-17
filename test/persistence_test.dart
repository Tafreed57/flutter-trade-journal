import 'package:flutter_test/flutter_test.dart';
import 'package:trade_journal_app/models/chart_drawing.dart';
import 'package:trade_journal_app/models/paper_trading.dart';
import 'package:trade_journal_app/services/paper_trading_engine.dart';

void main() {
  group('Position Tool Linking', () {
    test('Position should store linkedToolId when created with one', () {
      final engine = PaperTradingEngine();
      
      // Create position with linked tool ID
      engine.placeMarketOrder(
        symbol: 'AAPL',
        side: OrderSide.buy,
        quantity: 10,
        currentPrice: 150.0,
        stopLoss: 145.0,
        takeProfit: 160.0,
        linkedToolId: 'tool-123',
      );
      
      final position = engine.getPositionForSymbol('AAPL');
      expect(position, isNotNull);
      expect(position!.linkedToolId, equals('tool-123'));
    });
    
    test('onPositionClosed callback should fire with linkedToolId', () {
      final engine = PaperTradingEngine();
      
      String? closedPositionId;
      String? closedToolId;
      
      engine.onPositionClosed = (positionId, linkedToolId) {
        closedPositionId = positionId;
        closedToolId = linkedToolId;
      };
      
      // Create position with linked tool
      engine.placeMarketOrder(
        symbol: 'AAPL',
        side: OrderSide.buy,
        quantity: 10,
        currentPrice: 150.0,
        linkedToolId: 'tool-456',
      );
      
      final position = engine.getPositionForSymbol('AAPL');
      expect(position, isNotNull);
      
      // Close the position
      engine.closePosition(position!.id, 155.0);
      
      // Verify callback was called with correct data
      expect(closedPositionId, equals(position.id));
      expect(closedToolId, equals('tool-456'));
    });
  });
  
  group('PositionToolDrawing', () {
    test('createLong should set correct SL/TP prices', () {
      final tool = PositionToolDrawing.createLong(
        symbol: 'AAPL',
        entryPoint: ChartPoint(
          timestamp: DateTime.now(),
          price: 100.0,
        ),
        slPercent: 2.0,
        tpPercent: 4.0,
      );
      
      expect(tool.isLong, isTrue);
      expect(tool.entryPrice, equals(100.0));
      expect(tool.stopLossPrice, equals(98.0)); // 2% below
      expect(tool.takeProfitPrice, equals(104.0)); // 4% above
      expect(tool.riskRewardRatio, closeTo(2.0, 0.01)); // 4/2 = 2:1
    });
    
    test('createShort should set correct SL/TP prices', () {
      final tool = PositionToolDrawing.createShort(
        symbol: 'AAPL',
        entryPoint: ChartPoint(
          timestamp: DateTime.now(),
          price: 100.0,
        ),
        slPercent: 2.0,
        tpPercent: 4.0,
      );
      
      expect(tool.isLong, isFalse);
      expect(tool.entryPrice, equals(100.0));
      expect(tool.stopLossPrice, equals(102.0)); // 2% above
      expect(tool.takeProfitPrice, equals(96.0)); // 4% below
    });
    
    test('status should transition from draft to active to closed', () {
      var tool = PositionToolDrawing.createLong(
        symbol: 'AAPL',
        entryPoint: ChartPoint(
          timestamp: DateTime.now(),
          price: 100.0,
        ),
      );
      
      expect(tool.status, equals(PositionToolStatus.draft));
      
      // Activate
      tool = tool.copyWith(
        status: PositionToolStatus.active,
        linkedPositionId: 'pos-123',
      );
      expect(tool.status, equals(PositionToolStatus.active));
      expect(tool.linkedPositionId, equals('pos-123'));
      
      // Close
      tool = tool.copyWith(
        status: PositionToolStatus.closed,
        exitPrice: 105.0,
        realizedPnL: 5.0,
      );
      expect(tool.status, equals(PositionToolStatus.closed));
      expect(tool.exitPrice, equals(105.0));
      expect(tool.realizedPnL, equals(5.0));
    });
  });
  
  group('PaperTradingEngine Persistence', () {
    test('restoreAccount should set account state', () {
      final engine = PaperTradingEngine();
      
      final savedAccount = PaperAccount(
        id: 'acc-123',
        balance: 15000.0,
        initialBalance: 10000.0,
        realizedPnL: 5000.0,
        userId: 'user-abc',
      );
      
      engine.restoreAccount(savedAccount);
      
      expect(engine.balance, equals(15000.0));
      expect(engine.realizedPnL, equals(5000.0));
    });
    
    test('restorePositions should separate open and closed', () {
      final engine = PaperTradingEngine();
      
      final openPosition = PaperPosition(
        id: 'pos-1',
        symbol: 'AAPL',
        side: OrderSide.buy,
        quantity: 10,
        entryPrice: 150.0,
      );
      
      final closedPosition = PaperPosition(
        id: 'pos-2',
        symbol: 'GOOGL',
        side: OrderSide.sell,
        quantity: 5,
        entryPrice: 140.0,
        closedAt: DateTime.now(),
        exitPrice: 135.0,
        realizedPnL: 25.0,
      );
      
      engine.restorePositions([openPosition, closedPosition]);
      
      expect(engine.openPositions.length, equals(1));
      expect(engine.closedPositions.length, equals(1));
      expect(engine.openPositions.first.symbol, equals('AAPL'));
      expect(engine.closedPositions.first.symbol, equals('GOOGL'));
    });
    
    test('resetAccount should clear all data', () {
      final engine = PaperTradingEngine();
      
      // Add some positions
      engine.placeMarketOrder(
        symbol: 'AAPL',
        side: OrderSide.buy,
        quantity: 10,
        currentPrice: 150.0,
      );
      
      expect(engine.openPositions.length, equals(1));
      
      // Reset
      engine.resetAccount();
      
      expect(engine.openPositions.length, equals(0));
      expect(engine.closedPositions.length, equals(0));
      expect(engine.balance, equals(10000.0)); // Default balance
    });
  });
  
  group('Multi-User Support', () {
    test('PaperPosition should include userId', () {
      final position = PaperPosition(
        id: 'pos-1',
        symbol: 'AAPL',
        side: OrderSide.buy,
        quantity: 10,
        entryPrice: 150.0,
        userId: 'user-123',
      );
      
      expect(position.userId, equals('user-123'));
      
      final copied = position.copyWith(userId: 'user-456');
      expect(copied.userId, equals('user-456'));
    });
    
    test('PaperAccount should include userId', () {
      final account = PaperAccount(
        id: 'acc-1',
        balance: 10000.0,
        initialBalance: 10000.0,
        userId: 'user-123',
      );
      
      expect(account.userId, equals('user-123'));
    });
  });
}


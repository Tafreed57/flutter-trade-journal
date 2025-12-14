import 'package:flutter_test/flutter_test.dart';
import 'package:trade_journal_app/models/paper_trading.dart';
import 'package:trade_journal_app/models/trade.dart';
import 'package:trade_journal_app/services/paper_trading_engine.dart';

void main() {
  group('PaperTradingEngine', () {
    late PaperTradingEngine engine;

    setUp(() {
      engine = PaperTradingEngine(initialBalance: 10000.0);
    });

    group('Initialization', () {
      test('starts with correct initial balance', () {
        expect(engine.balance, equals(10000.0));
      });

      test('starts with zero realized P&L', () {
        expect(engine.realizedPnL, equals(0));
      });

      test('starts with no open positions', () {
        expect(engine.openPositions, isEmpty);
      });

      test('starts with no closed positions', () {
        expect(engine.closedPositions, isEmpty);
      });

      test('can use custom initial balance', () {
        final customEngine = PaperTradingEngine(initialBalance: 50000.0);
        expect(customEngine.balance, equals(50000.0));
      });
    });

    group('Market Orders - Long Positions', () {
      test('opening a long position deducts balance', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Balance should be reduced by (quantity * price)
        expect(engine.balance, equals(9000.0)); // 10000 - (10 * 100)
        expect(engine.openPositions.length, equals(1));
      });

      test('long position tracks correct entry price', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 150.0,
        );

        final position = engine.openPositions.first;
        expect(position.entryPrice, equals(150.0));
        expect(position.quantity, equals(10));
        expect(position.isLong, isTrue);
      });

      test('closing long position at profit updates balance correctly', () {
        // Open position at $100
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Close position at $120 (profit of $200)
        final position = engine.openPositions.first;
        engine.closePosition(position.id, 120.0);

        // Balance = 9000 + 1000 (returned capital) + 200 (profit) = 10200
        expect(engine.balance, equals(10200.0));
        expect(engine.realizedPnL, equals(200.0));
        expect(engine.openPositions, isEmpty);
        expect(engine.closedPositions.length, equals(1));
      });

      test('closing long position at loss updates balance correctly', () {
        // Open position at $100
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Close position at $80 (loss of $200)
        final position = engine.openPositions.first;
        engine.closePosition(position.id, 80.0);

        // Balance = 9000 + 1000 (returned capital) - 200 (loss) = 9800
        expect(engine.balance, equals(9800.0));
        expect(engine.realizedPnL, equals(-200.0));
      });
    });

    group('Market Orders - Short Positions', () {
      test('opening a short position deducts balance', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
        );

        expect(engine.balance, equals(9000.0));
        expect(engine.openPositions.first.isLong, isFalse);
      });

      test('short position profits when price drops', () {
        // Open short at $100
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Close at $80 (profit of $200)
        final position = engine.openPositions.first;
        engine.closePosition(position.id, 80.0);

        expect(engine.balance, equals(10200.0));
        expect(engine.realizedPnL, equals(200.0));
      });

      test('short position loses when price rises', () {
        // Open short at $100
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Close at $120 (loss of $200)
        final position = engine.openPositions.first;
        engine.closePosition(position.id, 120.0);

        expect(engine.balance, equals(9800.0));
        expect(engine.realizedPnL, equals(-200.0));
      });
    });

    group('Position Management', () {
      test('getPositionForSymbol returns correct position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );
        engine.placeMarketOrder(
          symbol: 'GOOGL',
          side: OrderSide.buy,
          quantity: 5,
          currentPrice: 200.0,
        );

        final aaplPosition = engine.getPositionForSymbol('AAPL');
        expect(aaplPosition?.symbol, equals('AAPL'));
        expect(aaplPosition?.quantity, equals(10));

        final googlPosition = engine.getPositionForSymbol('GOOGL');
        expect(googlPosition?.symbol, equals('GOOGL'));
        expect(googlPosition?.quantity, equals(5));
      });

      test('getPositionForSymbol returns null for non-existent symbol', () {
        expect(engine.getPositionForSymbol('AAPL'), isNull);
      });

      test('adding to existing position averages price', () {
        // Buy 10 at $100
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Buy 10 more at $120
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 120.0,
        );

        final position = engine.openPositions.first;
        expect(position.quantity, equals(20));
        // Average price = (10*100 + 10*120) / 20 = 110
        expect(position.entryPrice, equals(110.0));
      });

      test('closeAllPositions closes all open positions', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );
        engine.placeMarketOrder(
          symbol: 'GOOGL',
          side: OrderSide.buy,
          quantity: 5,
          currentPrice: 200.0,
        );

        expect(engine.openPositions.length, equals(2));

        engine.closeAllPositions({'AAPL': 110.0, 'GOOGL': 220.0});

        expect(engine.openPositions, isEmpty);
        expect(engine.closedPositions.length, equals(2));
      });
    });

    group('Unrealized P&L', () {
      test('calculates unrealized P&L correctly for long', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Price moved to $120 (unrealized profit of $200)
        final unrealizedPnL = engine.unrealizedPnL({'AAPL': 120.0});
        expect(unrealizedPnL, equals(200.0));
      });

      test('calculates unrealized P&L correctly for short', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Price dropped to $80 (unrealized profit of $200)
        final unrealizedPnL = engine.unrealizedPnL({'AAPL': 80.0});
        expect(unrealizedPnL, equals(200.0));
      });

      test('calculates total unrealized P&L across multiple positions', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );
        engine.placeMarketOrder(
          symbol: 'GOOGL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 200.0,
        );

        // AAPL: +$100, GOOGL: -$100
        final unrealizedPnL = engine.unrealizedPnL({
          'AAPL': 110.0,
          'GOOGL': 190.0,
        });
        expect(unrealizedPnL, equals(0.0));
      });

      test('equity includes unrealized P&L', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        // Balance is 9000, unrealized P&L is +200
        final equity = engine.equity({'AAPL': 120.0});
        expect(equity, equals(9200.0));
      });
    });

    group('Stop Loss / Take Profit', () {
      test('creates position with SL and TP', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
          stopLoss: 90.0,
          takeProfit: 120.0,
        );

        final position = engine.openPositions.first;
        expect(position.stopLoss, equals(90.0));
        expect(position.takeProfit, equals(120.0));
      });

      test('triggers stop loss for long position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
          stopLoss: 90.0,
        );

        expect(engine.openPositions.length, equals(1));

        // Price hits stop loss
        engine.checkStopLossTakeProfit('AAPL', 89.0);

        expect(engine.openPositions, isEmpty);
        expect(engine.closedPositions.length, equals(1));
      });

      test('triggers take profit for long position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
          takeProfit: 120.0,
        );

        expect(engine.openPositions.length, equals(1));

        // Price hits take profit
        engine.checkStopLossTakeProfit('AAPL', 121.0);

        expect(engine.openPositions, isEmpty);
        expect(engine.closedPositions.length, equals(1));
      });

      test('triggers stop loss for short position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
          stopLoss: 110.0,
        );

        // Price rises to stop loss
        engine.checkStopLossTakeProfit('AAPL', 111.0);

        expect(engine.openPositions, isEmpty);
        expect(engine.realizedPnL, lessThan(0)); // Loss
      });

      test('triggers take profit for short position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.sell,
          quantity: 10,
          currentPrice: 100.0,
          takeProfit: 80.0,
        );

        // Price drops to take profit
        engine.checkStopLossTakeProfit('AAPL', 79.0);

        expect(engine.openPositions, isEmpty);
        expect(engine.realizedPnL, greaterThan(0)); // Profit
      });

      test('can update stop loss on existing position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
          stopLoss: 90.0,
        );

        final position = engine.openPositions.first;
        engine.updateStopLoss(position.id, 95.0);

        expect(engine.openPositions.first.stopLoss, equals(95.0));
      });

      test('can update take profit on existing position', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
          takeProfit: 120.0,
        );

        final position = engine.openPositions.first;
        engine.updateTakeProfit(position.id, 130.0);

        expect(engine.openPositions.first.takeProfit, equals(130.0));
      });
    });

    group('Account Management', () {
      test('resetAccount restores initial balance', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        engine.resetAccount();

        expect(engine.balance, equals(10000.0));
        expect(engine.openPositions, isEmpty);
        expect(engine.closedPositions, isEmpty);
      });

      test('resetAccount with new balance', () {
        engine.resetAccount(newBalance: 50000.0);
        expect(engine.balance, equals(50000.0));
      });

      test('deposit adds to balance', () {
        engine.deposit(5000.0);
        expect(engine.balance, equals(15000.0));
      });

      test('withdraw subtracts from balance', () {
        final success = engine.withdraw(3000.0);
        expect(success, isTrue);
        expect(engine.balance, equals(7000.0));
      });

      test('withdraw fails if amount exceeds balance', () {
        final success = engine.withdraw(15000.0);
        expect(success, isFalse);
        expect(engine.balance, equals(10000.0));
      });
    });

    group('Position Size Calculator', () {
      test('calculates correct position size', () {
        final size = PaperTradingEngine.calculatePositionSize(
          balance: 10000.0,
          riskPercent: 1.0,
          entryPrice: 100.0,
          stopLossPrice: 95.0,
        );

        // Risk amount = 10000 * 0.01 = 100
        // Stop loss distance = 100 - 95 = 5
        // Position size = 100 / 5 = 20
        expect(size, equals(20.0));
      });

      test('returns 0 when stop loss equals entry', () {
        final size = PaperTradingEngine.calculatePositionSize(
          balance: 10000.0,
          riskPercent: 1.0,
          entryPrice: 100.0,
          stopLossPrice: 100.0,
        );

        expect(size, equals(0));
      });

      test('handles short position stop loss correctly', () {
        final size = PaperTradingEngine.calculatePositionSize(
          balance: 10000.0,
          riskPercent: 2.0,
          entryPrice: 100.0,
          stopLossPrice: 110.0, // Stop above for short
        );

        // Risk amount = 10000 * 0.02 = 200
        // Stop loss distance = |100 - 110| = 10
        // Position size = 200 / 10 = 20
        expect(size, equals(20.0));
      });
    });

    group('Journal Integration', () {
      test('calls onTradeClosed callback when position closes', () {
        Trade? capturedTrade;
        engine.onTradeClosed = (trade) {
          capturedTrade = trade;
        };

        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        final position = engine.openPositions.first;
        engine.closePosition(position.id, 120.0);

        expect(capturedTrade, isNotNull);
        expect(capturedTrade!.symbol, equals('AAPL'));
        expect(capturedTrade!.side, equals(TradeSide.long));
        expect(capturedTrade!.quantity, equals(10));
        expect(capturedTrade!.entryPrice, equals(100.0));
        expect(capturedTrade!.exitPrice, equals(120.0));
        expect(capturedTrade!.tags, contains('paper-trade'));
      });

      test('journal entry has correct P&L outcome', () {
        Trade? capturedTrade;
        engine.onTradeClosed = (trade) {
          capturedTrade = trade;
        };

        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        final position = engine.openPositions.first;
        engine.closePosition(position.id, 120.0);

        expect(capturedTrade!.notes, contains('WIN'));
      });
    });

    group('Order History', () {
      test('tracks all placed orders', () {
        engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );
        engine.placeMarketOrder(
          symbol: 'GOOGL',
          side: OrderSide.sell,
          quantity: 5,
          currentPrice: 200.0,
        );

        expect(engine.orderHistory.length, equals(2));
      });

      test('orders have correct status after execution', () {
        final order = engine.placeMarketOrder(
          symbol: 'AAPL',
          side: OrderSide.buy,
          quantity: 10,
          currentPrice: 100.0,
        );

        expect(order.status, equals(OrderStatus.filled));
        expect(order.filledPrice, equals(100.0));
        expect(order.filledAt, isNotNull);
      });
    });
  });
}


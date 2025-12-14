import 'package:flutter_test/flutter_test.dart';
import 'package:trade_journal_app/models/trade.dart';
import 'package:trade_journal_app/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    // Test data factory
    // Counter for unique IDs
    int tradeCounter = 0;
    
    Trade createTrade({
      required String symbol,
      required double entryPrice,
      required double exitPrice,
      required double quantity,
      bool isLong = true,
      DateTime? exitDate,
    }) {
      tradeCounter++;
      // Note: outcome is computed automatically from profitLoss in Trade model
      return Trade(
        id: 'test-$tradeCounter',
        symbol: symbol,
        side: isLong ? TradeSide.long : TradeSide.short,
        quantity: quantity,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        entryDate: DateTime(2024, 1, 1),
        exitDate: exitDate ?? DateTime(2024, 1, 2),
      );
    }

    group('calculateWinRate', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateWinRate([]), equals(0));
      });

      test('returns 100 for all winning trades', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10),
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 220, quantity: 5),
        ];
        expect(AnalyticsService.calculateWinRate(trades), equals(100));
      });

      test('returns 0 for all losing trades', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 90, quantity: 10),
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5),
        ];
        expect(AnalyticsService.calculateWinRate(trades), equals(0));
      });

      test('calculates correct percentage for mixed trades', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // win
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // loss
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 330, quantity: 3),  // win
          createTrade(symbol: 'TSLA', entryPrice: 400, exitPrice: 380, quantity: 2),  // loss
        ];
        expect(AnalyticsService.calculateWinRate(trades), equals(50));
      });

      test('ignores open trades (no exit price)', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // win
          Trade(
            id: 'open-trade',
            symbol: 'GOOGL',
            side: TradeSide.long,
            quantity: 5,
            entryPrice: 200,
            exitPrice: null, // open trade
            entryDate: DateTime(2024, 1, 1),
          ),
        ];
        expect(AnalyticsService.calculateWinRate(trades), equals(100));
      });
    });

    group('calculateTotalPnL', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateTotalPnL([]), equals(0));
      });

      test('sums positive P&L correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // +100
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 220, quantity: 5), // +100
        ];
        expect(AnalyticsService.calculateTotalPnL(trades), equals(200));
      });

      test('sums negative P&L correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 90, quantity: 10), // -100
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // -100
        ];
        expect(AnalyticsService.calculateTotalPnL(trades), equals(-200));
      });

      test('sums mixed P&L correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10), // +200
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // -100
        ];
        expect(AnalyticsService.calculateTotalPnL(trades), equals(100));
      });

      test('handles short trades correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 90, quantity: 10, isLong: false), // +100 (short wins when price drops)
        ];
        expect(AnalyticsService.calculateTotalPnL(trades), equals(100));
      });
    });

    group('calculateAveragePnL', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateAveragePnL([]), equals(0));
      });

      test('calculates average correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // +100
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 220, quantity: 5), // +100
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 280, quantity: 5),  // -100
        ];
        expect(AnalyticsService.calculateAveragePnL(trades), closeTo(33.33, 0.01));
      });
    });

    group('calculateProfitFactor', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateProfitFactor([]), equals(0));
      });

      test('returns infinity when no losses', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10),
        ];
        expect(AnalyticsService.calculateProfitFactor(trades), equals(double.infinity));
      });

      test('returns 0 when no wins', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 90, quantity: 10),
        ];
        expect(AnalyticsService.calculateProfitFactor(trades), equals(0));
      });

      test('calculates profit factor correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10), // +200
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // -100
        ];
        // Profit factor = 200 / 100 = 2.0
        expect(AnalyticsService.calculateProfitFactor(trades), equals(2.0));
      });
    });

    group('calculateRiskRewardRatio', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateRiskRewardRatio([]), equals(0));
      });

      test('calculates R:R correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10), // +200
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 210, quantity: 10), // +100
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 280, quantity: 5),  // -100
        ];
        // Avg win = (200 + 100) / 2 = 150
        // Avg loss = 100
        // R:R = 150 / 100 = 1.5
        expect(AnalyticsService.calculateRiskRewardRatio(trades), equals(1.5));
      });
    });

    group('calculateLargestWin', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateLargestWin([]), equals(0));
      });

      test('finds largest winning trade', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // +100
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 250, quantity: 10), // +500
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 310, quantity: 10), // +100
        ];
        expect(AnalyticsService.calculateLargestWin(trades), equals(500));
      });
    });

    group('calculateLargestLoss', () {
      test('returns 0 for empty list', () {
        expect(AnalyticsService.calculateLargestLoss([]), equals(0));
      });

      test('finds largest losing trade', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 90, quantity: 10),  // -100
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 150, quantity: 10), // -500
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 290, quantity: 10), // -100
        ];
        expect(AnalyticsService.calculateLargestLoss(trades), equals(-500));
      });
    });

    group('getTradeCountStats', () {
      test('returns zeros for empty list', () {
        final stats = AnalyticsService.getTradeCountStats([]);
        expect(stats.total, equals(0));
        expect(stats.wins, equals(0));
        expect(stats.losses, equals(0));
      });

      test('counts correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // win
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // loss
          createTrade(symbol: 'MSFT', entryPrice: 300, exitPrice: 330, quantity: 3),  // win
          Trade(
            id: 'open',
            symbol: 'TSLA',
            side: TradeSide.long,
            quantity: 2,
            entryPrice: 400,
            entryDate: DateTime(2024, 1, 1),
          ), // open
        ];
        
        final stats = AnalyticsService.getTradeCountStats(trades);
        expect(stats.total, equals(4));
        expect(stats.open, equals(1));
        expect(stats.wins, equals(2));
        expect(stats.losses, equals(1));
        expect(stats.closed, equals(3));
      });
    });

    group('generateEquityCurve', () {
      test('returns empty list for no trades', () {
        expect(AnalyticsService.generateEquityCurve([]), isEmpty);
      });

      test('generates correct cumulative P&L', () {
        final trades = [
          createTrade(
            symbol: 'AAPL', 
            entryPrice: 100, 
            exitPrice: 110, 
            quantity: 10,
            exitDate: DateTime(2024, 1, 1),
          ), // +100
          createTrade(
            symbol: 'GOOGL', 
            entryPrice: 200, 
            exitPrice: 180, 
            quantity: 5,
            exitDate: DateTime(2024, 1, 2),
          ), // -100
          createTrade(
            symbol: 'MSFT', 
            entryPrice: 300, 
            exitPrice: 350, 
            quantity: 4,
            exitDate: DateTime(2024, 1, 3),
          ), // +200
        ];
        
        final curve = AnalyticsService.generateEquityCurve(trades);
        expect(curve.length, equals(3));
        expect(curve[0].equity, equals(100));  // +100
        expect(curve[1].equity, equals(0));    // +100 - 100 = 0
        expect(curve[2].equity, equals(200));  // 0 + 200 = 200
      });

      test('sorts by exit date', () {
        final trades = [
          createTrade(
            symbol: 'AAPL', 
            entryPrice: 100, 
            exitPrice: 110, 
            quantity: 10,
            exitDate: DateTime(2024, 1, 3), // Later
          ),
          createTrade(
            symbol: 'GOOGL', 
            entryPrice: 200, 
            exitPrice: 210, 
            quantity: 5,
            exitDate: DateTime(2024, 1, 1), // Earlier
          ),
        ];
        
        final curve = AnalyticsService.generateEquityCurve(trades);
        expect(curve[0].date, equals(DateTime(2024, 1, 1)));
        expect(curve[1].date, equals(DateTime(2024, 1, 3)));
      });
    });

    group('getPnLBySymbol', () {
      test('returns empty map for no trades', () {
        expect(AnalyticsService.getPnLBySymbol([]), isEmpty);
      });

      test('groups P&L by symbol correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10), // +100
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10), // +200
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5), // -100
        ];
        
        final pnlBySymbol = AnalyticsService.getPnLBySymbol(trades);
        expect(pnlBySymbol['AAPL'], equals(300));
        expect(pnlBySymbol['GOOGL'], equals(-100));
      });

      test('handles case-insensitive symbols', () {
        final trades = [
          createTrade(symbol: 'aapl', entryPrice: 100, exitPrice: 110, quantity: 10),
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10),
        ];
        
        final pnlBySymbol = AnalyticsService.getPnLBySymbol(trades);
        expect(pnlBySymbol.containsKey('AAPL'), isTrue);
        expect(pnlBySymbol['AAPL'], equals(300));
      });
    });

    group('getTradeCountBySymbol', () {
      test('counts trades per symbol correctly', () {
        final trades = [
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 110, quantity: 10),
          createTrade(symbol: 'AAPL', entryPrice: 100, exitPrice: 120, quantity: 10),
          createTrade(symbol: 'GOOGL', entryPrice: 200, exitPrice: 180, quantity: 5),
        ];
        
        final countBySymbol = AnalyticsService.getTradeCountBySymbol(trades);
        expect(countBySymbol['AAPL'], equals(2));
        expect(countBySymbol['GOOGL'], equals(1));
      });
    });
  });
}


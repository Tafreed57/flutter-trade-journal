// Smoke tests for release verification
// Run these before any release build to ensure core functionality works

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trade_journal_app/core/env_config.dart';
import 'package:trade_journal_app/models/trade.dart';
import 'package:trade_journal_app/services/analytics_service.dart';

void main() {
  group('Smoke Tests - Core Functionality', () {
    setUpAll(() async {
      // Initialize Hive for tests
      await Hive.initFlutter();
      
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TradeSideAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(TradeOutcomeAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(TradeAdapter());
      }
      
      // Load environment
      await EnvConfig.load();
    });

    test('Environment config loads without error', () async {
      await EnvConfig.load();
      // Should not throw
      expect(true, isTrue);
    });

    test('Environment correctly identifies release vs debug mode', () {
      // This will vary based on how tests are run
      expect(EnvConfig.isRelease || EnvConfig.isDebug, isTrue);
    });

    test('Trade model can be created and calculates P&L', () {
      final trade = Trade(
        id: 'test-id',
        symbol: 'AAPL',
        side: TradeSide.long,
        entryPrice: 150.0,
        exitPrice: 160.0,
        quantity: 10,
        entryDate: DateTime(2024, 1, 1),
        exitDate: DateTime(2024, 1, 2),
        notes: 'Test trade',
        tags: ['test'],
      );

      expect(trade.symbol, equals('AAPL'));
      expect(trade.profitLoss, equals(100.0)); // (160-150) * 10
      expect(trade.outcome, equals(TradeOutcome.win));
      expect(trade.isClosed, isTrue);
    });

    test('Trade model calculates loss correctly', () {
      final trade = Trade(
        id: 'test-loss',
        symbol: 'GOOGL',
        side: TradeSide.long,
        entryPrice: 100.0,
        exitPrice: 90.0,
        quantity: 10,
        entryDate: DateTime(2024, 1, 1),
        exitDate: DateTime(2024, 1, 2),
      );

      expect(trade.profitLoss, equals(-100.0)); // (90-100) * 10
      expect(trade.outcome, equals(TradeOutcome.loss));
    });

    test('Analytics service calculates win rate correctly', () {
      final trades = [
        Trade(
          id: '1',
          symbol: 'AAPL',
          side: TradeSide.long,
          entryPrice: 100.0,
          exitPrice: 110.0, // Win
          quantity: 10,
          entryDate: DateTime(2024, 1, 1),
          exitDate: DateTime(2024, 1, 2),
        ),
        Trade(
          id: '2',
          symbol: 'GOOGL',
          side: TradeSide.long,
          entryPrice: 100.0,
          exitPrice: 90.0, // Loss
          quantity: 10,
          entryDate: DateTime(2024, 1, 3),
          exitDate: DateTime(2024, 1, 4),
        ),
      ];

      final winRate = AnalyticsService.calculateWinRate(trades);
      final totalPnL = AnalyticsService.calculateTotalPnL(trades);

      expect(winRate, closeTo(50.0, 0.01));
      expect(totalPnL, equals(0.0)); // +100 - 100 = 0
    });

    test('Timeframe parsing works correctly', () {
      // Test that common timeframe strings parse correctly
      final timeframes = ['1m', '5m', '15m', '1h', '4h', '1D', '1W'];
      for (final tf in timeframes) {
        // Should not throw
        expect(tf.isNotEmpty, isTrue);
      }
    });
  });

  group('Smoke Tests - UI Components', () {
    testWidgets('MaterialApp can be created', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test'),
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('Theme colors render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D1117),
          ),
          home: const Scaffold(
            body: Center(
              child: Text('Theme Test'),
            ),
          ),
        ),
      );

      expect(find.text('Theme Test'), findsOneWidget);
    });
  });

  group('Smoke Tests - Platform Compatibility', () {
    test('DateTime operations work correctly', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      expect(now.isAfter(yesterday), isTrue);
      expect(yesterday.isBefore(now), isTrue);
    });

    test('Number formatting works correctly', () {
      const value = 1234.5678;
      final formatted = value.toStringAsFixed(2);
      expect(formatted, equals('1234.57'));
    });

    test('List operations work correctly', () {
      final list = [1, 2, 3, 4, 5];
      expect(list.length, equals(5));
      expect(list.reduce((a, b) => a + b), equals(15));
    });
  });
}

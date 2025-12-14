// Basic widget test for Trading Journal app

import 'package:flutter_test/flutter_test.dart';
import 'package:trade_journal_app/main.dart';

void main() {
  testWidgets('App launches and shows title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TradingJournalApp());

    // Allow time for initialization
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the app title is displayed
    expect(find.text('Trading Journal'), findsOneWidget);
  });
}

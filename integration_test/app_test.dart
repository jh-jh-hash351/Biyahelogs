import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:biyahe_log/main.dart' as app;

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 150));
}

Future<void> _enter(WidgetTester tester, int index, String text) async {
  final field = find.byType(TextFormField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register, log fuel, reports, logout and log back in',
      (tester) async {
    final databasesPath = await getDatabasesPath();
    await deleteDatabase(p.join(databasesPath, 'biyahe_log.db'));

    app.main();
    await _settle(tester);

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('New here? Create a local account'));
    await _settle(tester);
    expect(find.text('Create account'), findsOneWidget);

    await _enter(tester, 0, 'juan');
    await _enter(tester, 1, 'secret123');
    await _enter(tester, 2, 'secret123');
    await _enter(tester, 3, 'City Car');
    await _enter(tester, 4, 'ABC 1234');

    await tester.tap(find.text('Motorcycle'));
    await _settle(tester);
    await tester.tap(find.text('Car').last);
    await _settle(tester);

    final createButton = find.text('Create account').last;
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await _settle(tester);

    expect(find.text('City Car'), findsWidgets);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('₱0.00'), findsWidgets);

    // First fuel log: 1,000 km, ₱500 for 10 L.
    await tester.tap(find.text('Add log'));
    await _settle(tester);
    expect(find.text('Add log entry'), findsOneWidget);
    await _enter(tester, 1, '1000');
    await _enter(tester, 2, '500');
    await _enter(tester, 3, '10');
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await _settle(tester);

    expect(find.text('₱500.00'), findsWidgets);

    // Second fuel log: 1,300 km, ₱600 for 7.5 L => 40 km/L.
    await tester.tap(find.text('Add log'));
    await _settle(tester);
    await _enter(tester, 1, '1300');
    await _enter(tester, 2, '600');
    await _enter(tester, 3, '7.5');
    await tester.ensureVisible(find.text('Save entry'));
    await tester.tap(find.text('Save entry'));
    await _settle(tester);

    expect(find.text('₱1,100.00'), findsWidgets);
    expect(find.text('40'), findsWidgets);
    expect(find.text('1,300 km'), findsWidgets);

    await tester.tap(find.text('Reports'));
    await _settle(tester);
    expect(find.text('Spending report'), findsOneWidget);
    expect(find.text('₱1,100.00'), findsWidgets);

    // Persistence: log out, then log back in.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await _settle(tester);
    await tester.tap(find.text('Log out'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await _settle(tester);

    expect(find.text('Welcome back'), findsOneWidget);

    await _enter(tester, 0, 'juan');
    await _enter(tester, 1, 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await _settle(tester);

    expect(find.text('City Car'), findsWidgets);
    expect(find.text('₱1,100.00'), findsWidgets);
  });
}

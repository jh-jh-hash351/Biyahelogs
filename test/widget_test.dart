import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biyahe_log/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders for a fresh install', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onAuthenticated: (_) {}),
      ),
    );

    expect(find.text('BiyaheLog'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('New here? Create a local account'), findsOneWidget);
  });

  testWidgets('login form validates empty fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onAuthenticated: (_) {}),
      ),
    );

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}

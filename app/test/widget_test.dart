// This is a basic Flutter widget test for the Neptune Pay Dashboard.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:app/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen loads and displays categories', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('LOADING...'), findsOneWidget);
    expect(find.text('TOURNAMENTS'), findsOneWidget);
    expect(find.text('SCRIMS'), findsOneWidget);
    expect(find.text('COMMUNITY'), findsOneWidget);

    // Complete splash warmup timers so the test exits cleanly.
    await tester.pump(const Duration(milliseconds: 700));
  });
}

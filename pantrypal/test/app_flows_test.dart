// Taps the real buttons on the Alerts, Stock and Add screens against the
// sample data in assets/mock/ (ApiConfig.useMock), with Flutter's debug
// checks on, so errors like "setState() callback returned a Future" fail here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/core/constants.dart';
import 'package:pantrypal/screens/add_stock_screen.dart';
import 'package:pantrypal/screens/batches_screen.dart';
import 'package:pantrypal/screens/today_alerts_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

// The screens catch errors and show them in a snackbar, so check the screen too.
void _expectNoErrors(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.textContaining('setState()'), findsNothing);
  expect(find.textContaining('Exception'), findsNothing);
  expect(find.textContaining('server returned an error'), findsNothing);
}

Widget _host(Widget screen) => MaterialApp(home: Scaffold(body: screen));

void main() {
  setUp(() {
    ApiConfig.useMock = true;
    rootBundle.clear(); // a cached load from the previous test never completes in this one
  });

  testWidgets('Alerts: Mark Used saves and reloads without errors', (tester) async {
    await tester.pumpWidget(_host(const TodayAlertsScreen()));
    await _settle(tester);
    expect(find.text('Beef Cubes'), findsWidgets);

    await tester.tap(find.text('Mark Used').first);
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    _expectNoErrors(tester);
  });

  testWidgets('Alerts: Discount saves and reloads without errors', (tester) async {
    await tester.pumpWidget(_host(const TodayAlertsScreen()));
    await _settle(tester);

    await tester.tap(find.textContaining('Discount ').first);
    await _settle(tester);
    await tester.tap(find.textContaining(RegExp(r'^Apply \d+% discount$')));
    await _settle(tester);
    _expectNoErrors(tester);
    expect(find.textContaining('discount applied'), findsOneWidget);
  });

  testWidgets('Stock: lists batches from the API and logs waste', (tester) async {
    await tester.pumpWidget(_host(const BatchesScreen()));
    await _settle(tester);
    expect(find.text('Prawns'), findsWidgets);
    expect(find.text('At risk'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log waste'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Log waste'));
    await _settle(tester);
    await tester.tap(find.text('Log waste').last); // the sheet's confirm button
    await _settle(tester);
    _expectNoErrors(tester);
    expect(find.textContaining('logged as waste'), findsOneWidget);
  });

  testWidgets('Add: picks a catalogue product, saves it, and reuses it', (tester) async {
    await tester.pumpWidget(_host(const AddStockScreen()));
    await _settle(tester);

    await tester.tap(find.text('Use last entry'));
    await _settle(tester);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);

    await tester.tap(find.textContaining('Tap to choose'));
    await _settle(tester);
    await tester.tap(find.text('White Bread'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    _expectNoErrors(tester);
    expect(find.textContaining('Saved '), findsOneWidget);

    await tester.tap(find.text('Use last entry'));
    await _settle(tester);
    expect(find.textContaining('White Bread ·'), findsOneWidget);
  });
}

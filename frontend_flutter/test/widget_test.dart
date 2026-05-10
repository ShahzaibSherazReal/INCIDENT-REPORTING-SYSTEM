import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incident_reporting_system/theme.dart';

void main() {
  testWidgets('Executive theme scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkExecutiveTheme(),
        home: const Scaffold(body: Text('IRS smoke')),
      ),
    );

    expect(find.text('IRS smoke'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

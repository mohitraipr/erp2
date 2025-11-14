import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_login_app/main.dart';

void main() {
  testWidgets('renders login form with username and password fields', (tester) async {
    await tester.pumpWidget(const AuroraLoginApp());

    expect(find.text('Aurora Login'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'demo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
  });
}

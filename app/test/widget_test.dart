// Basic Flutter widget test for Secretariat app
// Updated for Wave 21: Changed to test SecretariatApp instead of MyApp

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secretariat_app/main.dart';

void main() {
  testWidgets('Secretariat app loads without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SecretariatApp());

    // Verify that the app title appears
    expect(find.text('Secretariat'), findsOneWidget);

    // Verify that the search field is present
    expect(find.byType(TextField), findsOneWidget);
  });
}

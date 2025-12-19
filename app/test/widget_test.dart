// Basic Flutter widget test for Secretariat app
// Updated for Wave 21: Changed to test SecretariatApp instead of MyApp

import 'package:flutter_test/flutter_test.dart';

import 'package:secretariat_app/main.dart';
import 'package:secretariat_app/providers/vault_provider.dart';

void main() {
  testWidgets('Secretariat app loads without errors', (
    WidgetTester tester,
  ) async {
    // Create a VaultProvider for testing
    final vaultProvider = VaultProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(SecretariatApp(vaultProvider: vaultProvider));

    // Verify that the app title appears
    expect(find.text('Secretariat'), findsOneWidget);
  });
}

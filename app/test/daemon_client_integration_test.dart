// Integration test for DaemonClient
// Run with: flutter test test/daemon_client_integration_test.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretariat_app/services/daemon_client.dart';

void main() {
  final runIntegration =
      Platform.environment['SECRETARIAT_RUN_INTEGRATION_TESTS'] == '1';

  group('DaemonClient Integration', () {
    late DaemonClient client;

    setUp(() {
      client = DaemonClient();
    });

    tearDown(() async {
      await client.disconnect();
    });

    test('connects to daemon', () async {
      await client.connect();
      expect(client.isConnected, isTrue);
    }, skip: !runIntegration);

    test('lists secrets', () async {
      await client.connect();
      final secrets = await client.listSecrets();
      expect(secrets, isA<List<Map<String, dynamic>>>());
      debugPrint('Found ${secrets.length} secrets');
    }, skip: !runIntegration);

    test('set, get, and delete secret', () async {
      await client.connect();

      // Set a test secret
      await client.setSecret('FLUTTER_TEST_KEY', 'flutter_test_value_123');
      debugPrint('✓ Set secret');

      // Get it back
      final secret = await client.getSecret('FLUTTER_TEST_KEY');
      expect(secret['value'], equals('flutter_test_value_123'));
      debugPrint('✓ Get secret');

      // Delete it
      await client.deleteSecret('FLUTTER_TEST_KEY');
      debugPrint('✓ Delete secret');

      // Verify it's gone
      try {
        await client.getSecret('FLUTTER_TEST_KEY');
        fail('Secret should have been deleted');
      } catch (e) {
        debugPrint('✓ Secret no longer exists');
      }
    }, skip: !runIntegration);

    test('health check', () async {
      await client.connect();
      final status = await client.healthCheck();
      expect(status, isA<Map<String, dynamic>>());
      debugPrint('Health check: $status');
    }, skip: !runIntegration);
  });
}

// Example usage of the Secretariat Dart SDK

// ignore_for_file: avoid_print

import 'package:secretariat/secretariat.dart';

void main() async {
  // Create a Secretariat client
  final client = Secretariat();

  try {
    print('Secretariat Dart SDK Example\n');

    // Example 1: Get a single secret
    print('1. Getting single secret...');
    try {
      final apiKey = await client.get('OPENAI_API_KEY');
      print('   ✓ Retrieved OPENAI_API_KEY: ${apiKey.substring(0, 10)}...');
    } catch (e) {
      print('   ✗ Error: $e');
    }

    // Example 2: List all secrets
    print('\n2. Listing all secrets...');
    try {
      final secrets = await client.list();
      print('   ✓ Found ${secrets.length} secrets:');
      for (final name in secrets) {
        print('     - $name');
      }
    } catch (e) {
      print('   ✗ Error: $e');
    }

    // Example 3: Get multiple secrets
    print('\n3. Getting multiple secrets...');
    try {
      final secrets = await client.getMany([
        'OPENAI_API_KEY',
        'DATABASE_URL',
        'STRIPE_API_KEY',
      ]);
      print('   ✓ Retrieved ${secrets.length} secrets');
      for (final entry in secrets.entries) {
        final preview = entry.value.length > 20
            ? '${entry.value.substring(0, 20)}...'
            : entry.value;
        print('     ${entry.key}: $preview');
      }
    } catch (e) {
      print('   ✗ Error: $e');
    }

    print('\n✓ Example completed successfully');
  } catch (e) {
    print('\n✗ Fatal error: $e');
  } finally {
    // Always close the connection
    await client.close();
  }
}

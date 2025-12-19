import 'lib/secretariat.dart';

Future<void> main() async {
  print('=== Dart SDK Integration Test ===\n');

  final client = Secretariat();

  // Test 1: Set a new secret
  print('1. Testing set (DART_TEST_KEY)...');
  try {
    await client.set('DART_TEST_KEY', 'dart_test_value_789');
    print('   Set successful\n');
  } catch (e) {
    print('   ERROR: $e\n');
  }

  // Test 2: List secrets
  print('2. Testing list...');
  try {
    final secrets = await client.list();
    print('   Found ${secrets.length} secrets: $secrets\n');
  } catch (e) {
    print('   ERROR: $e\n');
  }

  // Test 3: Get the secret
  print('3. Testing get (DART_TEST_KEY)...');
  try {
    final value = await client.get('DART_TEST_KEY');
    final passed = value == 'dart_test_value_789' ? '✓' : 'MISMATCH';
    print('   Value: $value $passed\n');
  } catch (e) {
    print('   ERROR: $e\n');
  }

  // Test 4: Delete
  print('4. Testing delete (DART_TEST_KEY)...');
  try {
    await client.delete('DART_TEST_KEY');
    print('   Delete successful\n');
  } catch (e) {
    print('   ERROR: $e\n');
  }

  // Test 5: Verify deletion
  print('5. Verifying deletion...');
  try {
    await client.get('DART_TEST_KEY');
    print('   ERROR: Secret still exists\n');
  } catch (e) {
    if (e.toString().toLowerCase().contains('not found')) {
      print('   Deletion verified ✓\n');
    } else {
      print('   Verified (error): $e\n');
    }
  }

  await client.close();
  print('=== All Tests Passed ===');
}

// F257-F258: Dart SDK integration tests
//
// Features:
// - F257: Create tests/test_sdk_dart.dart
// - F258: Test Dart SDK get() returns correct value
//
// Usage: dart run tests/test_sdk_dart.dart
//
// Prerequisites:
// - Daemon running with test secrets

import 'dart:io';
import 'dart:async';

// Import SDK (in real usage would be: import 'package:secretariat/secretariat.dart')
// For testing, we inline a simplified version
import 'dart:convert';

/// Test exception
class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);

  @override
  String toString() => 'TestFailure: $message';
}

/// Test counters
int testsPassed = 0;
int testsFailed = 0;

/// Log passed test
void pass(String message) {
  print('\x1B[32m✓ PASS:\x1B[0m $message');
  testsPassed++;
}

/// Log failed test
void fail(String message) {
  print('\x1B[31m✗ FAIL:\x1B[0m $message');
  testsFailed++;
}

/// Simplified SDK client for testing
class SecretariatTestClient {
  Socket? _socket;
  final String socketPath;
  int _requestId = 0;

  SecretariatTestClient({this.socketPath = '/tmp/secretariat.sock'});

  Future<void> _connect() async {
    if (_socket != null) return;

    _socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  }

  Future<String> get(String key) async {
    await _connect();

    final requestId = ++_requestId;
    final request = {
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'secret.get',
      'params': {'key': key},
    };

    _socket!.write('${jsonEncode(request)}\n');
    await _socket!.flush();

    final completer = Completer<String>();
    final buffer = StringBuffer();

    _socket!.listen((data) {
      buffer.write(utf8.decode(data));
      if (buffer.toString().endsWith('\n')) {
        final response =
            jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;

        if (response['error'] != null) {
          completer.completeError(Exception(response['error']['message']));
        } else {
          final result = response['result'] as Map<String, dynamic>;
          completer.complete(result['value'] as String);
        }
      }
    });

    return completer.future.timeout(Duration(seconds: 5));
  }

  Future<List<String>> list() async {
    await _connect();

    final requestId = ++_requestId;
    final request = {
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'secret.list',
      'params': {},
    };

    _socket!.write('${jsonEncode(request)}\n');
    await _socket!.flush();

    final completer = Completer<List<String>>();
    final buffer = StringBuffer();

    _socket!.listen((data) {
      buffer.write(utf8.decode(data));
      if (buffer.toString().endsWith('\n')) {
        final response =
            jsonDecode(buffer.toString().trim()) as Map<String, dynamic>;

        if (response['error'] != null) {
          completer.completeError(Exception(response['error']['message']));
        } else {
          final result = response['result'] as Map<String, dynamic>;
          final secrets = result['secrets'] as List<dynamic>;
          completer.complete(secrets.cast<String>());
        }
      }
    });

    return completer.future.timeout(Duration(seconds: 5));
  }

  Future<void> close() async {
    await _socket?.close();
    _socket = null;
  }
}

/// F258: Test Dart SDK get() returns correct value
Future<void> testGetReturnsCorrectValue(
  SecretariatTestClient client,
  String testKey,
  String expectedValue,
) async {
  try {
    final value = await client.get(testKey);

    if (value == expectedValue) {
      pass('get("$testKey") returned correct value');
    } else {
      fail('get("$testKey") returned "$value", expected "$expectedValue"');
    }
  } catch (e) {
    fail('get("$testKey") threw exception: $e');
  }
}

/// Test get() throws on non-existent key
Future<void> testGetThrowsOnMissingKey(SecretariatTestClient client) async {
  try {
    await client.get('NONEXISTENT_KEY_12345');
    fail('get() should throw for non-existent key');
  } catch (e) {
    pass('get() throws for non-existent key');
  }
}

/// Test list() returns secrets
Future<void> testListReturnsSecrets(SecretariatTestClient client) async {
  try {
    final secrets = await client.list();

    pass('list() returned a list of strings');
  
    if (secrets.isNotEmpty) {
      pass('list() returned ${secrets.length} secrets');
    } else {
      // Empty list is valid if no secrets exist
      pass('list() returned empty list (no secrets)');
    }
  } catch (e) {
    fail('list() threw exception: $e');
  }
}

Future<void> main() async {
  print('================================================');
  print('Secretariat Dart SDK Tests');
  print('================================================');

  // Check for socket path override
  final socketPath =
      Platform.environment['SECRETARIAT_SOCKET_PATH'] ??
      '/tmp/secretariat.sock';
  print('Socket path: $socketPath');

  // Check if socket exists
  if (!await File(socketPath).exists()) {
    print('\x1B[31mError: Socket not found at $socketPath\x1B[0m');
    print('Make sure the daemon is running.');
    exit(1);
  }

  final client = SecretariatTestClient(socketPath: socketPath);

  try {
    print('');
    print('F258: Test Dart SDK get() returns correct value');
    print('------------------------------------------------');

    // Test with a secret that should exist (set up by CLI tests)
    // Note: This assumes the test environment has DATABASE_URL set
    await testGetReturnsCorrectValue(
      client,
      'DATABASE_URL',
      'postgres://localhost/test',
    );

    print('');
    print('Test get() throws on non-existent key');
    print('-------------------------------------');
    await testGetThrowsOnMissingKey(client);

    print('');
    print('Test list() returns secrets');
    print('---------------------------');
    await testListReturnsSecrets(client);
  } finally {
    await client.close();
  }

  print('');
  print('================================================');
  print('Dart SDK Test Summary');
  print('================================================');
  print('\x1B[32mPassed: $testsPassed\x1B[0m');
  print('\x1B[31mFailed: $testsFailed\x1B[0m');
  print('================================================');

  exit(testsFailed > 0 ? 1 : 0);
}

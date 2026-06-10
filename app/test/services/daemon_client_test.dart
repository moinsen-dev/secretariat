// Unit tests for DaemonClient heartbeat mechanism
//
// Tests are isolated from real socket I/O via TestableDaemonClient.
// Uses FakeAsync for timer control without real wall-clock waiting.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretariat_app/services/daemon_client.dart';

/// A [DaemonClient] subclass that replaces real I/O with test-friendly stubs.
///
/// - [heartbeatShouldRemainActive] always returns `true` so the heartbeat
///   timer continues ticking and calling [healthCheck] in tests.
/// - [connect()] only tracks the call count without opening a socket.
/// - [healthCheck()] returns an empty map and tracks the call count.
class TestableDaemonClient extends DaemonClient {
  int connectCallCount = 0;
  int healthCheckCallCount = 0;

  @override
  bool get heartbeatShouldRemainActive => true;

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  Future<Map<String, dynamic>> healthCheck() async {
    healthCheckCallCount++;
    return <String, dynamic>{};
  }
}

void main() {
  group('DaemonClient heartbeat', () {
    late TestableDaemonClient client;

    setUp(() {
      client = TestableDaemonClient();
    });

    tearDown(() {
      client.stopHeartbeat();
    });

    test(
      'startHeartbeat() creates a periodic Timer that fires every 15 seconds',
      () {
        FakeAsync().run((async) {
          client.startHeartbeat();

          // Timer should exist and be active immediately
          expect(client.heartbeatTimer, isNotNull);
          expect(client.heartbeatTimer!.isActive, isTrue);

          // The timer fires every 15s — advance by 15s and verify healthCheck was called
          async.elapse(const Duration(seconds: 15));
          expect(client.healthCheckCallCount, equals(1));

          // Advance another 15s → second tick
          async.elapse(const Duration(seconds: 15));
          expect(client.healthCheckCallCount, equals(2));

          // Advance another 15s → third tick
          async.elapse(const Duration(seconds: 15));
          expect(client.healthCheckCallCount, equals(3));
        });
      },
    );

    test(
      'cleanup() stops the heartbeat timer and clears socket state',
      () {
        FakeAsync().run((async) {
          client.startHeartbeat();
          expect(client.heartbeatTimer, isNotNull);
          expect(client.heartbeatTimer!.isActive, isTrue);

          client.cleanup();

          // Timer must be cancelled
          expect(client.heartbeatTimer, isNull);
          // Socket reference must be cleared
          expect(client.socket, isNull);
          // Disposed flag must be set
          expect(client.isDisposed, isTrue);
        });
      },
    );

    test(
      'heartbeat does not fire after cleanup()',
      () {
        FakeAsync().run((async) {
          client.startHeartbeat();
          client.cleanup();

          // Advance well past the timer interval
          async.elapse(const Duration(seconds: 30));

          // healthCheck should never have been called
          expect(client.healthCheckCallCount, equals(0));
        });
      },
    );

    test(
      'ensureConnected() calls connect() when socket is null (disconnected)',
      () async {
        // Default state: socket is null → disconnected
        expect(client.socket, isNull);
        expect(client.connectCallCount, equals(0));

        await client.ensureConnected();

        // Should have triggered a reconnect
        expect(client.connectCallCount, equals(1));
      },
    );
  });
}

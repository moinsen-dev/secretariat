import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretariat_app/services/daemon_client.dart';

class _MockJsonRpcServer {
  _MockJsonRpcServer({required this.socketPath, required this.handler});

  final String socketPath;
  final FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>) handler;

  final List<Map<String, dynamic>> requests = [];
  final List<Socket> _connections = [];
  ServerSocket? _server;

  Future<void> start() async {
    final socketFile = File(socketPath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
    }

    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );

    _server!.listen((connection) {
      _connections.add(connection);
      connection
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {
            if (line.trim().isEmpty) {
              return;
            }

            final request = jsonDecode(line) as Map<String, dynamic>;
            requests.add(request);

            final payload = await handler(request);
            final response = <String, dynamic>{
              'jsonrpc': '2.0',
              'id': request['id'],
              ...payload,
            };

            connection.write('${jsonEncode(response)}\n');
            await connection.flush();
          });
    });
  }

  Future<void> stop() async {
    for (final connection in _connections) {
      await connection.close();
    }
    await _server?.close();
    final socketFile = File(socketPath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
    }
  }
}

void main() {
  group('DaemonClient Contract', () {
    late String socketPath;
    DaemonClient? client;
    _MockJsonRpcServer? server;

    tearDown(() async {
      if (client != null) {
        await client!.disconnect();
      }
      if (server != null) {
        await server!.stop();
      }
    });

    test('getSecret sends app_id and parses result', () async {
      socketPath =
          '${Directory.systemTemp.path}/sec-app-${DateTime.now().microsecondsSinceEpoch}.sock';
      server = _MockJsonRpcServer(
        socketPath: socketPath,
        handler: (request) {
          return {
            'result': {
              'name': request['params']['name'],
              'value': 'test-secret',
            },
          };
        },
      );
      await server!.start();

      client = DaemonClient(
        socketPathOverride: socketPath,
        appId: 'flutter-test',
      );
      await client!.connect();
      final result = await client!.getSecret('OPENAI_API_KEY');

      expect(result['value'], equals('test-secret'));
      expect(server!.requests, hasLength(1));
      expect(server!.requests.first['method'], equals('secret.get'));
      expect(
        (server!.requests.first['params'] as Map<String, dynamic>)['app_id'],
        equals('flutter-test'),
      );
    });

    test(
      'listEnvironments derives unique environments from secret.list',
      () async {
        socketPath =
            '${Directory.systemTemp.path}/sec-app-${DateTime.now().microsecondsSinceEpoch}.sock';
        server = _MockJsonRpcServer(
          socketPath: socketPath,
          handler: (_) {
            return {
              'result': {
                'secrets': [
                  {'name': 'A', 'environment': 'prod'},
                  {'name': 'B', 'environment': 'dev'},
                  {'name': 'C', 'environment': 'prod'},
                ],
              },
            };
          },
        );
        await server!.start();

        client = DaemonClient(socketPathOverride: socketPath);
        await client!.connect();
        final environments = await client!.listEnvironments();

        expect(environments, equals(['default', 'dev', 'prod']));
        expect(server!.requests.first['method'], equals('secret.list'));
      },
    );

    test(
      'getAgentPermissions maps agent.explain payload to secret names',
      () async {
        socketPath =
            '${Directory.systemTemp.path}/sec-app-${DateTime.now().microsecondsSinceEpoch}.sock';
        server = _MockJsonRpcServer(
          socketPath: socketPath,
          handler: (_) {
            return {
              'result': {
                'agent_id': 'claude-code',
                'permissions': [
                  {'secret': 'OPENAI_API_KEY', 'environment': 'default'},
                  {'secret': 'OPENAI_API_KEY', 'environment': 'prod'},
                  {'secret': 'STRIPE_SECRET_KEY', 'environment': 'default'},
                ],
              },
            };
          },
        );
        await server!.start();

        client = DaemonClient(socketPathOverride: socketPath);
        await client!.connect();
        final permissions = await client!.getAgentPermissions('claude-code');

        expect(permissions, equals(['OPENAI_API_KEY', 'STRIPE_SECRET_KEY']));
        expect(server!.requests.first['method'], equals('agent.explain'));
      },
    );

    test('sendRequest surfaces daemon error payload', () async {
      socketPath =
          '${Directory.systemTemp.path}/sec-app-${DateTime.now().microsecondsSinceEpoch}.sock';
      server = _MockJsonRpcServer(
        socketPath: socketPath,
        handler: (_) {
          return {
            'error': {
              'code': -32602,
              'message': 'Missing required parameter: app_id',
            },
          };
        },
      );
      await server!.start();

      client = DaemonClient(socketPathOverride: socketPath);
      await client!.connect();

      expect(
        () => client!.sendRequest('secret.get', {'name': 'OPENAI_API_KEY'}),
        throwsA(isA<DaemonException>()),
      );
    });
  });
}

# Secretariat App

Flutter desktop UI for the local Secretariat daemon.

## Test Strategy

- Default `flutter test` run is daemon-independent and CI-safe.
- Daemon integration tests are opt-in and disabled by default.

### Run Unit/Contract Tests (default)

```bash
cd app
flutter test
```

### Run Daemon Integration Tests

Set this env var to enable integration tests that require a running daemon:

```bash
cd app
SECRETARIAT_RUN_INTEGRATION_TESTS=1 flutter test test/daemon_client_integration_test.dart
```

You can point tests to a custom socket path with:

```bash
SECRETARIAT_SOCKET_PATH=/path/to/secretariat.sock
```

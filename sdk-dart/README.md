# Secretariat Dart SDK

Lightweight Dart SDK for communicating with the Secretariat daemon.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  secretariat: ^0.1.0
```

## Usage

```dart
import 'package:secretariat/secretariat.dart';

void main() async {
  final client = Secretariat();

  try {
    // Get a single secret
    final apiKey = await client.get('OPENAI_API_KEY');
    print('API Key: $apiKey');

    // Get multiple secrets
    final secrets = await client.getMany([
      'OPENAI_API_KEY',
      'DATABASE_URL',
    ]);

    // List all secret names
    final names = await client.list();
    print('Available secrets: $names');
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.close();
  }
}
```

## Features

- **Minimal dependencies** - No external dependencies
- **Async-first API** - Uses Future-based async/await
- **Cross-platform** - Works on macOS, Linux, and Windows
- **Type-safe** - Full Dart type safety
- **Error handling** - Clear exception types

## API

### `Secretariat()`

Create a new Secretariat client.

**Parameters:**
- `socketPath` (optional) - Custom Unix socket or named pipe path
- `timeout` (optional) - Request timeout (default: 5 seconds)

### `Future<String> get(String key)`

Retrieve a secret value by key.

**Throws:** `SecretariatException` if secret not found or permission denied.

### `Future<Map<String, String>> getMany(List<String> keys)`

Retrieve multiple secrets at once.

### `Future<List<String>> list()`

List all available secret names (not values).

### `Future<void> close()`

Close the connection to the daemon. Always call this when done.

## Platform Support

- **macOS** - Unix domain socket at `/tmp/secretariat.sock`
- **Linux** - Unix domain socket at `/tmp/secretariat.sock`
- **Windows** - Named pipe at `\\.\pipe\secretariat`

## License

MIT

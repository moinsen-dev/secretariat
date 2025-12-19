# Dart SDK Guide

The Secretariat Dart SDK provides seamless integration for Flutter and Dart applications.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  secretariat: ^0.1.0
```

Then run:

```bash
flutter pub get
# or
dart pub get
```

## Quick Start

```dart
import 'package:secretariat/secretariat.dart';

void main() async {
  final client = Secretariat();

  // Get a single secret
  final apiKey = await client.get('OPENAI_API_KEY');
  print('API Key: $apiKey');

  // Get multiple secrets
  final secrets = await client.getMany([
    'OPENAI_API_KEY',
    'DATABASE_URL',
  ]);
  print('OpenAI: ${secrets['OPENAI_API_KEY']}');

  // List all secret names
  final names = await client.list();
  print('Available secrets: $names');

  // Clean up
  await client.close();
}
```

## API Reference

### `Secretariat` Class

The main client class for interacting with the Secretariat daemon.

#### Constructor

```dart
Secretariat({
  String? socketPath,
  Duration timeout = const Duration(seconds: 5),
})
```

**Parameters:**
- `socketPath` - Custom path to Unix socket (optional)
- `timeout` - Request timeout (default: 5 seconds)

#### Methods

##### `get(String key)`

Retrieve a single secret value.

```dart
Future<String> get(String key)
```

**Returns:** The decrypted secret value.

**Throws:** `SecretariatException` if:
- Secret not found
- Permission denied
- Daemon not running

**Example:**
```dart
try {
  final apiKey = await client.get('OPENAI_API_KEY');
  print('Got key: $apiKey');
} on SecretariatException catch (e) {
  print('Error: ${e.message}');
}
```

##### `getMany(List<String> keys)`

Retrieve multiple secrets at once.

```dart
Future<Map<String, String>> getMany(List<String> keys)
```

**Returns:** Map of key-value pairs.

**Example:**
```dart
final secrets = await client.getMany([
  'OPENAI_API_KEY',
  'ANTHROPIC_API_KEY',
  'DATABASE_URL',
]);

// Use the secrets
final openai = OpenAI(apiKey: secrets['OPENAI_API_KEY']!);
```

##### `list()`

List all available secret names.

```dart
Future<List<String>> list()
```

**Returns:** List of secret names (not values).

**Example:**
```dart
final secretNames = await client.list();
print('Found ${secretNames.length} secrets');
```

##### `close()`

Close the connection to the daemon.

```dart
Future<void> close()
```

**Example:**
```dart
await client.close();
```

### `SecretariatException` Class

Exception thrown by SDK operations.

```dart
class SecretariatException implements Exception {
  final String message;
  final int? code;
}
```

## Flutter Integration

### Provider Pattern

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secretariat/secretariat.dart';

// Create a provider
class SecretsProvider extends ChangeNotifier {
  final _client = Secretariat();
  Map<String, String> _secrets = {};
  bool _isLoading = false;

  Map<String, String> get secrets => _secrets;
  bool get isLoading => _isLoading;

  Future<void> loadSecrets(List<String> keys) async {
    _isLoading = true;
    notifyListeners();

    try {
      _secrets = await _client.getMany(keys);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

// Use in your app
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SecretsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SecretsProvider>();

    if (provider.isLoading) {
      return const CircularProgressIndicator();
    }

    return Text('API Key: ${provider.secrets['OPENAI_API_KEY']}');
  }
}
```

### Riverpod Pattern

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secretariat/secretariat.dart';

// Create providers
final secretariatProvider = Provider<Secretariat>((ref) {
  final client = Secretariat();
  ref.onDispose(() => client.close());
  return client;
});

final apiKeyProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(secretariatProvider);
  return client.get('OPENAI_API_KEY');
});

// Use in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKey = ref.watch(apiKeyProvider);

    return apiKey.when(
      data: (key) => Text('Key: $key'),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

## Environment Fallback

The SDK automatically falls back to environment variables when the daemon is unavailable:

```dart
import 'dart:io';

Future<String> getSecretOrEnv(String key) async {
  final client = Secretariat();

  try {
    return await client.get(key);
  } on SecretariatException {
    // Fallback to environment variable
    final value = Platform.environment[key];
    if (value != null) return value;
    throw SecretariatException('Secret $key not found');
  } finally {
    await client.close();
  }
}
```

## Best Practices

### 1. Don't Store Secrets in State

```dart
// ❌ Bad: Storing secret in widget state
class _MyWidgetState extends State<MyWidget> {
  String? _apiKey;  // Don't do this!

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  void _loadApiKey() async {
    _apiKey = await Secretariat().get('API_KEY');
  }
}

// ✅ Good: Fetch when needed
class ApiService {
  final _client = Secretariat();

  Future<String> makeRequest() async {
    final apiKey = await _client.get('API_KEY');
    // Use immediately, don't store
    return await http.get(
      Uri.parse('https://api.example.com'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
  }
}
```

### 2. Use Connection Pooling

```dart
// ✅ Reuse a single client instance
class SecretService {
  static final Secretariat _client = Secretariat();

  static Future<String> get(String key) => _client.get(key);
}
```

### 3. Handle Errors Gracefully

```dart
Future<void> initializeApp() async {
  try {
    final secrets = await Secretariat().getMany([
      'OPENAI_API_KEY',
      'DATABASE_URL',
    ]);
    // Configure services...
  } on SecretariatException catch (e) {
    if (e.code == 4) {
      // Daemon not running - show setup instructions
      showSetupDialog();
    } else if (e.code == 5) {
      // Vault locked - prompt for unlock
      await promptUnlock();
    } else {
      // Other error
      showErrorSnackbar(e.message);
    }
  }
}
```

## Troubleshooting

### Daemon Not Running

```dart
try {
  await client.get('KEY');
} on SecretariatException catch (e) {
  if (e.message.contains('Failed to connect')) {
    print('Start the daemon: secd');
  }
}
```

### Permission Denied

Make sure your app is registered:

```bash
sec grant my-flutter-app OPENAI_API_KEY
```

### Timeout Issues

Increase the timeout for slow systems:

```dart
final client = Secretariat(
  timeout: const Duration(seconds: 30),
);
```

## Example App

See the [example directory](https://github.com/secretariat/secretariat/tree/main/sdk-dart/example) for a complete Flutter app demonstrating:

- Secret retrieval
- Error handling
- Loading states
- Provider integration

// F140-F142: Application model for Secretariat app
//
// Features:
// - F140: Create lib/models/application.dart file
// - F141: Define Application class with id, name, path, permissions fields
// - F142: Implement JSON serialization for Application model

/// F141: Define Application class with id, name, path, permissions fields
///
/// Represents an application registered with the daemon.
class Application {
  /// Unique identifier for the application
  final String id;

  /// Application name
  final String name;

  /// Path to the application binary
  final String? path;

  /// Bundle ID (macOS) or package name (other platforms)
  final String? bundleId;

  /// Stable fingerprint for identification
  final String? fingerprint;

  /// When the application was registered
  final DateTime registeredAt;

  /// When the application last accessed secrets
  final DateTime? lastAccess;

  /// List of secret IDs this application has permission to access
  final List<String> permissions;

  /// Create a new Application instance
  const Application({
    required this.id,
    required this.name,
    this.path,
    this.bundleId,
    this.fingerprint,
    required this.registeredAt,
    this.lastAccess,
    this.permissions = const [],
  });

  /// F142: Implement JSON serialization for Application model
  ///
  /// Creates an Application instance from a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final json = {
  ///   'id': 'app-123',
  ///   'name': 'MyApp',
  ///   'path': '/usr/local/bin/myapp',
  ///   'registered_at': '2024-01-01T00:00:00Z',
  ///   'permissions': ['secret-1', 'secret-2'],
  /// };
  /// final app = Application.fromJson(json);
  /// ```
  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String?,
      bundleId: json['bundle_id'] as String?,
      fingerprint: json['fingerprint'] as String?,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      lastAccess: json['last_access'] != null
          ? DateTime.parse(json['last_access'] as String)
          : null,
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'] as List)
          : const [],
    );
  }

  /// F142: Implement JSON serialization for Application model
  ///
  /// Converts the Application instance to a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final app = Application(
  ///   id: 'app-123',
  ///   name: 'MyApp',
  ///   registeredAt: DateTime.now(),
  ///   permissions: ['secret-1', 'secret-2'],
  /// );
  /// final json = app.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (path != null) 'path': path,
      if (bundleId != null) 'bundle_id': bundleId,
      if (fingerprint != null) 'fingerprint': fingerprint,
      'registered_at': registeredAt.toIso8601String(),
      if (lastAccess != null) 'last_access': lastAccess!.toIso8601String(),
      'permissions': permissions,
    };
  }

  /// Creates a copy of this Application with specified fields replaced.
  ///
  /// This enables immutable updates to Application instances.
  ///
  /// Example:
  /// ```dart
  /// final original = Application(
  ///   id: 'app-123',
  ///   name: 'MyApp',
  ///   registeredAt: DateTime.now(),
  /// );
  ///
  /// // Add permissions
  /// final updated = original.copyWith(
  ///   permissions: ['secret-1', 'secret-2'],
  /// );
  /// ```
  Application copyWith({
    String? id,
    String? name,
    String? path,
    String? bundleId,
    String? fingerprint,
    DateTime? registeredAt,
    DateTime? lastAccess,
    List<String>? permissions,
  }) {
    return Application(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      bundleId: bundleId ?? this.bundleId,
      fingerprint: fingerprint ?? this.fingerprint,
      registeredAt: registeredAt ?? this.registeredAt,
      lastAccess: lastAccess ?? this.lastAccess,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  String toString() {
    return 'Application(id: $id, name: $name, path: $path, permissions: ${permissions.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Application &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.bundleId == bundleId &&
        other.fingerprint == fingerprint &&
        other.registeredAt == registeredAt &&
        other.lastAccess == lastAccess &&
        _listEquals(other.permissions, permissions);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      path,
      bundleId,
      fingerprint,
      registeredAt,
      lastAccess,
      Object.hashAll(permissions),
    );
  }

  /// Helper to compare lists for equality
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

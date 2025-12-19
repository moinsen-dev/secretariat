// F135-F139: Secret model for Secretariat app
//
// Features:
// - F135: Create lib/models/secret.dart file
// - F136: Define Secret class with id, name, value, provider, createdAt fields
// - F137: Implement Secret.fromJson(Map<String, dynamic> json) factory
// - F138: Implement Secret.toJson() -> Map<String, dynamic> method
// - F139: Implement Secret.copyWith({...}) for immutability

/// F136: Define Secret class with id, name, value, provider, createdAt fields
///
/// Represents a secret stored in the vault.
class Secret {
  /// Unique identifier for the secret
  final String id;

  /// Secret key name (e.g., OPENAI_API_KEY)
  final String name;

  /// Secret value (encrypted in storage, decrypted in memory)
  /// Null when listing secrets (secret.list returns metadata only)
  final String? value;

  /// Provider name (e.g., openai, stripe, anthropic)
  final String? provider;

  /// Environment (e.g., default, dev, staging, prod)
  final String? environment;

  /// When the secret was created
  final DateTime createdAt;

  /// When the secret was last updated
  final DateTime? updatedAt;

  /// When the secret was last rotated
  final DateTime? rotatedAt;

  /// Optional notes about the secret
  final String? notes;

  /// Create a new Secret instance
  const Secret({
    required this.id,
    required this.name,
    this.value,
    this.provider,
    this.environment,
    required this.createdAt,
    this.updatedAt,
    this.rotatedAt,
    this.notes,
  });

  /// F137: Implement Secret.fromJson factory
  ///
  /// Creates a Secret instance from a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final json = {
  ///   'id': '123',
  ///   'name': 'OPENAI_API_KEY',
  ///   'value': 'sk-abc123...',
  ///   'provider': 'openai',
  ///   'created_at': '2024-01-01T00:00:00Z',
  /// };
  /// final secret = Secret.fromJson(json);
  /// ```
  factory Secret.fromJson(Map<String, dynamic> json) {
    return Secret(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as String?,
      provider: json['provider'] as String?,
      environment: json['environment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      rotatedAt: json['rotated_at'] != null
          ? DateTime.parse(json['rotated_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  /// F138: Implement Secret.toJson method
  ///
  /// Converts the Secret instance to a JSON map.
  ///
  /// Example:
  /// ```dart
  /// final secret = Secret(
  ///   id: '123',
  ///   name: 'OPENAI_API_KEY',
  ///   value: 'sk-abc123...',
  ///   provider: 'openai',
  ///   createdAt: DateTime.now(),
  /// );
  /// final json = secret.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      if (provider != null) 'provider': provider,
      if (environment != null) 'environment': environment,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (rotatedAt != null) 'rotated_at': rotatedAt!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }

  /// F139: Implement Secret.copyWith({...}) for immutability
  ///
  /// Creates a copy of this Secret with specified fields replaced.
  ///
  /// This enables immutable updates to Secret instances.
  ///
  /// Example:
  /// ```dart
  /// final original = Secret(
  ///   id: '123',
  ///   name: 'OPENAI_API_KEY',
  ///   value: 'old-value',
  ///   provider: 'openai',
  ///   createdAt: DateTime.now(),
  /// );
  ///
  /// // Update only the value
  /// final updated = original.copyWith(value: 'new-value');
  /// ```
  Secret copyWith({
    String? id,
    String? name,
    String? value,
    String? provider,
    String? environment,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? rotatedAt,
    String? notes,
  }) {
    return Secret(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      provider: provider ?? this.provider,
      environment: environment ?? this.environment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rotatedAt: rotatedAt ?? this.rotatedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Secret(id: $id, name: $name, provider: $provider, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Secret &&
        other.id == id &&
        other.name == name &&
        other.value == value &&
        other.provider == provider &&
        other.environment == environment &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.rotatedAt == rotatedAt &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      value,
      provider,
      environment,
      createdAt,
      updatedAt,
      rotatedAt,
      notes,
    );
  }
}

/// Model for an audit log entry
///
/// Represents a single entry in the audit log tracking
/// all secret access and operations.
class AuditEntry {
  /// Unique identifier for the audit entry
  final int id;

  /// Timestamp when the action occurred
  final String timestamp;

  /// Application identifier (fingerprint) or 'system' for CLI
  final String appId;

  /// Name of the secret that was accessed
  final String secretName;

  /// Action performed (read, write, delete, grant, revoke, rotate, etc.)
  final String action;

  /// Whether the action succeeded
  final bool success;

  /// Optional additional details or error message
  final String? details;

  AuditEntry({
    required this.id,
    required this.timestamp,
    required this.appId,
    required this.secretName,
    required this.action,
    required this.success,
    this.details,
  });

  /// Create an AuditEntry from JSON (daemon response)
  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as int,
      timestamp: json['timestamp'] as String,
      appId: json['app_id'] as String? ?? 'unknown',
      secretName: json['secret_name'] as String? ?? '',
      action: json['action'] as String,
      success: json['success'] as bool,
      details: json['details'] as String?,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'app_id': appId,
      'secret_name': secretName,
      'action': action,
      'success': success,
      'details': details,
    };
  }

  /// Get a human-readable description of the action
  String get actionDescription {
    switch (action) {
      case 'read':
        return 'Read secret';
      case 'write':
        return 'Updated secret';
      case 'delete':
        return 'Deleted secret';
      case 'grant':
        return 'Granted access';
      case 'revoke':
        return 'Revoked access';
      case 'rotate':
        return 'Rotated secret';
      case 'register':
        return 'Registered app';
      default:
        return action;
    }
  }

  /// Get an icon name for the action
  String get actionIcon {
    switch (action) {
      case 'read':
        return 'visibility';
      case 'write':
        return 'edit';
      case 'delete':
        return 'delete';
      case 'grant':
        return 'check_circle';
      case 'revoke':
        return 'block';
      case 'rotate':
        return 'refresh';
      case 'register':
        return 'app_registration';
      default:
        return 'info';
    }
  }

  /// Parse timestamp to DateTime
  DateTime get dateTime {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Get a formatted timestamp string
  String get formattedTime {
    final dt = dateTime;
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
  }
}

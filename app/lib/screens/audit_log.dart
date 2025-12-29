import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audit_entry.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';

/// Screen displaying the audit log of all secret access and operations
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _isLoading = true;
  String? _error;
  String? _filterAppId;

  @override
  void initState() {
    super.initState();
    _loadAuditLog();
  }

  Future<void> _loadAuditLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<VaultProvider>();
      await provider.loadAuditLog(limit: 100, appId: _filterAppId);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceDark,
        title: Text(
          'Audit Log',
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimaryDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textSecondaryDark),
            onPressed: _loadAuditLog,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: textSecondaryDark),
            tooltip: 'Filter by app',
            onSelected: (value) {
              setState(() {
                _filterAppId = value == 'all' ? null : value;
              });
              _loadAuditLog();
            },
            itemBuilder: (context) {
              final provider = context.read<VaultProvider>();
              final apps = provider.applications;
              return [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('All Applications'),
                ),
                const PopupMenuDivider(),
                ...apps.map(
                  (app) => PopupMenuItem(
                    value: app.fingerprint,
                    child: Text(app.name),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Group audit entries by date for display with headers (per wireframe 3.14)
  List<dynamic> _groupEntriesByDate(List<AuditEntry> entries) {
    if (entries.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final result = <dynamic>[];
    String? lastDateLabel;

    for (final entry in entries) {
      final dt = entry.dateTime;
      final entryDate = DateTime(dt.year, dt.month, dt.day);

      String dateLabel;
      if (entryDate == today) {
        dateLabel = 'TODAY';
      } else if (entryDate == yesterday) {
        dateLabel = 'YESTERDAY';
      } else {
        // Format as "Dec 25, 2025"
        dateLabel = _formatDateLabel(entryDate);
      }

      // Add header if this is a new date group
      if (dateLabel != lastDateLabel) {
        result.add(dateLabel);
        lastDateLabel = dateLabel;
      }

      result.add(entry);
    }

    return result;
  }

  String _formatDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load audit log',
              style: TextStyle(
                color: textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: textSecondaryDark, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAuditLog,
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final provider = context.watch<VaultProvider>();
    final entries = provider.auditEntries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: textSecondaryDark.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No audit entries yet',
              style: TextStyle(
                color: textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secret access will be logged here',
              style: TextStyle(color: textSecondaryDark, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Group entries by date (per wireframe 3.14)
    final groupedEntries = _groupEntriesByDate(entries);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final item = groupedEntries[index];
        if (item is String) {
          // Date header
          return _DateGroupHeader(label: item);
        } else {
          // Audit entry
          return _AuditEntryTile(entry: item as AuditEntry);
        }
      },
    );
  }
}

class _AuditEntryTile extends StatelessWidget {
  final AuditEntry entry;

  const _AuditEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: entry.success ? borderDark : errorColor.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getActionColor(entry.action).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getActionIcon(entry.action),
            color: _getActionColor(entry.action),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.secretName.isNotEmpty ? entry.secretName : entry.action,
                style: TextStyle(
                  color: textPrimaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!entry.success)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FAILED',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  entry.actionDescription,
                  style: TextStyle(
                    color: _getActionColor(entry.action),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'by ${_formatAppId(entry.appId)}',
                  style: TextStyle(color: textSecondaryDark, fontSize: 12),
                ),
              ],
            ),
            if (entry.details != null && entry.details!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.details!,
                style: TextStyle(
                  color: textSecondaryDark,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Text(
          entry.formattedTime,
          style: TextStyle(color: textSecondaryDark, fontSize: 11),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'read':
        return Icons.visibility;
      case 'write':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'grant':
        return Icons.check_circle;
      case 'revoke':
        return Icons.block;
      case 'rotate':
        return Icons.refresh;
      case 'register':
        return Icons.app_registration;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'read':
        return accentColor;
      case 'write':
        return warningColor;
      case 'delete':
        return errorColor;
      case 'grant':
        return successColor;
      case 'revoke':
        return errorColor;
      case 'rotate':
        return secretColor;
      case 'register':
        return applicationColor;
      default:
        return textSecondaryDark;
    }
  }

  String _formatAppId(String appId) {
    if (appId == 'system' || appId == 'cli') {
      return 'CLI';
    }
    if (appId == 'flutter-app') {
      return 'App';
    }
    // Show abbreviated fingerprint
    if (appId.length > 12) {
      return '${appId.substring(0, 8)}...';
    }
    return appId;
  }
}

/// Date group header for audit log entries (per wireframe 3.14)
class _DateGroupHeader extends StatelessWidget {
  final String label;

  const _DateGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: textSecondaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

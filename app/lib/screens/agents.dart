import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';

/// AI Agents management screen
///
/// Allows users to:
/// - View registered AI agents
/// - Register new AI agents
/// - Grant/revoke access to secrets
/// - View agent permissions
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<String>> _agentPermissions = {};

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      await provider.loadAgents();

      // Load permissions for each agent
      _agentPermissions = {};
      for (final agent in provider.agents) {
        final agentId = agent['id'] as String? ?? agent['agent_id'] as String?;
        if (agentId != null) {
          final permissions = await provider.getAgentPermissions(agentId);
          _agentPermissions[agentId] = permissions;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load agents: $e';
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
          'AI Agents',
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
            icon: Icon(Icons.refresh, color: textPrimaryDark),
            onPressed: _loadAgents,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.add, color: accentColor),
            onPressed: _showRegisterAgentDialog,
            tooltip: 'Register Agent',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: accentColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAgents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Consumer<VaultProvider>(
      builder: (context, provider, child) {
        final agents = provider.agents;

        if (agents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.smart_toy_outlined, color: textSecondaryDark, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No AI Agents Registered',
                  style: TextStyle(
                    color: textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register an AI agent to grant it access to secrets',
                  style: TextStyle(color: textSecondaryDark, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showRegisterAgentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Register Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: agents.length,
          itemBuilder: (context, index) => _buildAgentCard(agents[index]),
        );
      },
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final agentId = agent['id'] as String? ?? agent['agent_id'] as String? ?? 'Unknown';
    final description = agent['description'] as String?;
    final createdAt = agent['created_at'] as String?;
    final permissions = _agentPermissions[agentId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderDark),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.smart_toy, color: accentColor, size: 24),
        ),
        title: Text(
          agentId,
          style: TextStyle(
            color: textPrimaryDark,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: textSecondaryDark, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.key, size: 12, color: textSecondaryDark),
                const SizedBox(width: 4),
                Text(
                  '${permissions.length} secret${permissions.length == 1 ? '' : 's'}',
                  style: TextStyle(color: textSecondaryDark, fontSize: 12),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 12, color: textSecondaryDark),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(color: textSecondaryDark, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: textSecondaryDark),
          color: surfaceVariantDark,
          onSelected: (value) => _handleAgentAction(value, agentId),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'grant',
              child: Row(
                children: [
                  Icon(Icons.add, color: successColor, size: 20),
                  const SizedBox(width: 12),
                  Text('Grant Access', style: TextStyle(color: textPrimaryDark)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'revoke_all',
              child: Row(
                children: [
                  Icon(Icons.remove_circle, color: errorColor, size: 20),
                  const SizedBox(width: 12),
                  Text('Revoke All', style: TextStyle(color: textPrimaryDark)),
                ],
              ),
            ),
          ],
        ),
        children: [
          if (permissions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No secrets granted to this agent',
                style: TextStyle(color: textSecondaryDark, fontSize: 13),
              ),
            )
          else
            ...permissions.map((secretName) => ListTile(
                  leading: Icon(Icons.key, color: secretColor, size: 20),
                  title: Text(
                    secretName,
                    style: TextStyle(color: textPrimaryDark, fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: errorColor, size: 20),
                    onPressed: () => _revokeAccess(agentId, secretName),
                    tooltip: 'Revoke Access',
                  ),
                )),
        ],
      ),
    );
  }

  void _handleAgentAction(String action, String agentId) {
    switch (action) {
      case 'grant':
        _showGrantAccessDialog(agentId);
        break;
      case 'revoke_all':
        _showRevokeAllConfirmation(agentId);
        break;
    }
  }

  void _showRegisterAgentDialog() {
    final agentIdController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text(
          'Register AI Agent',
          style: TextStyle(color: textPrimaryDark),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: agentIdController,
                style: TextStyle(color: textPrimaryDark),
                decoration: InputDecoration(
                  labelText: 'Agent ID',
                  labelStyle: TextStyle(color: textSecondaryDark),
                  hintText: 'e.g., claude-code, cursor, copilot',
                  hintStyle: TextStyle(color: textSecondaryDark.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: TextStyle(color: textPrimaryDark),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: textSecondaryDark),
                  hintText: 'e.g., Claude Code AI assistant',
                  hintStyle: TextStyle(color: textSecondaryDark.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
            ),
            onPressed: () async {
              final agentId = agentIdController.text.trim();
              if (agentId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Agent ID is required')),
                );
                return;
              }

              Navigator.pop(dialogContext);
              await _registerAgent(
                agentId,
                descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              );
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerAgent(String agentId, String? description) async {
    try {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      await provider.registerAgent(agentId, description: description);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent "$agentId" registered successfully'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register agent: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _showGrantAccessDialog(String agentId) {
    final provider = Provider.of<VaultProvider>(context, listen: false);
    final secrets = provider.secrets;
    final existingPermissions = _agentPermissions[agentId] ?? [];

    // Filter out secrets already granted
    final availableSecrets = secrets
        .where((s) => !existingPermissions.contains(s.name))
        .toList();

    if (availableSecrets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All secrets already granted to this agent')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text(
          'Grant Access to $agentId',
          style: TextStyle(color: textPrimaryDark),
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: availableSecrets.length,
            itemBuilder: (context, index) {
              final secret = availableSecrets[index];
              return ListTile(
                leading: Icon(Icons.key, color: secretColor),
                title: Text(
                  secret.name,
                  style: TextStyle(color: textPrimaryDark),
                ),
                subtitle: secret.provider != null
                    ? Text(
                        secret.provider!,
                        style: TextStyle(color: textSecondaryDark, fontSize: 12),
                      )
                    : null,
                trailing: IconButton(
                  icon: Icon(Icons.add_circle, color: successColor),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _grantAccess(agentId, secret.name);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _grantAccess(String agentId, String secretName) async {
    try {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      await provider.grantAgentAccess(agentId, secretName);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Granted "$secretName" access to $agentId'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to grant access: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  Future<void> _revokeAccess(String agentId, String secretName) async {
    try {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      await provider.revokeAgentAccess(agentId, secretName);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoked "$secretName" access from $agentId'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke access: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _showRevokeAllConfirmation(String agentId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Row(
          children: [
            Icon(Icons.warning, color: warningColor),
            const SizedBox(width: 12),
            Text('Revoke All Access', style: TextStyle(color: textPrimaryDark)),
          ],
        ),
        content: Text(
          'This will revoke access to ALL secrets for agent "$agentId".\n\n'
          'Are you sure you want to proceed?',
          style: TextStyle(color: textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _revokeAllAccess(agentId);
            },
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAllAccess(String agentId) async {
    try {
      final provider = Provider.of<VaultProvider>(context, listen: false);
      await provider.revokeAllAgentAccess(agentId);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Revoked all access for $agentId'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke all access: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'today';
      } else if (diff.inDays == 1) {
        return 'yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}

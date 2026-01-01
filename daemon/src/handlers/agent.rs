//! Handlers for AI agent access control
//!
//! Provides fine-grained access control for AI coding assistants
//! (Claude Code, Cursor, GitHub Copilot, etc.)
//!
//! ## Features:
//! - Register AI agents with unique identifiers
//! - Grant/revoke access to specific secrets per agent
//! - Audit trail for all agent access
//! - Emergency revoke-all for compromised agents

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

use crate::storage::Storage;

/// Information about a registered AI agent
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentInfo {
    pub id: String,
    pub name: String,
    pub agent_type: String,
    pub created_at: String,
    pub last_access: Option<String>,
    pub permission_count: i64,
}

/// Result of agent registration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentRegisterResult {
    pub agent_id: String,
    pub name: String,
    pub agent_type: String,
    pub status: String,
}

/// Result of agent permission operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentPermissionResult {
    pub agent_id: String,
    pub secret_name: String,
    pub status: String,
}

/// Result of revoke-all operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentRevokeAllResult {
    pub agent_id: String,
    pub revoked_count: i64,
    pub status: String,
}

/// Register a new AI agent
///
/// Creates a record for an AI coding assistant that can be granted
/// access to specific secrets.
pub fn handle_agent_register(
    storage: &Storage,
    name: &str,
    agent_type: &str,
) -> Result<AgentRegisterResult> {
    let id = uuid::Uuid::new_v4().to_string();

    storage.connection().execute(
        "INSERT INTO agents (id, name, agent_type) VALUES (?, ?, ?)",
        rusqlite::params![id, name, agent_type],
    ).context("Failed to register agent")?;

    storage.log_audit("system", &format!("agent:{}", name), "register", true, None)
        .context("Failed to log audit entry")?;

    tracing::info!("Registered AI agent: {} (type: {})", name, agent_type);

    Ok(AgentRegisterResult {
        agent_id: id,
        name: name.to_string(),
        agent_type: agent_type.to_string(),
        status: "registered".to_string(),
    })
}

/// List all registered AI agents
pub fn handle_agent_list(storage: &Storage) -> Result<Vec<AgentInfo>> {
    let mut stmt = storage.connection().prepare(
        r#"
        SELECT
            a.id,
            a.name,
            a.agent_type,
            a.created_at,
            a.last_access,
            COALESCE((SELECT COUNT(*) FROM agent_permissions WHERE agent_id = a.id), 0) as permission_count
        FROM agents a
        ORDER BY a.name
        "#
    )?;

    let agents = stmt.query_map([], |row| {
        Ok(AgentInfo {
            id: row.get(0)?,
            name: row.get(1)?,
            agent_type: row.get(2)?,
            created_at: row.get(3)?,
            last_access: row.get(4)?,
            permission_count: row.get(5)?,
        })
    })?
    .collect::<Result<Vec<_>, _>>()?;

    Ok(agents)
}

/// Grant an agent access to a secret
pub fn handle_agent_grant(
    storage: &Storage,
    agent_id: &str,
    secret_name: &str,
    environment: Option<&str>,
) -> Result<AgentPermissionResult> {
    let env = environment.unwrap_or("default");
    let perm_id = uuid::Uuid::new_v4().to_string();

    // Verify agent exists
    let agent_exists: bool = storage.connection().query_row(
        "SELECT EXISTS(SELECT 1 FROM agents WHERE id = ? OR name = ?)",
        rusqlite::params![agent_id, agent_id],
        |row| row.get(0),
    )?;

    if !agent_exists {
        anyhow::bail!("Agent not found: {}", agent_id);
    }

    // Get the actual agent ID if name was provided
    let actual_agent_id: String = storage.connection().query_row(
        "SELECT id FROM agents WHERE id = ? OR name = ?",
        rusqlite::params![agent_id, agent_id],
        |row| row.get(0),
    )?;

    // Verify secret exists
    let secret_exists: bool = storage.connection().query_row(
        "SELECT EXISTS(SELECT 1 FROM secrets WHERE name = ?)",
        rusqlite::params![secret_name],
        |row| row.get(0),
    )?;

    if !secret_exists {
        anyhow::bail!("Secret not found: {}", secret_name);
    }

    // Insert permission (or ignore if already exists)
    storage.connection().execute(
        "INSERT OR IGNORE INTO agent_permissions (id, agent_id, secret_name, environment) VALUES (?, ?, ?, ?)",
        rusqlite::params![perm_id, actual_agent_id, secret_name, env],
    ).context("Failed to grant agent permission")?;

    storage.log_audit(&format!("agent:{}", agent_id), secret_name, "grant", true, None)
        .context("Failed to log audit entry")?;

    tracing::info!("Granted agent {} access to secret {} (env: {})", agent_id, secret_name, env);

    Ok(AgentPermissionResult {
        agent_id: actual_agent_id,
        secret_name: secret_name.to_string(),
        status: "granted".to_string(),
    })
}

/// Revoke an agent's access to a secret
pub fn handle_agent_revoke(
    storage: &Storage,
    agent_id: &str,
    secret_name: &str,
) -> Result<AgentPermissionResult> {
    // Get the actual agent ID if name was provided
    let actual_agent_id: String = storage.connection().query_row(
        "SELECT id FROM agents WHERE id = ? OR name = ?",
        rusqlite::params![agent_id, agent_id],
        |row| row.get(0),
    ).context("Agent not found")?;

    let rows_affected = storage.connection().execute(
        "DELETE FROM agent_permissions WHERE agent_id = ? AND secret_name = ?",
        rusqlite::params![actual_agent_id, secret_name],
    ).context("Failed to revoke agent permission")?;

    if rows_affected == 0 {
        anyhow::bail!("No permission found for agent {} on secret {}", agent_id, secret_name);
    }

    storage.log_audit(&format!("agent:{}", agent_id), secret_name, "revoke", true, None)
        .context("Failed to log audit entry")?;

    tracing::info!("Revoked agent {} access to secret {}", agent_id, secret_name);

    Ok(AgentPermissionResult {
        agent_id: actual_agent_id,
        secret_name: secret_name.to_string(),
        status: "revoked".to_string(),
    })
}

/// Revoke ALL of an agent's permissions (emergency)
pub fn handle_agent_revoke_all(
    storage: &Storage,
    agent_id: &str,
) -> Result<AgentRevokeAllResult> {
    // Get the actual agent ID if name was provided
    let actual_agent_id: String = storage.connection().query_row(
        "SELECT id FROM agents WHERE id = ? OR name = ?",
        rusqlite::params![agent_id, agent_id],
        |row| row.get(0),
    ).context("Agent not found")?;

    // Count permissions before deletion
    let count: i64 = storage.connection().query_row(
        "SELECT COUNT(*) FROM agent_permissions WHERE agent_id = ?",
        rusqlite::params![actual_agent_id],
        |row| row.get(0),
    )?;

    // Delete all permissions
    storage.connection().execute(
        "DELETE FROM agent_permissions WHERE agent_id = ?",
        rusqlite::params![actual_agent_id],
    ).context("Failed to revoke all agent permissions")?;

    storage.log_audit(
        &format!("agent:{}", agent_id),
        "*",
        "revoke_all",
        true,
        Some(&format!("Revoked {} permissions", count)),
    ).context("Failed to log audit entry")?;

    tracing::warn!("SECURITY: Revoked ALL ({}) permissions for agent {}", count, agent_id);

    Ok(AgentRevokeAllResult {
        agent_id: actual_agent_id,
        revoked_count: count,
        status: "all_revoked".to_string(),
    })
}

/// Check if an agent has access to a specific secret
pub fn handle_agent_check_permission(
    storage: &Storage,
    agent_id: &str,
    secret_name: &str,
    environment: Option<&str>,
) -> Result<bool> {
    let env = environment.unwrap_or("default");

    let has_permission: bool = storage.connection().query_row(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM agent_permissions ap
            JOIN agents a ON ap.agent_id = a.id
            WHERE (a.id = ? OR a.name = ?)
            AND ap.secret_name = ?
            AND ap.environment = ?
        )
        "#,
        rusqlite::params![agent_id, agent_id, secret_name, env],
        |row| row.get(0),
    )?;

    Ok(has_permission)
}

/// List secrets an agent has access to
pub fn handle_agent_explain(
    storage: &Storage,
    agent_id: &str,
) -> Result<Vec<(String, String)>> {
    let actual_agent_id: String = storage.connection().query_row(
        "SELECT id FROM agents WHERE id = ? OR name = ?",
        rusqlite::params![agent_id, agent_id],
        |row| row.get(0),
    ).context("Agent not found")?;

    let mut stmt = storage.connection().prepare(
        "SELECT secret_name, environment FROM agent_permissions WHERE agent_id = ? ORDER BY secret_name"
    )?;

    let permissions = stmt.query_map(rusqlite::params![actual_agent_id], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
    })?
    .collect::<Result<Vec<_>, _>>()?;

    Ok(permissions)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn create_test_storage_with_agents_table() -> (Storage, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let db_path = temp_dir.path().join("test_vault.db");
        let storage = Storage::new_without_key(&db_path).expect("Failed to create storage");

        // Create agents and agent_permissions tables
        storage.connection().execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                agent_type TEXT NOT NULL DEFAULT 'ai-assistant',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_access TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS agent_permissions (
                id TEXT PRIMARY KEY,
                agent_id TEXT NOT NULL,
                secret_name TEXT NOT NULL,
                environment TEXT DEFAULT 'default',
                granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(agent_id, secret_name, environment),
                FOREIGN KEY (agent_id) REFERENCES agents(id)
            );
            "#
        ).expect("Failed to create tables");

        (storage, temp_dir)
    }

    #[test]
    fn test_agent_register() {
        let (storage, _temp_dir) = create_test_storage_with_agents_table();

        let result = handle_agent_register(&storage, "claude-code", "ai-assistant")
            .expect("Registration should succeed");

        assert_eq!(result.name, "claude-code");
        assert_eq!(result.agent_type, "ai-assistant");
        assert_eq!(result.status, "registered");
    }

    #[test]
    fn test_agent_list() {
        let (storage, _temp_dir) = create_test_storage_with_agents_table();

        handle_agent_register(&storage, "claude-code", "ai-assistant").unwrap();
        handle_agent_register(&storage, "cursor", "ai-assistant").unwrap();

        let agents = handle_agent_list(&storage).expect("List should succeed");

        assert_eq!(agents.len(), 2);
    }

    #[test]
    fn test_agent_grant_revoke() {
        let (storage, _temp_dir) = create_test_storage_with_agents_table();

        // Register agent
        let reg_result = handle_agent_register(&storage, "claude-code", "ai-assistant").unwrap();

        // Add a secret
        storage.connection().execute(
            "INSERT INTO secrets (id, name, value_encrypted) VALUES (?, ?, ?)",
            rusqlite::params!["secret-1", "OPENAI_KEY", vec![0u8; 32]],
        ).unwrap();

        // Grant access
        let grant_result = handle_agent_grant(&storage, &reg_result.agent_id, "OPENAI_KEY", None)
            .expect("Grant should succeed");
        assert_eq!(grant_result.status, "granted");

        // Check permission
        let has_perm = handle_agent_check_permission(&storage, &reg_result.agent_id, "OPENAI_KEY", None)
            .expect("Check should succeed");
        assert!(has_perm);

        // Revoke access
        let revoke_result = handle_agent_revoke(&storage, &reg_result.agent_id, "OPENAI_KEY")
            .expect("Revoke should succeed");
        assert_eq!(revoke_result.status, "revoked");

        // Check permission again
        let has_perm = handle_agent_check_permission(&storage, &reg_result.agent_id, "OPENAI_KEY", None)
            .expect("Check should succeed");
        assert!(!has_perm);
    }
}

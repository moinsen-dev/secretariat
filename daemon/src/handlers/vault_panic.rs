//! Handler for vault.panic - Security Kill-Switch
//!
//! Emergency revocation of ALL secrets for ALL apps, followed by vault lock.
//! This is the "panic button" for when a compromise is suspected.
//!
//! ## Features:
//! - Revokes ALL permissions immediately
//! - Locks the vault (clears master key from memory)
//! - Deletes master key from keychain (disables biometric unlock)
//! - Logs the emergency action to audit log
//!
//! ## Usage:
//! Call when:
//! - A key is suspected to be compromised
//! - Suspicious activity is detected
//! - Emergency lockdown is needed

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

use crate::storage::Storage;

/// Result of a vault panic operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultPanicResult {
    /// Number of permissions revoked
    pub permissions_revoked: i64,
    /// Number of apps affected
    pub apps_affected: i64,
    /// Whether biometric was disabled
    pub biometric_disabled: bool,
    /// Status message
    pub status: String,
}

/// Execute the vault panic operation
///
/// This function:
/// 1. Revokes ALL permissions in the database
/// 2. Logs the emergency action
/// 3. Returns statistics about what was affected
///
/// The caller (server.rs) is responsible for:
/// - Locking the vault (clearing master key from memory)
/// - Deleting master key from keychain
///
/// # Arguments
///
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// A `VaultPanicResult` containing statistics about the operation
pub fn handle_vault_panic(storage: &Storage) -> Result<VaultPanicResult> {
    // Get counts before deletion for reporting
    let permissions_count: i64 = storage
        .connection()
        .query_row("SELECT COUNT(*) FROM permissions", [], |row| row.get(0))
        .context("Failed to count permissions")?;

    let apps_count: i64 = storage
        .connection()
        .query_row(
            "SELECT COUNT(DISTINCT app_id) FROM permissions",
            [],
            |row| row.get(0),
        )
        .context("Failed to count affected apps")?;

    // Delete ALL permissions
    storage
        .connection()
        .execute("DELETE FROM permissions", [])
        .context("Failed to revoke all permissions")?;

    // Log the emergency action to audit log
    storage
        .connection()
        .execute(
            "INSERT INTO audit_log (app_id, secret_name, action, success, details) VALUES (?, ?, ?, ?, ?)",
            rusqlite::params![
                "SYSTEM",
                "*",
                "panic",
                true,
                format!(
                    "Emergency kill-switch activated. Revoked {} permissions for {} apps.",
                    permissions_count, apps_count
                )
            ],
        )
        .context("Failed to log panic action")?;

    tracing::warn!(
        "SECURITY: Vault panic executed. Revoked {} permissions for {} apps.",
        permissions_count,
        apps_count
    );

    Ok(VaultPanicResult {
        permissions_revoked: permissions_count,
        apps_affected: apps_count,
        biometric_disabled: false, // Will be set by caller after keychain deletion
        status: "panic_executed".to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn create_test_storage() -> (Storage, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let db_path = temp_dir.path().join("test_vault.db");
        let storage = Storage::new_without_key(&db_path).expect("Failed to create storage");
        (storage, temp_dir)
    }

    #[test]
    fn test_vault_panic_empty() {
        let (storage, _temp_dir) = create_test_storage();

        let result = handle_vault_panic(&storage).expect("Panic should succeed");

        assert_eq!(result.permissions_revoked, 0);
        assert_eq!(result.apps_affected, 0);
        assert_eq!(result.status, "panic_executed");
    }

    #[test]
    fn test_vault_panic_with_permissions() {
        let (storage, _temp_dir) = create_test_storage();

        // Add a secret
        storage
            .connection()
            .execute(
                "INSERT INTO secrets (id, name, value_encrypted) VALUES (?, ?, ?)",
                rusqlite::params!["secret-1", "TEST_KEY", vec![0u8; 32]],
            )
            .expect("Failed to insert secret");

        // Add an application
        storage
            .connection()
            .execute(
                "INSERT INTO applications (id, name, fingerprint) VALUES (?, ?, ?)",
                rusqlite::params!["app-1", "TestApp", "fingerprint-1"],
            )
            .expect("Failed to insert app");

        // Add a permission
        storage
            .connection()
            .execute(
                "INSERT INTO permissions (id, app_id, secret_id) VALUES (?, ?, ?)",
                rusqlite::params!["perm-1", "app-1", "secret-1"],
            )
            .expect("Failed to insert permission");

        // Execute panic
        let result = handle_vault_panic(&storage).expect("Panic should succeed");

        assert_eq!(result.permissions_revoked, 1);
        assert_eq!(result.apps_affected, 1);

        // Verify permissions are deleted
        let count: i64 = storage
            .connection()
            .query_row("SELECT COUNT(*) FROM permissions", [], |row| row.get(0))
            .expect("Failed to count");
        assert_eq!(count, 0);
    }
}

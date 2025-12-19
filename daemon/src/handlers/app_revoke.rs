//! Handler for app.revoke method
//!
//! Revokes an application's permission to access a specific secret.

use anyhow::{Result, Context};
use crate::storage::Storage;

/// Handle app.revoke method
///
/// Revokes an application's permission to access a specific secret by removing
/// the record from the permissions table.
///
/// # Arguments
///
/// * `app_id` - The fingerprint of the application
/// * `secret_name` - The name of the secret to revoke access to
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// Returns `Ok(())` on success
///
/// # Errors
///
/// Returns an error if:
/// - The permission does not exist
/// - Database deletion fails
pub fn handle_app_revoke(app_id: &str, secret_name: &str, storage: &Storage) -> Result<()> {
    // Revoke the permission
    storage.revoke_permission(app_id, secret_name)
        .context(format!("Failed to revoke permission for app '{}' to access secret '{}'", app_id, secret_name))?;

    // Log the revocation in audit log
    storage.log_audit(app_id, secret_name, "revoke", true, Some("Permission revoked by user"))
        .context("Failed to log revocation in audit log")?;

    tracing::info!("Revoked app '{}' access to secret '{}'", app_id, secret_name);

    Ok(())
}

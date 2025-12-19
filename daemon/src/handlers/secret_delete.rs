//! Handler for secret.delete method
//!
//! Deletes a secret from the database, cascading to permissions.
//!
//! ## Wave 14 Features:
//! - F068: Create handlers/secret_delete.rs file
//! - F069: Implement handle_secret_delete(name: &str, storage: &Storage) -> Result<()>
//! - F070: Cascade delete permissions when secret is deleted

use anyhow::{Result, Context};

use crate::storage::Storage;

/// Handle secret.delete method
///
/// Deletes a secret by name, including all associated permissions.
/// This implements cascade delete to maintain referential integrity.
///
/// # Arguments
///
/// * `name` - The name of the secret to delete (e.g., "OPENAI_API_KEY")
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// Returns `Ok(())` on success
///
/// # Errors
///
/// Returns an error if:
/// - The secret does not exist
/// - Database deletion fails
/// - Audit logging fails
///
/// # Features
///
/// - F068: Handler file created
/// - F069: Implements handle_secret_delete function
/// - F070: Cascade deletes permissions when secret is deleted
///
/// # Security
///
/// This function ensures:
/// 1. The secret is completely removed from the database
/// 2. All permissions referencing this secret are also deleted
/// 3. The deletion is logged to the audit trail
///
/// # Examples
///
/// ```no_run
/// use secd::handlers::handle_secret_delete;
/// use secd::storage::Storage;
///
/// let storage = Storage::new("vault.db", "encryption_key").unwrap();
///
/// handle_secret_delete("OPENAI_API_KEY", &storage)
///     .expect("Failed to delete secret");
/// ```
pub fn handle_secret_delete(name: &str, storage: &Storage) -> Result<()> {
    // F069: Delete the secret (F070: cascades to permissions)
    storage.delete_secret(name)
        .context("Failed to delete secret")?;

    // Log the deletion
    storage.log_audit("system", name, "delete", true, None)
        .context("Failed to log audit entry")?;

    Ok(())
}

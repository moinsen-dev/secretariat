//! Handler for app.authorize method
//!
//! Grants an application permission to access a specific secret.
//!
//! ## Wave 15 Features:
//! - F077: Create handlers/app_authorize.rs file
//! - F078: Validate app_id exists in applications table
//! - F079: Validate secret_name exists in secrets table
//! - F080: Insert permission record with granted_at timestamp

use anyhow::{Result, Context};
use crate::storage::Storage;

/// Handle app.authorize method
///
/// Grants an application permission to access a specific secret by creating
/// a record in the permissions table.
///
/// # Arguments
///
/// * `app_id` - The fingerprint of the application to authorize
/// * `secret_name` - The name of the secret to grant access to
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// Returns `Ok(())` on success
///
/// # Errors
///
/// Returns an error if:
/// - F078: The app_id does not exist in the applications table
/// - F079: The secret_name does not exist in the secrets table
/// - Database insert fails
///
/// # Features
///
/// - F077: Handler implementation for app.authorize
/// - F078: Validates app_id exists (delegated to storage.grant_permission)
/// - F079: Validates secret_name exists (delegated to storage.grant_permission)
/// - F080: Creates permission record with granted_at timestamp (delegated to storage.grant_permission)
///
/// # Security
///
/// This operation should only be called after user confirmation.
/// The handler delegates to storage.grant_permission which:
/// 1. Validates that both app and secret exist
/// 2. Creates or updates the permission record
/// 3. Sets granted_at timestamp automatically
///
/// # Examples
///
/// ```no_run
/// use secd::handlers::handle_app_authorize;
/// use secd::storage::Storage;
///
/// let storage = Storage::new("vault.db", "encryption_key").unwrap();
/// let app_id = "abc123..."; // Application fingerprint
/// let secret_name = "OPENAI_API_KEY";
///
/// handle_app_authorize(app_id, secret_name, &storage)
///     .expect("Failed to authorize app");
/// ```
pub fn handle_app_authorize(app_id: &str, secret_name: &str, storage: &Storage) -> Result<()> {
    // F078, F079, F080: Delegate to storage layer which validates and creates permission
    storage.grant_permission(app_id, secret_name, "user")
        .context(format!("Failed to grant permission for app '{}' to access secret '{}'", app_id, secret_name))?;

    // F083: Log the authorization in audit log
    storage.log_audit(app_id, secret_name, "grant", true, Some("Permission granted by user"))
        .context("Failed to log authorization in audit log")?;

    tracing::info!("Authorized app '{}' to access secret '{}'", app_id, secret_name);

    Ok(())
}

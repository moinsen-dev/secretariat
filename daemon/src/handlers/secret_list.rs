//! Handler for secret.list method
//!
//! Lists all secrets in the database, returning metadata only (no encrypted values).
//!
//! ## Wave 11 Features:
//! - F052: Create handlers/secret_list.rs file
//! - F053: Implement handle_secret_list(db: &Storage) -> Result<Vec<SecretMetadata>>
//! - F054: Query secrets table for id, name, provider, created_at columns only
//! - F055: Return JSON array of secret metadata (no encrypted values)

use anyhow::Result;

use crate::storage::{Storage, SecretMetadata};

/// Handle secret.list method
///
/// Returns a list of all secrets in the database with metadata only.
/// Does NOT include encrypted values for security.
///
/// # Arguments
///
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// A vector of `SecretMetadata` containing id, name, provider, environment, and created_at
///
/// # Errors
///
/// Returns an error if:
/// - Database query fails
/// - Data cannot be parsed from the database
///
/// # Features
///
/// - F053: Implements handle_secret_list function
/// - F054: Queries only id, name, provider, environment, created_at (not value_encrypted)
/// - F055: Returns JSON-serializable metadata array
pub fn handle_secret_list(storage: &Storage) -> Result<Vec<SecretMetadata>> {
    storage.list_secrets()
}

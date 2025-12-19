//! Handler for vault.unlock method
//!
//! Unlocks the vault by deriving the master key from password.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::{Context, Result};
use crate::storage::Storage;
use crate::crypto;

/// Result of vault unlock operation
pub struct VaultUnlockResult {
    pub status: String,
    pub master_key: [u8; 32],
}

/// Handle vault.unlock method
///
/// Unlocks the vault by:
/// 1. Retrieving the stored salt from vault_metadata
/// 2. Deriving the master key from the password and salt
/// 3. Returning the key to be stored in server state
///
/// # Arguments
///
/// * `password` - The master password
/// * `storage` - Reference to storage layer
///
/// # Returns
///
/// Returns `Ok(VaultUnlockResult)` with the derived master key
///
/// # Errors
///
/// Returns error if:
/// - Vault is not initialized (no salt stored)
/// - Key derivation fails
pub fn handle_vault_unlock(password: &str, storage: &Storage) -> Result<VaultUnlockResult> {
    // Get the stored salt (it's already a base64 salt string, not hex)
    let salt = storage
        .get_vault_metadata("salt")?
        .context("Vault not initialized. Run 'sec init' first.")?;

    // Derive the master key from password
    // Note: salt is already a base64-encoded SaltString
    let master_key = crypto::derive_key_from_password(password.as_bytes(), &salt)
        .context("Failed to derive key from password")?;

    tracing::info!("Vault unlocked successfully");

    Ok(VaultUnlockResult {
        status: "unlocked".to_string(),
        master_key,
    })
}

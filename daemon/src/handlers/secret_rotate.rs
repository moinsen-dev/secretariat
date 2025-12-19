//! Handler for secret.rotate method
//!
//! Rotates a secret's value while preserving the previous version.
//!
//! Milestone 4: Secret Rotation

use anyhow::{Context, Result};
use crate::storage::Storage;
use crate::crypto;

/// Result of secret rotation
pub struct SecretRotateResult {
    pub name: String,
    pub version: i64,
    pub status: String,
}

/// Handle secret.rotate method
///
/// Rotates a secret by:
/// 1. Getting the current secret
/// 2. Storing the current value as previous_value
/// 3. Encrypting and storing the new value
/// 4. Incrementing the version number
/// 5. Logging the rotation in audit log
///
/// # Arguments
///
/// * `name` - The secret name
/// * `new_value` - The new secret value
/// * `storage` - Reference to storage layer
/// * `master_key` - The master encryption key
///
/// # Returns
///
/// Returns `Ok(SecretRotateResult)` with new version number
///
/// # Errors
///
/// Returns error if:
/// - Secret doesn't exist
/// - Encryption fails
/// - Database update fails
pub fn handle_secret_rotate(
    name: &str,
    new_value: &str,
    storage: &Storage,
    master_key: &[u8; 32],
) -> Result<SecretRotateResult> {
    // Check if secret exists and get current version
    let current = storage
        .get_secret_metadata(name)?
        .context(format!("Secret '{}' not found", name))?;

    // Get current version (default to 1 if not set)
    let current_version = current.version.unwrap_or(1);
    let new_version = current_version + 1;

    // Encrypt the new value
    let encrypted = crypto::encrypt(new_value, master_key)
        .context("Failed to encrypt new secret value")?;

    // Convert EncryptedValue to bytes (nonce + ciphertext)
    let mut encrypted_bytes = Vec::with_capacity(encrypted.nonce.len() + encrypted.ciphertext.len());
    encrypted_bytes.extend_from_slice(&encrypted.nonce);
    encrypted_bytes.extend_from_slice(&encrypted.ciphertext);

    // Rotate the secret (stores previous value, updates to new)
    storage.rotate_secret(name, &encrypted_bytes, new_version)
        .context("Failed to rotate secret in storage")?;

    // Log the rotation
    storage.log_audit("system", name, "rotate", true, Some(&format!("Rotated to version {}", new_version)))
        .context("Failed to log rotation")?;

    tracing::info!("Rotated secret '{}' to version {}", name, new_version);

    Ok(SecretRotateResult {
        name: name.to_string(),
        version: new_version,
        status: "rotated".to_string(),
    })
}

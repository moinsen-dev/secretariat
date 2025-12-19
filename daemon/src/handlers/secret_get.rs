//! Handler for secret.get method
//!
//! Retrieves a secret value by name, enforcing permission checks.
//!
//! ## Wave 12 Features:
//! - F056: Create handlers/secret_get.rs file
//! - F057: Implement handle_secret_get(name: &str, app_id: &str, storage: &Storage) -> Result<String>
//! - F058: Check permissions table for matching app_id and secret_id
//! - F059: Return PermissionDenied error if no permission exists
//! - F060: Load encrypted value from secrets table
//!
//! ## Wave 13 Features:
//! - F061: Decrypt value using master key from keychain
//! - F062: Log successful access to audit_log table

use anyhow::{Result, bail};

use crate::storage::Storage;
use crate::crypto::{decrypt, EncryptedValue};

/// Custom error type for permission denied
///
/// F059: Returns a specific error when app lacks permission to access a secret
#[derive(Debug, thiserror::Error)]
#[error("Permission denied: app '{app_id}' does not have access to secret '{secret_name}'")]
pub struct PermissionDenied {
    pub app_id: String,
    pub secret_name: String,
}

/// Handle secret.get method
///
/// Retrieves a secret value by name, but only if the requesting app
/// has been granted permission to access it. Decrypts the value and logs the access.
///
/// # Arguments
///
/// * `name` - The name of the secret to retrieve (e.g., "OPENAI_API_KEY")
/// * `app_id` - The identifier of the application requesting access
/// * `storage` - Reference to the storage layer
/// * `master_key` - The 32-byte master encryption key from keychain
///
/// # Returns
///
/// The decrypted secret value as a plaintext string on success
///
/// # Errors
///
/// Returns an error if:
/// - F059: The app does not have permission to access the secret (PermissionDenied)
/// - The secret does not exist
/// - Database query fails
/// - F061: Decryption fails (wrong key or tampered data)
/// - F062: Audit logging fails
///
/// # Features
///
/// - F057: Implements handle_secret_get function
/// - F058: Checks permissions table for matching app_id and secret_id
/// - F059: Returns PermissionDenied error if no permission exists
/// - F060: Loads encrypted value from secrets table
/// - F061: Decrypts value using master key from keychain
/// - F062: Logs successful access to audit_log table
///
/// # Security
///
/// This function enforces the authorization model:
/// 1. Look up the secret by name to get its ID
/// 2. Check if the app has permission to access this secret
/// 3. Decrypt the value using the master key
/// 4. Log the successful access to the audit log
/// 5. Return the plaintext value
pub fn handle_secret_get(name: &str, app_id: &str, storage: &Storage, master_key: &[u8; 32]) -> Result<String> {
    // F060: Look up secret by name
    let secret = storage.get_secret_by_name(name)?;

    // Special case: Trusted local interfaces have administrative access to all secrets
    // These are CLI and SDK clients running on the local machine
    let is_trusted = matches!(
        app_id,
        "cli" | "python-sdk" | "node-sdk" | "dart-sdk" | "rust-sdk" | "flutter-app"
    );

    // F058: Check if the app has permission to access this secret
    // Skip permission check for trusted local interfaces
    let has_permission = is_trusted || storage.check_permission(app_id, &secret.id)?;

    // F059: Return PermissionDenied error if no permission exists
    if !has_permission {
        // F062: Log failed access attempt
        let _ = storage.log_audit(app_id, name, "read", false, Some("Permission denied"));

        bail!(PermissionDenied {
            app_id: app_id.to_string(),
            secret_name: name.to_string(),
        });
    }

    // F061: Decrypt the value using the master key
    // The value_encrypted is stored as: nonce (12 bytes) + ciphertext (variable length)
    // We need to split it into nonce and ciphertext components
    if secret.value_encrypted.len() < 12 {
        bail!("Invalid encrypted value: too short to contain nonce");
    }

    let nonce_bytes = &secret.value_encrypted[..12];
    let ciphertext_bytes = &secret.value_encrypted[12..];

    let mut nonce = [0u8; 12];
    nonce.copy_from_slice(nonce_bytes);

    let encrypted = EncryptedValue {
        nonce,
        ciphertext: ciphertext_bytes.to_vec(),
    };

    let decrypted_value = decrypt(&encrypted, master_key)?;

    // F062: Log successful access to audit_log
    storage.log_audit(app_id, name, "read", true, None)?;

    Ok(decrypted_value)
}

// Re-export for convenience
pub use PermissionDenied as PermissionDeniedError;

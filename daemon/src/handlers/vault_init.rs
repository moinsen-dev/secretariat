//! Handler for vault.init method
//!
//! Initializes or re-initializes the vault with a new master password.
//!
//! ## Features:
//! - Derives master key from user password using Argon2
//! - Stores salt in vault_metadata table
//! - Stores master key in system keychain
//! - Re-encrypts existing secrets if migrating

use anyhow::{Context, Result};

use crate::crypto::{decrypt, encrypt, derive_key_from_password, generate_salt, EncryptedValue};
use crate::keychain;
use crate::storage::Storage;

/// Result of vault initialization
#[derive(Debug)]
pub struct VaultInitResult {
    /// Path to the vault database
    pub vault_path: String,
    /// Number of secrets that were re-encrypted (0 for fresh init)
    pub secrets_migrated: usize,
}

/// Handle vault.init method
///
/// Initializes the vault with a new master password. If secrets already exist
/// and a previous master key is available, they will be re-encrypted with the
/// new key.
///
/// # Arguments
///
/// * `password` - The user's master password (min 8 characters)
/// * `storage` - Reference to the storage layer
/// * `old_master_key` - Optional previous master key for re-encryption
///
/// # Returns
///
/// A `VaultInitResult` containing the vault path and number of migrated secrets
///
/// # Errors
///
/// Returns an error if:
/// - Password is too short
/// - Key derivation fails
/// - Keychain storage fails
/// - Re-encryption of existing secrets fails
///
/// # Security
///
/// This function:
/// 1. Generates a cryptographically secure random salt
/// 2. Derives a 256-bit key using Argon2id (memory-hard)
/// 3. Re-encrypts all existing secrets with the new key
/// 4. Stores the derived key in the system keychain
/// 5. Stores only the salt in the database (not the key)
pub fn handle_vault_init(
    password: &str,
    storage: &Storage,
    old_master_key: Option<&[u8; 32]>,
) -> Result<VaultInitResult> {
    // Validate password length (additional check, CLI also validates)
    if password.len() < 8 {
        anyhow::bail!("Password must be at least 8 characters long");
    }

    // 1. Generate a new random salt
    let salt = generate_salt();

    // 2. Derive new master key from password using Argon2id
    let new_master_key = derive_key_from_password(password.as_bytes(), &salt)
        .context("Failed to derive key from password")?;

    // 3. If secrets exist and we have the old key, re-encrypt them
    let secrets_migrated = if let Some(old_key) = old_master_key {
        re_encrypt_secrets(storage, old_key, &new_master_key)?
    } else {
        0
    };

    // 4. Store/update salt in vault_metadata
    storage.set_vault_metadata("salt", &salt)
        .context("Failed to store salt in vault metadata")?;

    // 4b. Store password verification value (encrypted known string)
    // This allows us to verify the password is correct during unlock
    let verification_plaintext = "SECRETARIAT_VAULT_VERIFICATION_V1";
    let verification_encrypted = encrypt(verification_plaintext, &new_master_key)
        .context("Failed to create verification value")?;

    // Store as base64-encoded nonce+ciphertext
    let mut verification_bytes = Vec::with_capacity(
        verification_encrypted.nonce.len() + verification_encrypted.ciphertext.len()
    );
    verification_bytes.extend_from_slice(&verification_encrypted.nonce);
    verification_bytes.extend_from_slice(&verification_encrypted.ciphertext);

    use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
    let verification_b64 = BASE64.encode(&verification_bytes);
    storage.set_vault_metadata("password_verification", &verification_b64)
        .context("Failed to store password verification")?;

    // 4c. Reset failed attempt counter on successful init
    storage.set_vault_metadata("failed_attempts", "0")
        .context("Failed to reset failed attempts")?;
    storage.set_vault_metadata("lockout_until", "")
        .context("Failed to clear lockout")?;

    // 5. Store new master key in keychain (replaces old if exists)
    keychain::store_master_key(&new_master_key)
        .context("Failed to store master key in keychain")?;

    // 6. Log the initialization
    storage.log_audit("system", "vault", "init", true, None)
        .context("Failed to log vault initialization")?;

    Ok(VaultInitResult {
        vault_path: storage.path().to_string_lossy().to_string(),
        secrets_migrated,
    })
}

/// Re-encrypt all secrets with a new master key
///
/// # Arguments
///
/// * `storage` - Reference to the storage layer
/// * `old_key` - The previous master key for decryption
/// * `new_key` - The new master key for encryption
///
/// # Returns
///
/// The number of secrets that were re-encrypted
fn re_encrypt_secrets(
    storage: &Storage,
    old_key: &[u8; 32],
    new_key: &[u8; 32],
) -> Result<usize> {
    let secrets = storage.list_secrets_raw()
        .context("Failed to list secrets for re-encryption")?;

    let count = secrets.len();

    for secret in secrets {
        // Decrypt with old key
        if secret.value_encrypted.len() < 12 {
            anyhow::bail!("Invalid encrypted value for secret '{}': too short", secret.name);
        }

        let nonce_bytes = &secret.value_encrypted[..12];
        let ciphertext_bytes = &secret.value_encrypted[12..];

        let mut nonce = [0u8; 12];
        nonce.copy_from_slice(nonce_bytes);

        let encrypted = EncryptedValue {
            nonce,
            ciphertext: ciphertext_bytes.to_vec(),
        };

        let plaintext = decrypt(&encrypted, old_key)
            .with_context(|| format!("Failed to decrypt secret '{}' with old key", secret.name))?;

        // Re-encrypt with new key
        let new_encrypted = encrypt(&plaintext, new_key)
            .with_context(|| format!("Failed to re-encrypt secret '{}'", secret.name))?;

        // Combine nonce and ciphertext for storage
        let mut new_value = Vec::with_capacity(new_encrypted.nonce.len() + new_encrypted.ciphertext.len());
        new_value.extend_from_slice(&new_encrypted.nonce);
        new_value.extend_from_slice(&new_encrypted.ciphertext);

        // Update in storage
        storage.update_secret_encrypted(&secret.id, &new_value)
            .with_context(|| format!("Failed to update secret '{}' with new encryption", secret.name))?;
    }

    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    /// Create a test storage instance
    fn create_test_storage() -> (Storage, tempfile::TempDir) {
        let dir = tempdir().expect("Failed to create temp dir");
        let db_path = dir.path().join("test_vault.db");
        let storage = Storage::new(&db_path, "test_key").expect("Failed to create storage");
        (storage, dir)
    }

    #[test]
    fn test_vault_init_fresh() {
        let (storage, _dir) = create_test_storage();

        // Initialize vault with a fresh password
        let result = handle_vault_init("test_password_123", &storage, None);

        // Note: This test will fail if keychain access is not available
        // In CI environments, we may need to skip this test
        let result = match result {
            Ok(r) => r,
            Err(err) => {
                // Check if it's a keychain error (expected in CI)
                if err.to_string().contains("keychain") || err.to_string().contains("Keychain") {
                    eprintln!("Skipping test: keychain not available");
                    return;
                }
                // Fail the test with a proper assertion
                panic!("Unexpected error during vault init: {}", err);
            }
        };
        assert_eq!(result.secrets_migrated, 0);
        assert!(result.vault_path.contains("test_vault.db"));

        // Verify salt was stored
        assert!(storage.is_vault_initialized().unwrap());
    }

    #[test]
    fn test_password_too_short() {
        let (storage, _dir) = create_test_storage();

        let result = handle_vault_init("short", &storage, None);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("8 characters"));
    }
}

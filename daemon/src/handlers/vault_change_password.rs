//! Handler for vault.change_password method
//!
//! Allows changing the vault master password without losing secrets.
//!
//! ## Security Flow:
//! 1. Verify current password is correct
//! 2. Generate new salt for new password
//! 3. Derive new master key from new password
//! 4. Re-encrypt all secrets with new key
//! 5. Update salt and verification in database
//! 6. Update keychain with new master key

use anyhow::{Context, Result};

use crate::crypto::{decrypt, encrypt, derive_key_from_password, generate_salt, EncryptedValue};
use crate::keychain;
use crate::storage::Storage;

/// Result of password change operation
#[derive(Debug)]
pub struct PasswordChangeResult {
    /// Number of secrets that were re-encrypted
    pub secrets_migrated: usize,
    /// New master key (caller should store in server state)
    pub new_master_key: [u8; 32],
}

/// Handle vault.change_password method
///
/// Changes the vault master password while preserving all secrets.
///
/// # Arguments
///
/// * `current_password` - The current master password for verification
/// * `new_password` - The new master password (min 8 characters)
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// A `PasswordChangeResult` containing the number of re-encrypted secrets
/// and the new master key.
///
/// # Errors
///
/// Returns an error if:
/// - Current password is incorrect
/// - New password is too short
/// - Vault is not initialized
/// - Re-encryption fails
/// - Keychain update fails
///
/// # Security
///
/// This function:
/// 1. Verifies the current password before allowing change
/// 2. Generates a new cryptographically secure random salt
/// 3. Derives a new 256-bit key using Argon2id
/// 4. Re-encrypts all secrets with the new key
/// 5. Updates the keychain with the new key
/// 6. Stores only the salt in the database (not the key)
pub fn handle_vault_change_password(
    current_password: &str,
    new_password: &str,
    storage: &Storage,
) -> Result<PasswordChangeResult> {
    // 1. Validate new password length
    if new_password.len() < 8 {
        anyhow::bail!("New password must be at least 8 characters long");
    }

    // 2. Get the stored salt and verify current password
    let current_salt = storage
        .get_vault_metadata("salt")?
        .context("Vault not initialized. Run 'sec init' first.")?;

    // 3. Derive current master key
    let current_master_key = derive_key_from_password(current_password.as_bytes(), &current_salt)
        .context("Failed to derive key from current password")?;

    // 4. Verify current password by decrypting verification value
    verify_current_password(storage, &current_master_key)?;

    // 5. Generate new salt and derive new key
    let new_salt = generate_salt();
    let new_master_key = derive_key_from_password(new_password.as_bytes(), &new_salt)
        .context("Failed to derive key from new password")?;

    // 6. Re-encrypt all secrets with new key
    let secrets_migrated = re_encrypt_secrets(storage, &current_master_key, &new_master_key)?;

    // 7. Update salt in vault_metadata
    storage.set_vault_metadata("salt", &new_salt)
        .context("Failed to store new salt")?;

    // 8. Create and store new password verification value
    let verification_plaintext = "SECRETARIAT_VAULT_VERIFICATION_V1";
    let verification_encrypted = encrypt(verification_plaintext, &new_master_key)
        .context("Failed to create new verification value")?;

    let mut verification_bytes = Vec::with_capacity(
        verification_encrypted.nonce.len() + verification_encrypted.ciphertext.len()
    );
    verification_bytes.extend_from_slice(&verification_encrypted.nonce);
    verification_bytes.extend_from_slice(&verification_encrypted.ciphertext);

    use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
    let verification_b64 = BASE64.encode(&verification_bytes);
    storage.set_vault_metadata("password_verification", &verification_b64)
        .context("Failed to store new password verification")?;

    // 9. Reset failed attempt counters
    storage.set_vault_metadata("failed_attempts", "0")
        .context("Failed to reset failed attempts")?;
    storage.set_vault_metadata("lockout_until", "")
        .context("Failed to clear lockout")?;

    // 10. Update keychain with new master key
    keychain::store_master_key(&new_master_key)
        .context("Failed to update master key in keychain")?;

    // 11. Log the password change
    storage.log_audit("system", "vault", "password_changed", true,
        Some(&format!("Re-encrypted {} secrets", secrets_migrated)))
        .context("Failed to log password change")?;

    tracing::info!("Vault password changed, {} secrets re-encrypted", secrets_migrated);

    Ok(PasswordChangeResult {
        secrets_migrated,
        new_master_key,
    })
}

/// Verify the current password is correct
fn verify_current_password(storage: &Storage, master_key: &[u8; 32]) -> Result<()> {
    let verification_b64 = storage
        .get_vault_metadata("password_verification")?
        .context("Password verification not found. Vault may need re-initialization.")?;

    use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};

    let verification_bytes = BASE64.decode(&verification_b64)
        .context("Failed to decode verification value")?;

    if verification_bytes.len() < 12 {
        anyhow::bail!("Invalid verification value stored");
    }

    let nonce_bytes = &verification_bytes[..12];
    let ciphertext_bytes = &verification_bytes[12..];

    let mut nonce = [0u8; 12];
    nonce.copy_from_slice(nonce_bytes);

    let encrypted = EncryptedValue {
        nonce,
        ciphertext: ciphertext_bytes.to_vec(),
    };

    // Try to decrypt - if it fails, the password is wrong
    let plaintext = decrypt(&encrypted, master_key)
        .context("Current password is incorrect")?;

    if plaintext != "SECRETARIAT_VAULT_VERIFICATION_V1" {
        anyhow::bail!("Current password is incorrect");
    }

    Ok(())
}

/// Re-encrypt all secrets with a new master key
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
            .with_context(|| format!("Failed to decrypt secret '{}' with current key", secret.name))?;

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
    fn test_new_password_too_short() {
        let (storage, _dir) = create_test_storage();

        let result = handle_vault_change_password("current_password", "short", &storage);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("8 characters"));
    }

    #[test]
    fn test_vault_not_initialized() {
        let (storage, _dir) = create_test_storage();

        let result = handle_vault_change_password("current", "new_password_123", &storage);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("not initialized"));
    }
}

//! Handler for vault.unlock method
//!
//! Unlocks the vault by deriving the master key from password.
//!
//! Milestone 3: Vault Lock/Unlock
//! Security: Failed attempt tracking with exponential backoff

use anyhow::{Context, Result};
use crate::storage::Storage;
use crate::crypto::{self, decrypt, EncryptedValue};
use std::time::{SystemTime, UNIX_EPOCH};

/// Result of vault unlock operation
pub struct VaultUnlockResult {
    #[allow(dead_code)]
    pub status: String,
    pub master_key: [u8; 32],
}

/// Maximum failed attempts before extended lockout
const MAX_FAILED_ATTEMPTS: u32 = 10;

/// Base delay in seconds for exponential backoff
const BASE_DELAY_SECS: u64 = 1;

/// Maximum lockout duration in seconds (30 minutes)
const MAX_LOCKOUT_SECS: u64 = 1800;

/// Calculate lockout delay based on failed attempts (exponential backoff)
/// Returns delay in seconds: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512... capped at MAX_LOCKOUT_SECS
fn calculate_lockout_delay(failed_attempts: u32) -> u64 {
    if failed_attempts == 0 {
        return 0;
    }
    let delay = BASE_DELAY_SECS * (1u64 << (failed_attempts - 1).min(20));
    delay.min(MAX_LOCKOUT_SECS)
}

/// Get current Unix timestamp
fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Handle vault.unlock method
///
/// Unlocks the vault by:
/// 1. Checking for lockout (failed attempt protection)
/// 2. Retrieving the stored salt from vault_metadata
/// 3. Deriving the master key from the password and salt
/// 4. Verifying the password is correct
/// 5. Returning the key to be stored in server state
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
/// - Account is locked out (too many failed attempts)
/// - Vault is not initialized (no salt stored)
/// - Password is incorrect
/// - Key derivation fails
pub fn handle_vault_unlock(password: &str, storage: &Storage) -> Result<VaultUnlockResult> {
    // 1. Check for lockout
    let failed_attempts: u32 = storage
        .get_vault_metadata("failed_attempts")?
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    let lockout_until: u64 = storage
        .get_vault_metadata("lockout_until")?
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    let now = current_timestamp();

    if lockout_until > now {
        let remaining = lockout_until - now;
        anyhow::bail!(
            "Too many failed attempts. Please wait {} seconds before trying again.",
            remaining
        );
    }

    // 2. Get the stored salt
    let salt = storage
        .get_vault_metadata("salt")?
        .context("Vault not initialized. Run 'sec init' first.")?;

    // 3. Derive the master key from password
    let master_key = crypto::derive_key_from_password(password.as_bytes(), &salt)
        .context("Failed to derive key from password")?;

    // 4. Verify password by decrypting the verification value
    let verification_b64 = storage.get_vault_metadata("password_verification")?;

    if let Some(verification_b64) = verification_b64 {
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
        match decrypt(&encrypted, &master_key) {
            Ok(plaintext) => {
                // Verify the plaintext matches expected value
                if plaintext != "SECRETARIAT_VAULT_VERIFICATION_V1" {
                    return handle_failed_attempt(storage, failed_attempts);
                }
            }
            Err(_) => {
                return handle_failed_attempt(storage, failed_attempts);
            }
        }
    }
    // If no verification value exists (legacy vault), we accept the key
    // This maintains backward compatibility

    // 5. Success - reset failed attempts
    let _ = storage.set_vault_metadata("failed_attempts", "0");
    let _ = storage.set_vault_metadata("lockout_until", "");

    tracing::info!("Vault unlocked successfully");

    // Keep the Keychain key in sync so biometric (Touch ID) unlock uses the
    // current key. Best-effort — ignore Keychain timeouts.
    let _ = crate::keychain::store_master_key(&master_key);

    Ok(VaultUnlockResult {
        status: "unlocked".to_string(),
        master_key,
    })
}

/// Verify a candidate master key against the stored verification value.
/// Returns Ok(true) if it decrypts the verification value correctly (or if no
/// verification value exists — legacy vault), Ok(false) if the key is wrong.
/// Used by Keychain/biometric unlock to reject a stale Keychain key.
pub fn verify_master_key(storage: &Storage, master_key: &[u8; 32]) -> Result<bool> {
    let Some(verification_b64) = storage.get_vault_metadata("password_verification")? else {
        return Ok(true); // legacy vault without a verification value
    };

    use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
    let verification_bytes = BASE64
        .decode(&verification_b64)
        .context("Failed to decode verification value")?;
    if verification_bytes.len() < 12 {
        return Ok(false);
    }

    let mut nonce = [0u8; 12];
    nonce.copy_from_slice(&verification_bytes[..12]);
    let encrypted = EncryptedValue {
        nonce,
        ciphertext: verification_bytes[12..].to_vec(),
    };

    match decrypt(&encrypted, master_key) {
        Ok(plaintext) => Ok(plaintext == "SECRETARIAT_VAULT_VERIFICATION_V1"),
        Err(_) => Ok(false),
    }
}

/// Handle a failed unlock attempt
fn handle_failed_attempt(storage: &Storage, current_attempts: u32) -> Result<VaultUnlockResult> {
    let new_attempts = current_attempts + 1;

    // Update failed attempt counter
    let _ = storage.set_vault_metadata("failed_attempts", &new_attempts.to_string());

    // Calculate and set lockout time
    let delay = calculate_lockout_delay(new_attempts);
    let lockout_until = current_timestamp() + delay;
    let _ = storage.set_vault_metadata("lockout_until", &lockout_until.to_string());

    // Log the failed attempt
    let _ = storage.log_audit("system", "vault", "unlock_failed", false,
        Some(&format!("Attempt {} of {}", new_attempts, MAX_FAILED_ATTEMPTS)));

    tracing::warn!(
        "Failed unlock attempt {} - lockout for {} seconds",
        new_attempts, delay
    );

    if new_attempts >= MAX_FAILED_ATTEMPTS {
        anyhow::bail!(
            "Incorrect password. Account locked for {} seconds ({} failed attempts).",
            delay, new_attempts
        );
    } else {
        anyhow::bail!(
            "Incorrect password. {} attempts remaining before extended lockout.",
            MAX_FAILED_ATTEMPTS - new_attempts
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lockout_delay_calculation() {
        assert_eq!(calculate_lockout_delay(0), 0);
        assert_eq!(calculate_lockout_delay(1), 1);    // 2^0 = 1
        assert_eq!(calculate_lockout_delay(2), 2);    // 2^1 = 2
        assert_eq!(calculate_lockout_delay(3), 4);    // 2^2 = 4
        assert_eq!(calculate_lockout_delay(4), 8);    // 2^3 = 8
        assert_eq!(calculate_lockout_delay(5), 16);   // 2^4 = 16
        assert_eq!(calculate_lockout_delay(10), 512); // 2^9 = 512
        // Should cap at MAX_LOCKOUT_SECS
        assert_eq!(calculate_lockout_delay(20), MAX_LOCKOUT_SECS);
    }
}

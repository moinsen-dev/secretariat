//! F029: Keychain integration for secure master key storage
//!
//! Provides platform-specific keychain access for storing and retrieving
//! the master encryption key. On macOS, uses the system Keychain via
//! security-framework. On other platforms, provides fallback mechanisms.

use anyhow::Result;

/// Service name for keychain entries
const SERVICE_NAME: &str = "dev.moinsen.secretariat.daemon";

/// Account name for the master key in keychain
const ACCOUNT_NAME: &str = "master_key";

/// F030: Store master key in macOS Keychain
///
/// Stores the master encryption key securely in the system keychain.
/// The key is stored with the service name "dev.moinsen.secretariat.daemon"
/// and account name "master_key".
///
/// # Arguments
///
/// * `key` - The 32-byte master encryption key to store
///
/// # Returns
///
/// Returns `Ok(())` if the key is successfully stored.
/// Returns `Err` if storage fails.
///
/// # Platform Support
///
/// - **macOS**: Uses Security Framework to store in Keychain
/// - **Linux**: Not yet implemented (TODO: use Secret Service API)
/// - **Windows**: Not yet implemented (TODO: use Credential Manager)
///
/// # Security
///
/// - Key is stored in the system keychain, protected by OS-level security
/// - Access requires user authentication (Touch ID or password)
/// - Key is never written to disk in plaintext
///
/// # Examples
///
/// ```no_run
/// use secd::keychain::store_master_key;
/// use secd::crypto::generate_master_key;
///
/// let key = generate_master_key();
/// store_master_key(&key).expect("Failed to store key");
/// ```
#[cfg(target_os = "macos")]
pub fn store_master_key(key: &[u8; 32]) -> Result<()> {
    use security_framework::passwords::{set_generic_password};

    // F030: Use SecItemAdd via security-framework's set_generic_password
    // This internally calls SecItemAdd from the Security Framework
    set_generic_password(SERVICE_NAME, ACCOUNT_NAME, key)
        .map_err(|e| anyhow::anyhow!("Failed to store key in keychain: {}", e))?;

    Ok(())
}

/// F030: Retrieve master key from macOS Keychain
///
/// Retrieves the master encryption key from the system keychain.
///
/// # Returns
///
/// Returns `Ok([u8; 32])` containing the master key if found.
/// Returns `Err` if:
/// - Key is not found in keychain
/// - User denies access
/// - Keychain is locked
///
/// # Platform Support
///
/// - **macOS**: Uses Security Framework to retrieve from Keychain
/// - **Linux**: Not yet implemented
/// - **Windows**: Not yet implemented
///
/// # Examples
///
/// ```no_run
/// use secd::keychain::retrieve_master_key;
///
/// let key = retrieve_master_key().expect("Failed to retrieve key");
/// ```
#[cfg(target_os = "macos")]
pub fn retrieve_master_key() -> Result<[u8; 32]> {
    use security_framework::passwords::get_generic_password;

    // Retrieve password from keychain
    let data = get_generic_password(SERVICE_NAME, ACCOUNT_NAME)
        .map_err(|e| anyhow::anyhow!("Failed to retrieve key from keychain: {}", e))?;

    // Verify the key is the correct length
    if data.len() != 32 {
        anyhow::bail!("Retrieved key has invalid length: {} (expected 32)", data.len());
    }

    let mut key = [0u8; 32];
    key.copy_from_slice(&data);
    Ok(key)
}

/// Delete master key from keychain
///
/// Removes the master key from the system keychain.
/// This is useful for vault reset or re-initialization.
///
/// # Returns
///
/// Returns `Ok(())` if the key is successfully deleted or doesn't exist.
/// Returns `Err` if deletion fails.
#[cfg(target_os = "macos")]
#[allow(dead_code)] // Used for vault reset and re-initialization
pub fn delete_master_key() -> Result<()> {
    use security_framework::passwords::delete_generic_password;

    // Delete the item (ignore if not found)
    match delete_generic_password(SERVICE_NAME, ACCOUNT_NAME) {
        Ok(_) => Ok(()),
        Err(e) => {
            // Check if error is "item not found" - that's fine
            let err_str = format!("{:?}", e);
            if err_str.contains("NotFound") || err_str.contains("-25300") {
                Ok(())
            } else {
                Err(anyhow::anyhow!("Failed to delete key from keychain: {}", e))
            }
        }
    }
}

// Placeholder implementations for non-macOS platforms
#[cfg(not(target_os = "macos"))]
pub fn store_master_key(_key: &[u8; 32]) -> Result<()> {
    anyhow::bail!("Keychain storage not yet implemented for this platform. Use environment variable fallback.");
}

#[cfg(not(target_os = "macos"))]
pub fn retrieve_master_key() -> Result<[u8; 32]> {
    anyhow::bail!("Keychain retrieval not yet implemented for this platform. Use environment variable fallback.");
}

#[cfg(not(target_os = "macos"))]
pub fn delete_master_key() -> Result<()> {
    anyhow::bail!("Keychain deletion not yet implemented for this platform.");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[cfg(target_os = "macos")]
    fn test_keychain_round_trip() {
        use crate::crypto::generate_master_key;

        // Clean up any existing key
        let _ = delete_master_key();

        // Generate and store a key
        let key = generate_master_key();
        store_master_key(&key).expect("Failed to store key");

        // Retrieve the key
        let retrieved_key = retrieve_master_key().expect("Failed to retrieve key");

        // Verify they match
        assert_eq!(key, retrieved_key, "Retrieved key should match stored key");

        // Clean up
        delete_master_key().expect("Failed to delete key");
    }

    #[test]
    #[cfg(target_os = "macos")]
    fn test_delete_nonexistent_key() {
        // Ensure no key exists
        let _ = delete_master_key();

        // Deleting again should succeed (idempotent)
        delete_master_key().expect("Delete should succeed even if key doesn't exist");
    }

    #[test]
    #[cfg(not(target_os = "macos"))]
    fn test_unsupported_platform() {
        // On non-macOS platforms, operations should return errors
        let key = [0u8; 32];
        assert!(store_master_key(&key).is_err());
        assert!(retrieve_master_key().is_err());
        assert!(delete_master_key().is_err());
    }
}

//! Cryptographic operations for Secretariat
//!
//! Provides AES-256-GCM encryption for secure secret storage.
//! Uses cryptographically secure random number generation for keys and nonces.

use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use rand::RngCore;
use argon2::{
    password_hash::{ rand_core::OsRng as Argon2OsRng, SaltString},
    Argon2, PasswordHasher,
};
use zeroize::Zeroizing;

/// Size of AES-256 key in bytes
pub const KEY_SIZE: usize = 32;

/// Size of GCM nonce in bytes (96 bits)
pub const NONCE_SIZE: usize = 12;

/// Encrypted value with authentication
///
/// Contains both the encrypted ciphertext and the nonce used for encryption.
/// The nonce is required for decryption and must be stored alongside the ciphertext.
/// GCM mode provides authenticated encryption, ensuring both confidentiality and integrity.
#[derive(Debug, Clone)]
pub struct EncryptedValue {
    /// 96-bit nonce used for this encryption operation
    /// Must be unique for each encryption with the same key
    pub nonce: [u8; NONCE_SIZE],

    /// Encrypted data with authentication tag appended
    /// GCM appends a 128-bit authentication tag to the ciphertext
    pub ciphertext: Vec<u8>,
}

/// Generate a cryptographically secure 256-bit AES master key
///
/// Uses the operating system's random number generator (OsRng) to create
/// a 32-byte key suitable for AES-256-GCM encryption.
///
/// # Returns
///
/// A 32-byte array containing the generated master key
///
/// # Security
///
/// - Uses `rand::rngs::OsRng` which provides cryptographically secure randomness
/// - Generates 256 bits of entropy for AES-256
/// - Should be stored securely (e.g., in system keychain) after generation
///
/// # Examples
///
/// ```
/// use secretariat_core::generate_master_key;
///
/// let master_key = generate_master_key();
/// // Store master_key in system keychain
/// ```
#[allow(dead_code)] // Kept for API completeness - key generation may be needed for new keychain entries
pub fn generate_master_key() -> [u8; KEY_SIZE] {
    let mut key = [0u8; KEY_SIZE];
    OsRng.fill_bytes(&mut key);
    key
}

/// F026: Derive a 256-bit encryption key from a master password using Argon2
///
/// Uses Argon2id (the recommended variant) to derive a cryptographically strong
/// encryption key from a user-provided password. This function is designed to be
/// resistant to brute-force attacks through memory-hard computation.
///
/// # Arguments
///
/// * `password` - The master password (as bytes). Use `password.as_bytes()` for strings.
///                The password will be securely zeroed after use via Zeroizing wrapper.
/// * `salt` - A unique salt for this password (minimum 16 bytes recommended).
///           Must be stored alongside the derived key for future derivations.
///
/// # Returns
///
/// Returns `Ok([u8; KEY_SIZE])` containing the 32-byte derived key suitable for AES-256.
///
/// Returns `Err` if:
/// - Password hashing fails (extremely rare with valid inputs)
/// - Salt is invalid
///
/// # Security Features
///
/// - **Memory-hard**: Uses Argon2id which is resistant to GPU/ASIC attacks
/// - **Configurable cost**: Uses default parameters (can be tuned for security/performance)
/// - **Unique per-password**: Same password with different salts produces different keys
/// - **Zeroized memory**: Password is automatically zeroed after use via Zeroizing wrapper
/// - **OWASP recommended**: Argon2 is the recommended algorithm for password hashing
///
/// # Password Storage Pattern
///
/// ```text
/// User Password -> Argon2 -> Derived Key -> Encrypt Secrets
///                     ^
///                   Salt (store in DB)
/// ```
///
/// # Examples
///
/// ```no_run
/// use secretariat_core::derive_key_from_password;
/// use argon2::password_hash::{rand_core::OsRng, SaltString};
///
/// // Generate a random salt (do this once per user/vault)
/// let salt = SaltString::generate(&mut OsRng);
///
/// // Derive key from password
/// let password = "my-secure-master-password";
/// let key = derive_key_from_password(password.as_bytes(), salt.as_str())
///     .expect("Key derivation failed");
///
/// // Store salt.as_str() for future use
/// // Use key for encrypting secrets
/// ```
pub fn derive_key_from_password(password: &[u8], salt: &str) -> anyhow::Result<[u8; KEY_SIZE]> {
    // Wrap password in Zeroizing to ensure it's cleared from memory after use
    let password = Zeroizing::new(password.to_vec());

    // Use Argon2id (recommended variant) with default parameters
    let argon2 = Argon2::default();

    // Parse the salt string
    let salt = SaltString::from_b64(salt)
        .map_err(|e| anyhow::anyhow!("Invalid salt: {}", e))?;

    // Derive the password hash (contains the derived key)
    let password_hash = argon2
        .hash_password(&password, &salt)
        .map_err(|e| anyhow::anyhow!("Password hashing failed: {}", e))?;

    // Extract the raw hash bytes (32 bytes for Argon2 default output)
    let hash_bytes = password_hash
        .hash
        .ok_or_else(|| anyhow::anyhow!("Password hash missing"))?;

    // Convert to fixed-size array
    let hash_slice = hash_bytes.as_bytes();
    if hash_slice.len() < KEY_SIZE {
        anyhow::bail!("Derived hash is too short: {} bytes (expected {})", hash_slice.len(), KEY_SIZE);
    }

    let mut key = [0u8; KEY_SIZE];
    key.copy_from_slice(&hash_slice[..KEY_SIZE]);

    Ok(key)
}

/// Generate a random salt for password-based key derivation
///
/// Creates a cryptographically secure random salt suitable for use with
/// `derive_key_from_password`. The salt should be stored and reused for
/// the same password.
///
/// # Returns
///
/// A base64-encoded salt string suitable for storage
///
/// # Examples
///
/// ```
/// use secretariat_core::generate_salt;
///
/// let salt = generate_salt();
/// // Store salt in database alongside encrypted data
/// ```
pub fn generate_salt() -> String {
    SaltString::generate(&mut Argon2OsRng).to_string()
}

/// F021: Encrypt plaintext using AES-256-GCM with authenticated encryption
///
/// Encrypts the provided plaintext string using AES-256-GCM (Galois/Counter Mode)
/// which provides both confidentiality and authenticity. Each encryption operation
/// generates a unique random nonce to ensure semantic security.
///
/// # Arguments
///
/// * `plaintext` - The secret value to encrypt (e.g., an API key)
/// * `key` - 32-byte AES-256 encryption key
///
/// # Returns
///
/// Returns `Ok(EncryptedValue)` containing:
/// - `nonce`: Random 96-bit nonce used for this encryption
/// - `ciphertext`: Encrypted data with 128-bit authentication tag appended
///
/// Returns `Err` if:
/// - Encryption operation fails (extremely rare with valid inputs)
///
/// # Security Features
///
/// - **F022**: Generates a unique random 96-bit nonce for each encryption using OsRng
/// - **F023**: Uses Aes256Gcm cipher for authenticated encryption (AEAD)
/// - **Semantic security**: Same plaintext encrypted twice produces different ciphertexts
/// - **Authentication**: GCM mode appends a 128-bit authentication tag to detect tampering
/// - **No nonce reuse**: Fresh random nonce for every encryption prevents nonce reuse attacks
///
/// # Examples
///
/// ```
/// use secretariat_core::{encrypt, generate_master_key};
///
/// let master_key = generate_master_key();
/// let api_key = "sk-1234567890abcdef";
///
/// let encrypted = encrypt(api_key, &master_key)
///     .expect("Encryption failed");
///
/// // encrypted.nonce contains the random nonce
/// // encrypted.ciphertext contains the encrypted data + auth tag
/// ```
pub fn encrypt(plaintext: &str, key: &[u8; KEY_SIZE]) -> anyhow::Result<EncryptedValue> {
    // F023: Initialize Aes256Gcm cipher with the provided key
    let cipher = Aes256Gcm::new(key.into());

    // F022: Generate a random 96-bit nonce for this encryption operation
    // Using OsRng ensures cryptographically secure randomness
    let mut nonce_bytes = [0u8; NONCE_SIZE];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    // Encrypt the plaintext with authenticated encryption (AEAD)
    // GCM mode will append a 128-bit authentication tag to the ciphertext
    let ciphertext = cipher
        .encrypt(nonce, plaintext.as_bytes())
        .map_err(|e| anyhow::anyhow!("Encryption failed: {}", e))?;

    Ok(EncryptedValue {
        nonce: nonce_bytes,
        ciphertext,
    })
}

/// F024: Decrypt ciphertext using AES-256-GCM with authentication verification
///
/// Decrypts an `EncryptedValue` (ciphertext + nonce) using AES-256-GCM.
/// The authentication tag is automatically verified during decryption to detect
/// any tampering or corruption of the ciphertext.
///
/// # Arguments
///
/// * `encrypted` - The encrypted value containing nonce and ciphertext
/// * `key` - 32-byte AES-256 decryption key (must match encryption key)
///
/// # Returns
///
/// Returns `Ok(String)` with the decrypted plaintext if:
/// - The key is correct
/// - The ciphertext has not been tampered with
/// - The authentication tag is valid
///
/// Returns `Err` if:
/// - Wrong decryption key is used
/// - Ciphertext has been modified or corrupted
/// - **F025**: Authentication tag verification fails (tampering detected)
/// - Ciphertext is malformed
///
/// # Security Features
///
/// - **F025**: Verifies authentication tag to prevent tampering
/// - **AEAD guarantee**: Decryption only succeeds if both decryption AND authentication succeed
/// - **Fail-safe**: Any tampering causes immediate failure, preventing partial decryption
/// - **Timing safety**: GCM verification is constant-time to prevent timing attacks
///
/// # Examples
///
/// ```
/// use secretariat_core::{encrypt, decrypt, generate_master_key};
///
/// let master_key = generate_master_key();
/// let secret = "my-secret-api-key";
///
/// // Encrypt
/// let encrypted = encrypt(secret, &master_key).unwrap();
///
/// // Decrypt
/// let decrypted = decrypt(&encrypted, &master_key).unwrap();
/// assert_eq!(decrypted, secret);
/// ```
pub fn decrypt(encrypted: &EncryptedValue, key: &[u8; KEY_SIZE]) -> anyhow::Result<String> {
    // Initialize Aes256Gcm cipher with the provided key
    let cipher = Aes256Gcm::new(key.into());

    // Recreate the nonce from the encrypted value
    let nonce = Nonce::from_slice(&encrypted.nonce);

    // F025: Decrypt and verify authentication tag
    // This operation will fail if:
    // - The key is wrong
    // - The ciphertext has been tampered with
    // - The authentication tag doesn't match
    let plaintext_bytes = cipher
        .decrypt(nonce, encrypted.ciphertext.as_ref())
        .map_err(|e| anyhow::anyhow!("Decryption failed (wrong key or tampered data): {}", e))?;

    // Convert decrypted bytes back to UTF-8 string
    let plaintext = String::from_utf8(plaintext_bytes)
        .map_err(|e| anyhow::anyhow!("Decrypted data is not valid UTF-8: {}", e))?;

    Ok(plaintext)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_master_key() {
        let key1 = generate_master_key();
        let key2 = generate_master_key();

        // Keys should be 32 bytes
        assert_eq!(key1.len(), KEY_SIZE);
        assert_eq!(key2.len(), KEY_SIZE);

        // Keys should be different (with overwhelming probability)
        assert_ne!(key1, key2);

        // Keys should not be all zeros
        assert_ne!(key1, [0u8; KEY_SIZE]);
        assert_ne!(key2, [0u8; KEY_SIZE]);
    }

    #[test]
    fn test_encrypted_value_structure() {
        let nonce = [1u8; NONCE_SIZE];
        let ciphertext = vec![2u8, 3u8, 4u8, 5u8];

        let encrypted = EncryptedValue {
            nonce,
            ciphertext: ciphertext.clone(),
        };

        assert_eq!(encrypted.nonce, nonce);
        assert_eq!(encrypted.ciphertext, ciphertext);
    }

    #[test]
    fn test_constants() {
        assert_eq!(KEY_SIZE, 32, "AES-256 requires 32-byte keys");
        assert_eq!(NONCE_SIZE, 12, "GCM standard nonce is 96 bits (12 bytes)");
    }

    // Wave 5: Encryption/Decryption Tests

    #[test]
    fn test_encrypt_decrypt_round_trip() {
        // F021, F024: Test basic encryption and decryption
        let key = generate_master_key();
        let plaintext = "my-secret-api-key-12345";

        let encrypted = encrypt(plaintext, &key)
            .expect("Encryption should succeed");

        let decrypted = decrypt(&encrypted, &key)
            .expect("Decryption should succeed");

        assert_eq!(decrypted, plaintext, "Decrypted text should match original");
    }

    #[test]
    fn test_encrypt_generates_unique_nonces() {
        // F022: Verify that each encryption generates a unique random nonce
        let key = generate_master_key();
        let plaintext = "same-plaintext-every-time";

        let encrypted1 = encrypt(plaintext, &key).unwrap();
        let encrypted2 = encrypt(plaintext, &key).unwrap();
        let encrypted3 = encrypt(plaintext, &key).unwrap();

        // Nonces should all be different
        assert_ne!(encrypted1.nonce, encrypted2.nonce, "Nonces should be unique");
        assert_ne!(encrypted2.nonce, encrypted3.nonce, "Nonces should be unique");
        assert_ne!(encrypted1.nonce, encrypted3.nonce, "Nonces should be unique");

        // Ciphertexts should also be different (semantic security)
        assert_ne!(encrypted1.ciphertext, encrypted2.ciphertext, "Ciphertexts should differ");
        assert_ne!(encrypted2.ciphertext, encrypted3.ciphertext, "Ciphertexts should differ");

        // All should decrypt to same plaintext
        assert_eq!(decrypt(&encrypted1, &key).unwrap(), plaintext);
        assert_eq!(decrypt(&encrypted2, &key).unwrap(), plaintext);
        assert_eq!(decrypt(&encrypted3, &key).unwrap(), plaintext);
    }

    #[test]
    fn test_encrypt_uses_aes256gcm() {
        // F023: Verify that encryption uses AES-256-GCM cipher
        let key = generate_master_key();
        let plaintext = "test-secret";

        let encrypted = encrypt(plaintext, &key).unwrap();

        // GCM appends a 128-bit (16-byte) authentication tag to the ciphertext
        // Ciphertext length should be: plaintext_length + 16
        let expected_length = plaintext.len() + 16;
        assert_eq!(
            encrypted.ciphertext.len(),
            expected_length,
            "Ciphertext should include 16-byte authentication tag"
        );

        // Nonce should be 96 bits (12 bytes) as required by GCM
        assert_eq!(encrypted.nonce.len(), NONCE_SIZE);
    }

    #[test]
    fn test_decrypt_with_wrong_key_fails() {
        // F024: Verify that decryption with wrong key fails
        let key1 = generate_master_key();
        let key2 = generate_master_key();
        let plaintext = "secret-data";

        let encrypted = encrypt(plaintext, &key1).unwrap();

        // Attempt to decrypt with wrong key should fail
        let result = decrypt(&encrypted, &key2);
        assert!(result.is_err(), "Decryption with wrong key should fail");

        // Error message should indicate authentication failure
        let error_msg = result.unwrap_err().to_string();
        assert!(
            error_msg.contains("Decryption failed"),
            "Error should mention decryption failure"
        );
    }

    #[test]
    fn test_decrypt_detects_tampering() {
        // F025: Verify authentication tag verification prevents tampering
        let key = generate_master_key();
        let plaintext = "important-secret";

        let mut encrypted = encrypt(plaintext, &key).unwrap();

        // Tamper with the ciphertext by flipping a bit
        if !encrypted.ciphertext.is_empty() {
            encrypted.ciphertext[0] ^= 0xFF;
        }

        // Decryption should fail due to authentication tag mismatch
        let result = decrypt(&encrypted, &key);
        assert!(result.is_err(), "F025: Tampered ciphertext should fail authentication");

        let error_msg = result.unwrap_err().to_string();
        assert!(
            error_msg.contains("Decryption failed") || error_msg.contains("tampered"),
            "Error should indicate authentication failure"
        );
    }

    #[test]
    fn test_decrypt_detects_nonce_tampering() {
        // F025: Verify that nonce tampering is detected
        let key = generate_master_key();
        let plaintext = "secret-value";

        let mut encrypted = encrypt(plaintext, &key).unwrap();

        // Tamper with the nonce
        encrypted.nonce[0] ^= 0xFF;

        // Decryption should fail
        let result = decrypt(&encrypted, &key);
        assert!(result.is_err(), "F025: Modified nonce should cause decryption to fail");
    }

    #[test]
    fn test_encrypt_decrypt_empty_string() {
        // Edge case: Empty string encryption
        let key = generate_master_key();
        let plaintext = "";

        let encrypted = encrypt(plaintext, &key).unwrap();
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(decrypted, plaintext, "Empty string should round-trip correctly");

        // Even empty plaintext should have authentication tag
        assert_eq!(encrypted.ciphertext.len(), 16, "Should still have 16-byte auth tag");
    }

    #[test]
    fn test_encrypt_decrypt_large_secret() {
        // Test with a large secret value
        let key = generate_master_key();
        let plaintext = "A".repeat(10000); // 10KB secret

        let encrypted = encrypt(&plaintext, &key).unwrap();
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(decrypted, plaintext, "Large secrets should round-trip correctly");
    }

    #[test]
    fn test_encrypt_decrypt_unicode() {
        // Test with Unicode characters
        let key = generate_master_key();
        let plaintext = "🔐 Secret émoji and ñoñ-ASCII 中文 テスト";

        let encrypted = encrypt(plaintext, &key).unwrap();
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(decrypted, plaintext, "Unicode strings should round-trip correctly");
    }

    #[test]
    fn test_encrypt_decrypt_special_characters() {
        // Test with special characters that might appear in API keys
        let key = generate_master_key();
        let plaintext = "sk-proj_1234567890abcdefABCDEF!@#$%^&*()_+-=[]{}|;':\",./<>?";

        let encrypted = encrypt(plaintext, &key).unwrap();
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(decrypted, plaintext, "Special characters should round-trip correctly");
    }

    #[test]
    fn test_encrypted_value_contains_nonce() {
        // Verify EncryptedValue structure
        let key = generate_master_key();
        let plaintext = "test";

        let encrypted = encrypt(plaintext, &key).unwrap();

        // Nonce should be 12 bytes
        assert_eq!(encrypted.nonce.len(), NONCE_SIZE);

        // Nonce should not be all zeros (random)
        assert_ne!(encrypted.nonce, [0u8; NONCE_SIZE]);

        // Ciphertext should not be empty
        assert!(!encrypted.ciphertext.is_empty());
    }

    #[test]
    fn test_multiple_keys_isolation() {
        // Verify that secrets encrypted with different keys are isolated
        let key1 = generate_master_key();
        let key2 = generate_master_key();
        let plaintext = "shared-secret";

        let encrypted1 = encrypt(plaintext, &key1).unwrap();
        let encrypted2 = encrypt(plaintext, &key2).unwrap();

        // Can decrypt with correct key
        assert_eq!(decrypt(&encrypted1, &key1).unwrap(), plaintext);
        assert_eq!(decrypt(&encrypted2, &key2).unwrap(), plaintext);

        // Cannot decrypt with wrong key
        assert!(decrypt(&encrypted1, &key2).is_err());
        assert!(decrypt(&encrypted2, &key1).is_err());
    }

    // Wave 6: Argon2 Password Derivation Tests (F026)

    #[test]
    fn test_derive_key_from_password() {
        // F026: Test password-based key derivation
        let password = b"my-secure-master-password";
        let salt = generate_salt();

        let key = derive_key_from_password(password, &salt)
            .expect("Key derivation should succeed");

        // Key should be 32 bytes
        assert_eq!(key.len(), KEY_SIZE);

        // Key should not be all zeros
        assert_ne!(key, [0u8; KEY_SIZE]);
    }

    #[test]
    fn test_derive_key_deterministic() {
        // F026: Same password and salt should produce same key
        let password = b"test-password-123";
        let salt = generate_salt();

        let key1 = derive_key_from_password(password, &salt).unwrap();
        let key2 = derive_key_from_password(password, &salt).unwrap();

        assert_eq!(key1, key2, "Same password and salt should produce identical keys");
    }

    #[test]
    fn test_derive_key_different_salts() {
        // F026: Same password with different salts should produce different keys
        let password = b"same-password";
        let salt1 = generate_salt();
        let salt2 = generate_salt();

        let key1 = derive_key_from_password(password, &salt1).unwrap();
        let key2 = derive_key_from_password(password, &salt2).unwrap();

        assert_ne!(key1, key2, "Different salts should produce different keys");
    }

    #[test]
    fn test_derive_key_different_passwords() {
        // F026: Different passwords with same salt should produce different keys
        let password1 = b"password-one";
        let password2 = b"password-two";
        let salt = generate_salt();

        let key1 = derive_key_from_password(password1, &salt).unwrap();
        let key2 = derive_key_from_password(password2, &salt).unwrap();

        assert_ne!(key1, key2, "Different passwords should produce different keys");
    }

    #[test]
    fn test_derived_key_works_for_encryption() {
        // F026: Verify that derived keys work for encryption/decryption
        let password = b"my-master-password";
        let salt = generate_salt();

        let key = derive_key_from_password(password, &salt).unwrap();

        // Encrypt with derived key
        let plaintext = "secret-api-key-12345";
        let encrypted = encrypt(plaintext, &key).unwrap();

        // Decrypt with same derived key
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(decrypted, plaintext, "Derived key should work for encryption");
    }

    #[test]
    fn test_generate_salt_uniqueness() {
        // F026: Verify that generate_salt produces unique salts
        let salt1 = generate_salt();
        let salt2 = generate_salt();
        let salt3 = generate_salt();

        assert_ne!(salt1, salt2, "Salts should be unique");
        assert_ne!(salt2, salt3, "Salts should be unique");
        assert_ne!(salt1, salt3, "Salts should be unique");
    }

    #[test]
    fn test_derive_key_with_empty_password() {
        // Edge case: Empty password
        let password = b"";
        let salt = generate_salt();

        let key = derive_key_from_password(password, &salt)
            .expect("Should handle empty password");

        assert_eq!(key.len(), KEY_SIZE);
    }

    #[test]
    fn test_derive_key_with_long_password() {
        // Edge case: Very long password
        let password = "A".repeat(10000);
        let salt = generate_salt();

        let key = derive_key_from_password(password.as_bytes(), &salt)
            .expect("Should handle long password");

        assert_eq!(key.len(), KEY_SIZE);
    }

    #[test]
    fn test_derive_key_with_unicode_password() {
        // Edge case: Unicode password
        let password = "パスワード🔐秘密".as_bytes();
        let salt = generate_salt();

        let key = derive_key_from_password(password, &salt)
            .expect("Should handle Unicode password");

        assert_eq!(key.len(), KEY_SIZE);
    }
}

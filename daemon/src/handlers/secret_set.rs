//! Handler for secret.set method
//!
//! Creates or updates a secret with encrypted storage.
//!
//! ## Wave 13 Features:
//! - F063: Create handlers/secret_set.rs file
//! - F064: Implement handle_secret_set(name: &str, value: &str, storage: &Storage, master_key: &[u8; 32]) -> Result<()>
//! - F065: Encrypt value using AES-256-GCM with random nonce

use anyhow::{Result, Context};

use crate::storage::Storage;
use crate::crypto::encrypt;

/// Auto-detect provider from secret name
///
/// Analyzes the secret name to determine which service provider it belongs to.
/// This enables better organization and categorization of secrets.
///
/// # Arguments
///
/// * `name` - The name of the secret (e.g., "OPENAI_API_KEY", "STRIPE_SECRET_KEY")
///
/// # Returns
///
/// An optional provider name string if detected
///
/// # Detection Rules
///
/// - Names starting with "OPENAI_" -> "openai"
/// - Names starting with "ANTHROPIC_" -> "anthropic"
/// - Names starting with "STRIPE_" -> "stripe"
/// - Names starting with "AWS_" -> "aws"
/// - Names starting with "GITHUB_" -> "github"
/// - Names starting with "GOOGLE_" -> "google"
/// - Names containing "DATABASE" or "DB_" -> "database"
/// - Otherwise -> None
///
/// # Examples
///
/// ```
/// assert_eq!(detect_provider("OPENAI_API_KEY"), Some("openai"));
/// assert_eq!(detect_provider("STRIPE_SECRET_KEY"), Some("stripe"));
/// assert_eq!(detect_provider("MY_CUSTOM_SECRET"), None);
/// ```
fn detect_provider(name: &str) -> Option<&str> {
    let name_upper = name.to_uppercase();

    if name_upper.starts_with("OPENAI_") {
        Some("openai")
    } else if name_upper.starts_with("ANTHROPIC_") {
        Some("anthropic")
    } else if name_upper.starts_with("STRIPE_") {
        Some("stripe")
    } else if name_upper.starts_with("AWS_") {
        Some("aws")
    } else if name_upper.starts_with("GITHUB_") {
        Some("github")
    } else if name_upper.starts_with("GOOGLE_") {
        Some("google")
    } else if name_upper.contains("DATABASE") || name_upper.starts_with("DB_") {
        Some("database")
    } else {
        None
    }
}

/// Handle secret.set method
///
/// Creates a new secret or updates an existing one. The value is encrypted
/// using AES-256-GCM before storage, and the provider is auto-detected from
/// the secret name.
///
/// # Arguments
///
/// * `name` - The name of the secret (e.g., "OPENAI_API_KEY")
/// * `value` - The plaintext secret value to encrypt and store
/// * `storage` - Reference to the storage layer
/// * `master_key` - The 32-byte master encryption key from keychain
/// * `environment` - Optional environment context (defaults to "default")
/// * `provider_override` - Optional provider override (auto-detected if None)
///
/// # Returns
///
/// Returns `Ok(())` on success
///
/// # Errors
///
/// Returns an error if:
/// - F065: Encryption fails
/// - F064: Database storage fails
/// - Provider detection fails (should not happen)
///
/// # Features
///
/// - F063: Handler file created
/// - F064: Implements handle_secret_set function
/// - F065: Encrypts value using AES-256-GCM with random nonce
///
/// # Security
///
/// This function ensures:
/// 1. The plaintext value is never written to disk
/// 2. Each encryption uses a unique random nonce
/// 3. The nonce is stored alongside the ciphertext
/// 4. The provider is auto-detected for better organization
///
/// # Storage Format
///
/// The encrypted value is stored as: nonce (12 bytes) + ciphertext (variable length)
/// This allows for easy decryption by reading the nonce from the first 12 bytes.
///
/// # Examples
///
/// ```no_run
/// use secd::handlers::handle_secret_set;
/// use secd::storage::Storage;
///
/// let storage = Storage::new("vault.db", "encryption_key").unwrap();
/// let master_key = [0u8; 32]; // In production, from keychain
///
/// handle_secret_set("OPENAI_API_KEY", "sk-1234567890", &storage, &master_key, None, None)
///     .expect("Failed to set secret");
/// ```
pub fn handle_secret_set(
    name: &str,
    value: &str,
    storage: &Storage,
    master_key: &[u8; 32],
    environment: Option<&str>,
    provider_override: Option<&str>,
) -> Result<()> {
    // F065: Encrypt the value using AES-256-GCM with random nonce
    let encrypted = encrypt(value, master_key)
        .context("Failed to encrypt secret value")?;

    // Concatenate nonce and ciphertext for storage
    // Format: nonce (12 bytes) + ciphertext (variable length)
    let mut value_encrypted = Vec::with_capacity(encrypted.nonce.len() + encrypted.ciphertext.len());
    value_encrypted.extend_from_slice(&encrypted.nonce);
    value_encrypted.extend_from_slice(&encrypted.ciphertext);

    // Use provider override if provided, otherwise auto-detect from secret name
    let provider = provider_override.or_else(|| detect_provider(name));

    // Use provided environment or default to "default"
    let env = environment.unwrap_or("default");

    // F064: Store the encrypted value in the database
    storage.create_secret(name, &value_encrypted, provider, env)
        .context("Failed to store secret")?;

    // Log the secret creation/update
    storage.log_audit("system", name, "write", true, None)
        .context("Failed to log audit entry")?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_provider_openai() {
        assert_eq!(detect_provider("OPENAI_API_KEY"), Some("openai"));
        assert_eq!(detect_provider("openai_api_key"), Some("openai"));
        assert_eq!(detect_provider("OPENAI_ORG_ID"), Some("openai"));
    }

    #[test]
    fn test_detect_provider_anthropic() {
        assert_eq!(detect_provider("ANTHROPIC_API_KEY"), Some("anthropic"));
        assert_eq!(detect_provider("anthropic_api_key"), Some("anthropic"));
    }

    #[test]
    fn test_detect_provider_stripe() {
        assert_eq!(detect_provider("STRIPE_SECRET_KEY"), Some("stripe"));
        assert_eq!(detect_provider("STRIPE_PUBLISHABLE_KEY"), Some("stripe"));
    }

    #[test]
    fn test_detect_provider_aws() {
        assert_eq!(detect_provider("AWS_ACCESS_KEY_ID"), Some("aws"));
        assert_eq!(detect_provider("AWS_SECRET_ACCESS_KEY"), Some("aws"));
    }

    #[test]
    fn test_detect_provider_github() {
        assert_eq!(detect_provider("GITHUB_TOKEN"), Some("github"));
        assert_eq!(detect_provider("GITHUB_API_KEY"), Some("github"));
    }

    #[test]
    fn test_detect_provider_google() {
        assert_eq!(detect_provider("GOOGLE_API_KEY"), Some("google"));
        assert_eq!(detect_provider("GOOGLE_CLIENT_ID"), Some("google"));
    }

    #[test]
    fn test_detect_provider_database() {
        assert_eq!(detect_provider("DATABASE_URL"), Some("database"));
        assert_eq!(detect_provider("DB_HOST"), Some("database"));
        assert_eq!(detect_provider("POSTGRES_DATABASE"), Some("database"));
    }

    #[test]
    fn test_detect_provider_unknown() {
        assert_eq!(detect_provider("MY_CUSTOM_SECRET"), None);
        assert_eq!(detect_provider("API_KEY"), None);
        assert_eq!(detect_provider("SECRET_TOKEN"), None);
    }
}

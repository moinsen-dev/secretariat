//! Handler for vault.lock method
//!
//! Locks the vault by clearing the master key from memory.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::Result;

/// Result of vault lock operation
pub struct VaultLockResult {
    pub status: String,
}

/// Handle vault.lock method
///
/// Locks the vault by signaling that the master key should be cleared.
/// Note: The actual key clearing happens at the server level since
/// the key is stored in ServerState, not passed to handlers.
///
/// # Returns
///
/// Returns `Ok(VaultLockResult)` with status "locked"
pub fn handle_vault_lock() -> Result<VaultLockResult> {
    // The actual locking is handled by the server, which clears the master key.
    // This handler just returns the success status.
    tracing::info!("Vault lock requested");

    Ok(VaultLockResult {
        status: "locked".to_string(),
    })
}

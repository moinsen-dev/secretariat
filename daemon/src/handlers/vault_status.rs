//! Handler for vault.status method
//!
//! Returns the current vault state and statistics.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::Result;
use crate::storage::Storage;

/// Vault state enum
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VaultState {
    /// Vault is unlocked and operational
    Unlocked,
    /// Vault is locked (master key cleared from memory)
    Locked,
    /// Vault has not been initialized yet
    Uninitialized,
}

impl std::fmt::Display for VaultState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VaultState::Unlocked => write!(f, "unlocked"),
            VaultState::Locked => write!(f, "locked"),
            VaultState::Uninitialized => write!(f, "uninitialized"),
        }
    }
}

/// Result of vault status query
pub struct VaultStatusResult {
    pub state: VaultState,
    pub secret_count: i64,
    pub app_count: i64,
}

/// Handle vault.status method
///
/// Returns the current vault state and statistics.
///
/// # Arguments
///
/// * `storage` - Reference to storage layer
/// * `is_locked` - Whether the vault is currently locked (from server state)
///
/// # Returns
///
/// Returns `Ok(VaultStatusResult)` with current state and counts
pub fn handle_vault_status(storage: &Storage, is_locked: bool) -> Result<VaultStatusResult> {
    // Check if vault is initialized
    let is_initialized = storage.is_vault_initialized()?;

    let state = if !is_initialized {
        VaultState::Uninitialized
    } else if is_locked {
        VaultState::Locked
    } else {
        VaultState::Unlocked
    };

    // Get counts
    let secret_count = storage.count_secrets().unwrap_or(0);
    let app_count = storage.count_applications().unwrap_or(0);

    Ok(VaultStatusResult {
        state,
        secret_count,
        app_count,
    })
}

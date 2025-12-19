//! Lock command implementation
//!
//! Lock the vault, clearing the master key from memory.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// LockCommand arguments
pub struct LockCommand {}

#[derive(Debug, Deserialize)]
struct LockResponse {
    status: String,
}

/// Handle the lock command
///
/// Locks the vault by:
/// 1. Sending vault.lock request to daemon
/// 2. Daemon clears master key from memory
/// 3. All subsequent secret operations will fail until unlock
pub async fn handle_lock(client: DaemonClient, _cmd: LockCommand) -> Result<()> {
    let response: LockResponse = client
        .request("vault.lock", json!({}))
        .await
        .context("Failed to lock vault")?;

    if response.status == "locked" {
        println!("🔒 Vault locked");
        println!();
        println!("All secrets are now inaccessible.");
        println!("Use 'sec unlock' to unlock the vault.");
    } else {
        println!("Vault status: {}", response.status);
    }

    Ok(())
}

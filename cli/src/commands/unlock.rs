//! Unlock command implementation
//!
//! Unlock the vault with master password.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// UnlockCommand arguments
pub struct UnlockCommand {
    pub password: bool,
}

#[derive(Debug, Deserialize)]
struct UnlockResponse {
    status: String,
}

/// Handle the unlock command
///
/// Unlocks the vault by:
/// 1. Prompting for master password
/// 2. Sending vault.unlock request to daemon
/// 3. Daemon derives key from password and restores access
pub async fn handle_unlock(client: DaemonClient, _cmd: UnlockCommand) -> Result<()> {
    // Prompt for password
    print!("Enter master password: ");
    io::stdout().flush()?;
    let password = rpassword::read_password().context("Failed to read password")?;

    if password.is_empty() {
        println!("Password cannot be empty.");
        return Ok(());
    }

    println!("Unlocking vault...");

    let response: UnlockResponse = client
        .request(
            "vault.unlock",
            json!({
                "password": password
            }),
        )
        .await
        .context("Failed to unlock vault")?;

    if response.status == "unlocked" {
        println!("🔓 Vault unlocked");
        println!();
        println!("Secrets are now accessible.");
    } else {
        println!("Vault status: {}", response.status);
    }

    Ok(())
}

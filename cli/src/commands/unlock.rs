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
    /// Use password prompt instead of Touch ID
    pub password: bool,
    /// Optional password for non-interactive unlock.
    /// Falls back to $SECRETARIAT_INIT_PASSWORD env var (set in main.rs).
    pub password_value: Option<String>,
}

#[derive(Debug, Deserialize)]
struct UnlockResponse {
    status: String,
}

/// Handle the unlock command
///
/// Unlocks the vault by:
/// 1. Prompting for master password (or using provided one)
/// 2. Sending vault.unlock request to daemon
/// 3. Daemon derives key from password and restores access
pub async fn handle_unlock(client: DaemonClient, cmd: UnlockCommand) -> Result<()> {
    // Use provided password, env var, or prompt interactively
    let password = if let Some(pw) = cmd.password_value {
        if pw.is_empty() {
            anyhow::bail!("Password cannot be empty.");
        }
        pw
    } else {
        // Prompt interactively (Touch ID or rpassword)
        print!("Enter master password: ");
        io::stdout().flush()?;
        let pw = rpassword::read_password().context("Failed to read password")?;
        if pw.is_empty() {
            println!("Password cannot be empty.");
            return Ok(());
        }
        pw
    };

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

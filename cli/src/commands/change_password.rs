//! Change password command implementation
//!
//! Change the vault master password without losing secrets.
//!
//! Phase 2: Security Hardening

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// ChangePasswordCommand arguments (empty - uses interactive prompts)
pub struct ChangePasswordCommand;

#[derive(Debug, Deserialize)]
struct ChangePasswordResponse {
    status: String,
    secrets_migrated: usize,
}

/// Handle the change-password command
///
/// Changes the vault master password by:
/// 1. Prompting for current password
/// 2. Prompting for new password with confirmation
/// 3. Sending vault.change_password request to daemon
/// 4. Daemon re-encrypts all secrets with new key
pub async fn handle_change_password(client: DaemonClient, _cmd: ChangePasswordCommand) -> Result<()> {
    println!("Change Vault Master Password");
    println!("============================");
    println!();
    println!("This will re-encrypt all secrets with a new password.");
    println!("Make sure you remember your new password - it cannot be recovered!");
    println!();

    // Prompt for current password
    print!("Enter current password: ");
    io::stdout().flush()?;
    let current_password = rpassword::read_password().context("Failed to read password")?;

    if current_password.is_empty() {
        println!("Current password cannot be empty.");
        return Ok(());
    }

    // Prompt for new password
    print!("Enter new password (min 8 characters): ");
    io::stdout().flush()?;
    let new_password = rpassword::read_password().context("Failed to read password")?;

    if new_password.len() < 8 {
        println!("New password must be at least 8 characters long.");
        return Ok(());
    }

    // Confirm new password
    print!("Confirm new password: ");
    io::stdout().flush()?;
    let confirm_password = rpassword::read_password().context("Failed to read password")?;

    if new_password != confirm_password {
        println!("Passwords do not match.");
        return Ok(());
    }

    println!();
    println!("Changing password and re-encrypting secrets...");

    let response: ChangePasswordResponse = client
        .request(
            "vault.change_password",
            json!({
                "current_password": current_password,
                "new_password": new_password
            }),
        )
        .await
        .context("Failed to change password")?;

    if response.status == "password_changed" {
        println!("✅ Password changed successfully");
        println!();
        if response.secrets_migrated > 0 {
            println!("Re-encrypted {} secret(s) with new key.", response.secrets_migrated);
        }
        println!("The vault remains unlocked with your new password.");
    } else {
        println!("Password change status: {}", response.status);
    }

    Ok(())
}

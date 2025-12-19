//! F109-F113: Init command implementation
//!
//! Initialize the secrets vault with master password.
//!
//! Features:
//! - F109: Create commands/init.rs file
//! - F110: Prompt user for master password with rpassword crate
//! - F111: Confirm password with second prompt
//! - F112: Send init request to daemon with password
//! - F113: Display success message with vault location

use anyhow::{bail, Context, Result};
use serde_json::json;

use crate::client::DaemonClient;

/// InitCommand arguments
pub struct InitCommand {
    pub yes: bool,
}

/// F109-F113: Handle the init command
///
/// This command initializes the vault by:
/// 1. Prompting for a master password (twice for confirmation)
/// 2. Sending the init request to the daemon
/// 3. Displaying success with vault location
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments
///
/// # Returns
///
/// Returns Ok(()) on success, error if init fails
pub async fn handle_init(client: DaemonClient, cmd: InitCommand) -> Result<()> {
    println!("Initializing Secretariat vault...\n");

    // F110: Prompt for master password
    let password = if cmd.yes {
        // In non-interactive mode, can't prompt for password
        bail!("Cannot use --yes flag with init command. Password is required.");
    } else {
        prompt_password("Enter master password: ")?
    };

    // F111: Confirm password with second prompt
    let confirm_password = prompt_password("Confirm master password: ")?;

    // Validate passwords match
    if password != confirm_password {
        bail!("Passwords do not match. Please try again.");
    }

    // Validate password strength (basic check)
    if password.len() < 8 {
        bail!("Password must be at least 8 characters long.");
    }

    // F112: Send init request to daemon with password
    println!("\nInitializing vault...");

    let params = json!({
        "password": password
    });

    let response: serde_json::Value = client
        .request("vault.init", params)
        .await
        .context("Failed to initialize vault")?;

    // F113: Display success message with vault location
    let vault_path = response
        .get("vault_path")
        .and_then(|v| v.as_str())
        .unwrap_or("~/.secretariat");

    println!("\n✓ Vault initialized successfully!");
    println!("  Location: {}", vault_path);
    println!("\nYour vault is now ready to store secrets.");
    println!("Try: sec set MY_API_KEY <value>");

    Ok(())
}

/// F110: Prompt for password using rpassword
///
/// Reads password input without echoing to the terminal.
///
/// # Arguments
///
/// * `prompt` - Prompt message to display
///
/// # Returns
///
/// Returns the entered password
fn prompt_password(prompt: &str) -> Result<String> {
    rpassword::prompt_password(prompt).context("Failed to read password")
}

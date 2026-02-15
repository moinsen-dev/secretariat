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
    pub password_env: Option<String>,
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

    // F110: Prompt for master password or read from env var for automation
    let password = if let Some(env_var) = cmd.password_env.as_deref() {
        let value = std::env::var(env_var)
            .with_context(|| format!("Environment variable '{env_var}' is not set"))?;
        if value.is_empty() {
            bail!("Environment variable '{env_var}' is empty.");
        }
        value
    } else if cmd.yes {
        bail!("Cannot use --yes without --password-env. Password is required.");
    } else {
        prompt_password("Enter master password: ")?
    };

    // F111: Confirm password with second prompt (interactive only)
    if cmd.password_env.is_none() {
        let confirm_password = prompt_password("Confirm master password: ")?;

        // Validate passwords match
        if password != confirm_password {
            bail!("Passwords do not match. Please try again.");
        }
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

    // Keep vault immediately usable after init so scripted flows can continue.
    // We intentionally avoid keychain persistence here.
    let _: serde_json::Value = client
        .request(
            "vault.unlock",
            json!({
                "password": password,
                "store_for_biometric": false
            }),
        )
        .await
        .context("Vault initialized, but failed to unlock")?;

    // F113: Display success message with vault location
    let vault_path = response
        .get("vault_path")
        .and_then(|v| v.as_str())
        .unwrap_or("~/.secretariat");

    println!("\n✓ Vault initialized successfully!");
    println!("  Location: {}", vault_path);
    println!("  Vault: unlocked");
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

//! F127-F130: Delete command implementation
//!
//! Delete a secret from the vault.
//!
//! Features:
//! - F127: Create commands/delete.rs file
//! - F128: Prompt "Are you sure? (y/n)" unless --force flag
//! - F129: Send secret.delete request if confirmed
//! - F130: Display "Secret deleted" message

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// DeleteCommand arguments
pub struct DeleteCommand {
    pub key: String,
    pub force: bool,
}

/// Response from secret.delete
#[derive(Debug, Deserialize)]
struct DeleteResponse {
    name: String,
    status: String,
}

/// F127-F130: Handle the delete command
///
/// This command deletes a secret by:
/// 1. F128: Prompting "Are you sure? (y/n)" unless --force flag is set
/// 2. F129: Sending secret.delete request if confirmed
/// 3. F130: Displaying "Secret deleted" message
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments containing key and force flag
///
/// # Returns
///
/// Returns Ok(()) on success, error if delete fails
///
/// # Examples
///
/// ```bash
/// # Delete with confirmation prompt
/// sec delete OPENAI_API_KEY
///
/// # Force delete without prompt
/// sec delete OPENAI_API_KEY --force
/// ```
pub async fn handle_delete(client: DaemonClient, cmd: DeleteCommand) -> Result<()> {
    // F128: Prompt "Are you sure? (y/n)" unless --force flag
    if !cmd.force {
        print!("Are you sure you want to delete '{}'? (y/n): ", cmd.key);
        io::stdout()
            .flush()
            .context("Failed to flush stdout")?;

        let mut input = String::new();
        io::stdin()
            .read_line(&mut input)
            .context("Failed to read confirmation")?;

        let confirmation = input.trim().to_lowercase();

        if confirmation != "y" && confirmation != "yes" {
            println!("Deletion cancelled.");
            return Ok(());
        }
    }

    // F129: Send secret.delete request if confirmed
    let params = json!({
        "name": cmd.key,
    });

    let response: DeleteResponse = match client.request("secret.delete", params).await {
        Ok(resp) => resp,
        Err(e) => {
            let error_msg = e.to_string();

            // Check if it's a SecretNotFound error
            if error_msg.contains("not found") || error_msg.contains("-32001") {
                anyhow::bail!("Secret '{}' not found.\n\nTry: sec list", cmd.key);
            }

            // Generic error
            return Err(e).context(format!("Failed to delete secret '{}'", cmd.key));
        }
    };

    // F130: Display "Secret deleted" message
    println!("Secret deleted");
    println!();
    println!("  Name:   {}", response.name);
    println!("  Status: {}", response.status);

    Ok(())
}

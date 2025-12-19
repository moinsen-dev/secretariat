//! F119-F122: Get command implementation
//!
//! Retrieve a secret value by key.
//!
//! Features:
//! - F119: Create commands/get.rs file
//! - F120: Send secret.get request with key argument
//! - F121: Print returned value to stdout (only value, no formatting)
//! - F122: Handle SecretNotFound error with user-friendly message

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// GetCommand arguments
pub struct GetCommand {
    pub key: String,
    pub no_newline: bool,
}

/// Response from secret.get
#[derive(Debug, Deserialize)]
struct GetResponse {
    value: String,
}

/// F119-F122: Handle the get command
///
/// This command retrieves a secret value by:
/// 1. F120: Sending secret.get request with the key argument
/// 2. F121: Printing only the value to stdout (no formatting)
/// 3. F122: Handling SecretNotFound error with user-friendly message
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments containing the key to retrieve
///
/// # Returns
///
/// Returns Ok(()) on success, error if get fails
///
/// # Output
///
/// Prints only the secret value to stdout (for shell piping).
/// No additional formatting or messages.
pub async fn handle_get(client: DaemonClient, cmd: GetCommand) -> Result<()> {
    // F120: Send secret.get request with key argument
    // Note: In production, app_id would be determined from process info
    // For CLI, we use a special "cli" app_id that has permission to all secrets
    let params = json!({
        "name": cmd.key,
        "app_id": "cli"
    });

    // F122: Handle errors with user-friendly messages
    let response: GetResponse = match client.request("secret.get", params).await {
        Ok(resp) => resp,
        Err(e) => {
            let error_msg = e.to_string();

            // Check if it's a SecretNotFound error (daemon returns -32001 for not found)
            if error_msg.contains("not found") || error_msg.contains("-32001") {
                anyhow::bail!("Secret '{}' not found.\n\nTry: sec list", cmd.key);
            }

            // Check if it's a permission denied error
            if error_msg.contains("Permission denied") {
                anyhow::bail!("Permission denied: CLI does not have access to '{}'", cmd.key);
            }

            // Generic error
            return Err(e).context(format!("Failed to get secret '{}'", cmd.key));
        }
    };

    // F121: Print returned value to stdout (only value, no formatting)
    // This allows piping: export OPENAI_API_KEY=$(sec get OPENAI_API_KEY)
    if cmd.no_newline {
        print!("{}", response.value);
    } else {
        println!("{}", response.value);
    }

    Ok(())
}

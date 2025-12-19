//! F123-F126: Set command implementation
//!
//! Create or update a secret value.
//!
//! Features:
//! - F123: Create commands/set.rs file
//! - F124: Read value from stdin if --stdin flag is set
//! - F125: Send secret.set request with key and value
//! - F126: Display "Secret set successfully" message

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Read};

use crate::client::DaemonClient;

/// SetCommand arguments
pub struct SetCommand {
    pub key: String,
    pub value: Option<String>,
    pub stdin: bool,
    pub provider: Option<String>,
    pub environment: Option<String>,
    pub notes: Option<String>,
}

/// Response from secret.set
#[derive(Debug, Deserialize)]
struct SetResponse {
    name: String,
    status: String,
}

/// F123-F126: Handle the set command
///
/// This command sets a secret value by:
/// 1. F124: Reading value from stdin if --stdin flag is set
/// 2. F125: Sending secret.set request with key and value
/// 3. F126: Displaying "Secret set successfully" message
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments containing key, value, and options
///
/// # Returns
///
/// Returns Ok(()) on success, error if set fails
///
/// # Examples
///
/// ```bash
/// # Set with value argument
/// sec set OPENAI_API_KEY sk-abc123...
///
/// # Set from stdin (secure input)
/// echo "sk-abc123..." | sec set OPENAI_API_KEY --stdin
///
/// # Set with metadata
/// sec set STRIPE_KEY sk-test... --provider stripe --environment dev
/// ```
pub async fn handle_set(client: DaemonClient, cmd: SetCommand) -> Result<()> {
    // F124: Read value from stdin if --stdin flag is set
    let value = if cmd.stdin {
        // Read from stdin
        let mut buffer = String::new();
        io::stdin()
            .read_to_string(&mut buffer)
            .context("Failed to read value from stdin")?;

        // Trim trailing newline if present
        buffer.trim_end().to_string()
    } else if let Some(val) = cmd.value {
        // Use provided value
        val
    } else {
        anyhow::bail!(
            "No value provided. Either pass value as argument or use --stdin flag.\n\n\
            Usage:\n  \
              sec set {} <value>\n  \
              echo <value> | sec set {} --stdin",
            cmd.key,
            cmd.key
        );
    };

    // Validate value is not empty
    if value.is_empty() {
        anyhow::bail!("Value cannot be empty");
    }

    // F125: Send secret.set request with key and value
    let mut params = json!({
        "name": cmd.key,
        "value": value,
    });

    // Add optional metadata
    if let Some(provider) = cmd.provider {
        params["provider"] = json!(provider);
    }

    if let Some(environment) = cmd.environment {
        params["environment"] = json!(environment);
    }

    if let Some(notes) = cmd.notes {
        params["notes"] = json!(notes);
    }

    let response: SetResponse = client
        .request("secret.set", params)
        .await
        .context("Failed to set secret")?;

    // F126: Display "Secret set successfully" message
    println!("Secret set successfully");
    println!();
    println!("  Name:   {}", response.name);
    println!("  Status: {}", response.status);

    Ok(())
}

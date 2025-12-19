//! Rotate command implementation
//!
//! Rotate a secret's value while keeping history.
//!
//! Milestone 4: Secret Rotation

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// RotateCommand arguments
pub struct RotateCommand {
    pub key: String,
    pub new_value: Option<String>,
}

#[derive(Debug, Deserialize)]
struct RotateResponse {
    name: String,
    version: i64,
    status: String,
}

/// Handle the rotate command
///
/// Rotates a secret by:
/// 1. Getting new value (from argument or interactive prompt)
/// 2. Sending secret.rotate request to daemon
/// 3. Daemon stores new value and keeps previous version
pub async fn handle_rotate(client: DaemonClient, cmd: RotateCommand) -> Result<()> {
    // Get new value
    let new_value = if let Some(value) = cmd.new_value {
        value
    } else {
        // Interactive prompt
        print!("Enter new value for {}: ", cmd.key);
        io::stdout().flush()?;
        let value = rpassword::read_password().context("Failed to read value")?;

        if value.is_empty() {
            println!("Value cannot be empty.");
            return Ok(());
        }

        // Confirm
        print!("Confirm new value: ");
        io::stdout().flush()?;
        let confirm = rpassword::read_password().context("Failed to read confirmation")?;

        if value != confirm {
            println!("Values do not match.");
            return Ok(());
        }

        value
    };

    println!("Rotating secret '{}'...", cmd.key);

    let response: RotateResponse = client
        .request(
            "secret.rotate",
            json!({
                "name": cmd.key,
                "value": new_value
            }),
        )
        .await
        .context("Failed to rotate secret")?;

    println!();
    println!("✓ Secret '{}' rotated", response.name);
    println!("  Version: {}", response.version);
    println!("  Status:  {}", response.status);
    println!();
    println!("Previous version is preserved and can be rolled back.");

    Ok(())
}

//! Grant command implementation
//!
//! Grant an application access to a specific secret.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// GrantCommand arguments
pub struct GrantCommand {
    pub app: String,
    pub key: String,
}

#[derive(Debug, Deserialize)]
struct GrantResponse {
    app_id: String,
    secret_name: String,
    status: String,
}

/// Handle the grant command
///
/// Grants application access to a secret by:
/// 1. Sending app.authorize request to daemon
/// 2. Displaying success/failure message
pub async fn handle_grant(client: DaemonClient, cmd: GrantCommand) -> Result<()> {
    let response: GrantResponse = client
        .request(
            "app.authorize",
            json!({
                "app_id": cmd.app,
                "secret_name": cmd.key
            }),
        )
        .await
        .context("Failed to grant permission")?;

    println!(
        "✓ Granted '{}' access to secret '{}'",
        response.app_id, response.secret_name
    );
    println!("  Status: {}", response.status);

    Ok(())
}

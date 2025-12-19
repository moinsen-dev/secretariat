//! Revoke command implementation
//!
//! Revoke an application's access to a specific secret.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// RevokeCommand arguments
pub struct RevokeCommand {
    pub app: String,
    pub key: String,
}

#[derive(Debug, Deserialize)]
struct RevokeResponse {
    app_id: String,
    secret_name: String,
    status: String,
}

/// Handle the revoke command
///
/// Revokes application access to a secret by:
/// 1. Sending app.revoke request to daemon
/// 2. Displaying success/failure message
pub async fn handle_revoke(client: DaemonClient, cmd: RevokeCommand) -> Result<()> {
    let response: RevokeResponse = client
        .request(
            "app.revoke",
            json!({
                "app_id": cmd.app,
                "secret_name": cmd.key
            }),
        )
        .await
        .context("Failed to revoke permission")?;

    println!(
        "✓ Revoked '{}' access to secret '{}'",
        response.app_id, response.secret_name
    );
    println!("  Status: {}", response.status);

    Ok(())
}

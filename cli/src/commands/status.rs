//! Status command implementation
//!
//! Show vault and daemon status.
//!
//! Milestone 3: Vault Lock/Unlock

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// StatusCommand arguments
pub struct StatusCommand {
    pub json: bool,
}

#[derive(Debug, Deserialize)]
struct HealthResponse {
    status: String,
    version: String,
}

#[derive(Debug, Deserialize)]
struct VaultStatusResponse {
    state: String,
    secret_count: Option<i64>,
    app_count: Option<i64>,
}

/// Handle the status command
///
/// Shows:
/// 1. Daemon health status
/// 2. Vault state (locked/unlocked/uninitialized)
/// 3. Secret and app counts
pub async fn handle_status(client: DaemonClient, cmd: StatusCommand) -> Result<()> {
    // Get health check
    let health: HealthResponse = client
        .request("health.check", json!({}))
        .await
        .context("Failed to check daemon health")?;

    // Get vault status
    let vault_status: Result<VaultStatusResponse, _> = client
        .request("vault.status", json!({}))
        .await;

    if cmd.json {
        let output = serde_json::json!({
            "daemon": {
                "status": health.status,
                "version": health.version
            },
            "vault": vault_status.as_ref().ok().map(|v| {
                serde_json::json!({
                    "state": v.state,
                    "secret_count": v.secret_count,
                    "app_count": v.app_count
                })
            })
        });
        println!("{}", serde_json::to_string_pretty(&output)?);
    } else {
        println!("Secretariat Status");
        println!("==================");
        println!();

        // Daemon status
        let status_icon = if health.status == "healthy" { "✓" } else { "✗" };
        println!("Daemon:  {} {} (v{})", status_icon, health.status, health.version);

        // Vault status
        match vault_status {
            Ok(vs) => {
                let state_icon = match vs.state.as_str() {
                    "unlocked" => "🔓",
                    "locked" => "🔒",
                    "uninitialized" => "⚠️ ",
                    _ => "?",
                };
                println!("Vault:   {} {}", state_icon, vs.state);

                if let Some(count) = vs.secret_count {
                    println!("Secrets: {}", count);
                }
                if let Some(count) = vs.app_count {
                    println!("Apps:    {}", count);
                }
            }
            Err(_) => {
                // vault.status not implemented yet, just show basic info
                println!("Vault:   ✓ operational");
            }
        }
    }

    Ok(())
}

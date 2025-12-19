//! Audit command implementation
//!
//! View access audit log entries.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::client::DaemonClient;

/// AuditCommand arguments
pub struct AuditCommand {
    pub app: Option<String>,
    pub secret: Option<String>,
    pub limit: usize,
    pub json: bool,
}

/// Audit log entry from daemon
#[derive(Debug, Deserialize, Serialize)]
struct AuditEntry {
    id: i64,
    app_id: String,
    secret_name: String,
    action: String,
    success: bool,
    details: Option<String>,
    timestamp: String,
}

#[derive(Debug, Deserialize)]
struct AuditResponse {
    entries: Vec<AuditEntry>,
}

/// Handle the audit command
///
/// Queries audit log by:
/// 1. Sending audit.log request to daemon with optional filters
/// 2. Parsing response as Vec<AuditEntry>
/// 3. Formatting as ASCII table or JSON
pub async fn handle_audit(client: DaemonClient, cmd: AuditCommand) -> Result<()> {
    let mut params = json!({
        "limit": cmd.limit
    });

    if let Some(app) = &cmd.app {
        params["app_id"] = json!(app);
    }

    // Note: secret filter may need to be added to daemon if not supported
    let response: AuditResponse = client
        .request("audit.log", params)
        .await
        .context("Failed to query audit log")?;

    // Apply client-side secret filter if specified
    let entries: Vec<_> = if let Some(secret) = &cmd.secret {
        response
            .entries
            .into_iter()
            .filter(|e| e.secret_name == *secret)
            .collect()
    } else {
        response.entries
    };

    if cmd.json {
        let json_output = serde_json::to_string_pretty(&entries)
            .context("Failed to serialize audit log to JSON")?;
        println!("{}", json_output);
    } else {
        if entries.is_empty() {
            println!("No audit entries found.");
            if cmd.app.is_some() || cmd.secret.is_some() {
                println!("\nTry removing filters to see all entries.");
            }
        } else {
            // Find max widths for columns
            let max_app_width = entries
                .iter()
                .map(|e| e.app_id.len().min(20))
                .max()
                .unwrap_or(12)
                .max(12);

            let max_secret_width = entries
                .iter()
                .map(|e| e.secret_name.len().min(25))
                .max()
                .unwrap_or(15)
                .max(15);

            let action_width = 8;
            let status_width = 7;
            let timestamp_width = 19;

            // Print header
            println!(
                "{:<ts_width$}  {:<app_width$}  {:<secret_width$}  {:<action_width$}  {:>status_width$}",
                "TIMESTAMP",
                "APPLICATION",
                "SECRET",
                "ACTION",
                "STATUS",
                ts_width = timestamp_width,
                app_width = max_app_width,
                secret_width = max_secret_width,
                action_width = action_width,
                status_width = status_width
            );

            // Print separator
            let total_width = timestamp_width + max_app_width + max_secret_width + action_width + status_width + 8;
            println!("{}", "-".repeat(total_width));

            // Print entries
            for entry in &entries {
                let app_display = if entry.app_id.len() > 20 {
                    format!("{}...", &entry.app_id[..17])
                } else {
                    entry.app_id.clone()
                };

                let secret_display = if entry.secret_name.len() > 25 {
                    format!("{}...", &entry.secret_name[..22])
                } else {
                    entry.secret_name.clone()
                };

                let status = if entry.success { "OK" } else { "DENIED" };

                println!(
                    "{:<ts_width$}  {:<app_width$}  {:<secret_width$}  {:<action_width$}  {:>status_width$}",
                    entry.timestamp,
                    app_display,
                    secret_display,
                    entry.action,
                    status,
                    ts_width = timestamp_width,
                    app_width = max_app_width,
                    secret_width = max_secret_width,
                    action_width = action_width,
                    status_width = status_width
                );
            }

            println!();
            println!("Total: {} entries (limit: {})", entries.len(), cmd.limit);
        }
    }

    Ok(())
}

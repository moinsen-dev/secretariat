//! Apps command implementation
//!
//! List all registered applications in the vault.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::client::DaemonClient;

/// AppsCommand arguments
pub struct AppsCommand {
    pub json: bool,
}

/// Application record from daemon
#[derive(Debug, Deserialize, Serialize)]
struct ApplicationRecord {
    id: String,
    name: String,
    path: Option<String>,
    bundle_id: Option<String>,
    fingerprint: Option<String>,
    registered_at: String,
    last_access: Option<String>,
    permission_count: i64,
}

#[derive(Debug, Deserialize)]
struct AppsResponse {
    apps: Vec<ApplicationRecord>,
}

/// Handle the apps command
///
/// Lists all registered applications by:
/// 1. Sending app.list request to daemon
/// 2. Parsing response as Vec<ApplicationRecord>
/// 3. Formatting as ASCII table or JSON
pub async fn handle_apps(client: DaemonClient, cmd: AppsCommand) -> Result<()> {
    let response: AppsResponse = client
        .request("app.list", json!({}))
        .await
        .context("Failed to list applications")?;

    if cmd.json {
        let json_output = serde_json::to_string_pretty(&response.apps)
            .context("Failed to serialize apps to JSON")?;
        println!("{}", json_output);
    } else {
        if response.apps.is_empty() {
            println!("No applications registered.");
            println!("\nApplications are registered automatically when they request secret access.");
        } else {
            // Find max widths for columns
            let max_name_width = response
                .apps
                .iter()
                .map(|a| a.name.len())
                .max()
                .unwrap_or(20)
                .max(20);

            let max_fingerprint_width = 12; // Show first 12 chars of fingerprint
            let permissions_width = 11; // "PERMISSIONS"
            let registered_width = 19; // "YYYY-MM-DD HH:MM:SS"

            // Print header
            println!(
                "{:<name_width$}  {:<fp_width$}  {:>perm_width$}  {:<reg_width$}",
                "APPLICATION",
                "FINGERPRINT",
                "PERMISSIONS",
                "REGISTERED",
                name_width = max_name_width,
                fp_width = max_fingerprint_width,
                perm_width = permissions_width,
                reg_width = registered_width
            );

            // Print separator line
            let total_width = max_name_width + max_fingerprint_width + permissions_width + registered_width + 6;
            println!("{}", "-".repeat(total_width));

            // Print apps
            for app in &response.apps {
                let fingerprint = app
                    .fingerprint
                    .as_deref()
                    .map(|f| if f.len() > 12 { &f[..12] } else { f })
                    .unwrap_or("-");

                println!(
                    "{:<name_width$}  {:<fp_width$}  {:>perm_width$}  {:<reg_width$}",
                    app.name,
                    fingerprint,
                    app.permission_count,
                    app.registered_at,
                    name_width = max_name_width,
                    fp_width = max_fingerprint_width,
                    perm_width = permissions_width,
                    reg_width = registered_width
                );
            }

            println!();
            println!("Total: {} application(s)", response.apps.len());
        }
    }

    Ok(())
}

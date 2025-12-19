//! Explain command implementation
//!
//! Show what secrets an application has access to.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::client::DaemonClient;

/// ExplainCommand arguments
pub struct ExplainCommand {
    pub app: String,
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

#[derive(Debug, Deserialize)]
struct AuditEntry {
    app_id: String,
    secret_name: String,
    action: String,
    success: bool,
    timestamp: String,
}

#[derive(Debug, Deserialize)]
struct AuditResponse {
    entries: Vec<AuditEntry>,
}

/// Handle the explain command
///
/// Shows what secrets an application would receive by:
/// 1. Fetching app details from app.list
/// 2. Querying audit log to find which secrets the app has accessed
/// 3. Displaying a summary of the app's permissions and access patterns
pub async fn handle_explain(client: DaemonClient, cmd: ExplainCommand) -> Result<()> {
    // First, get all apps to find the matching one
    let apps_response: AppsResponse = client
        .request("app.list", json!({}))
        .await
        .context("Failed to list applications")?;

    // Find the app by name or fingerprint
    let app = apps_response
        .apps
        .iter()
        .find(|a| {
            a.name.to_lowercase() == cmd.app.to_lowercase()
                || a.fingerprint
                    .as_ref()
                    .map(|f| f.starts_with(&cmd.app))
                    .unwrap_or(false)
                || a.id == cmd.app
        });

    match app {
        Some(app) => {
            println!("Application: {}", app.name);
            if let Some(path) = &app.path {
                println!("Path: {}", path);
            }
            if let Some(bundle_id) = &app.bundle_id {
                println!("Bundle ID: {}", bundle_id);
            }
            if let Some(fingerprint) = &app.fingerprint {
                println!("Fingerprint: {}", fingerprint);
            }
            println!("Registered: {}", app.registered_at);
            if let Some(last_access) = &app.last_access {
                println!("Last Access: {}", last_access);
            }
            println!();
            println!("Permissions: {} secret(s)", app.permission_count);

            // Get audit log for this app to show which secrets it accesses
            if app.permission_count > 0 {
                let app_id = app.fingerprint.as_ref().unwrap_or(&app.id);
                let audit_response: Result<AuditResponse, _> = client
                    .request(
                        "audit.log",
                        json!({
                            "app_id": app_id,
                            "limit": 100
                        }),
                    )
                    .await;

                if let Ok(audit) = audit_response {
                    // Group by secret name and get unique secrets
                    let mut secrets: Vec<&str> = audit
                        .entries
                        .iter()
                        .filter(|e| e.action == "authorize" || e.action == "get")
                        .map(|e| e.secret_name.as_str())
                        .collect();
                    secrets.sort();
                    secrets.dedup();

                    if !secrets.is_empty() {
                        println!();
                        println!("Authorized Secrets:");
                        for secret in secrets {
                            println!("  • {}", secret);
                        }
                    }

                    // Show recent access summary
                    let recent_access: Vec<_> = audit
                        .entries
                        .iter()
                        .filter(|e| e.action == "get")
                        .take(5)
                        .collect();

                    if !recent_access.is_empty() {
                        println!();
                        println!("Recent Access:");
                        for entry in recent_access {
                            let status = if entry.success { "✓" } else { "✗" };
                            println!(
                                "  {} {} - {}",
                                status, entry.secret_name, entry.timestamp
                            );
                        }
                    }
                }
            } else {
                println!();
                println!("This application has no permissions granted.");
                println!("Use: sec grant {} <secret_key>", app.name);
            }
        }
        None => {
            println!("Application '{}' not found.", cmd.app);
            println!();
            println!("Use 'sec apps' to list registered applications.");
        }
    }

    Ok(())
}

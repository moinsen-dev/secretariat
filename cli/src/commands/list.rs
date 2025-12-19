//! F114-F118: List command implementation
//!
//! List all secrets stored in the vault.
//!
//! Features:
//! - F114: Create commands/list.rs file
//! - F115: Send secret.list request to daemon
//! - F116: Parse response as Vec<SecretMetadata>
//! - F117: Format as ASCII table with name, provider, created columns
//! - F118: Implement --json flag to output raw JSON

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::client::DaemonClient;

/// ListCommand arguments
pub struct ListCommand {
    pub json: bool,
    pub provider: Option<String>,
    pub environment: Option<String>,
}

/// F116: SecretMetadata matches daemon's storage::SecretMetadata
#[derive(Debug, Deserialize, Serialize)]
struct SecretMetadata {
    id: String,
    name: String,
    provider: Option<String>,
    environment: String,
    created_at: String,
}

#[derive(Debug, Deserialize)]
struct ListResponse {
    secrets: Vec<SecretMetadata>,
}

/// F114-F118: Handle the list command
///
/// This command lists all secrets by:
/// 1. Sending secret.list request to daemon with optional filters
/// 2. F116: Parsing response as Vec<SecretMetadata>
/// 3. F117: Formatting as ASCII table with name, provider, created columns
/// 4. F118: Supporting --json flag to output raw JSON
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments
///
/// # Returns
///
/// Returns Ok(()) on success, error if list fails
pub async fn handle_list(client: DaemonClient, cmd: ListCommand) -> Result<()> {
    // F115: Build request params with optional filters
    let mut params = json!({});

    if let Some(provider) = &cmd.provider {
        params["provider"] = json!(provider);
    }

    if let Some(environment) = &cmd.environment {
        params["environment"] = json!(environment);
    }

    // F115-F116: Send secret.list request to daemon and parse as Vec<SecretMetadata>
    let response: ListResponse = client
        .request("secret.list", params)
        .await
        .context("Failed to list secrets")?;

    // F118: Display results - JSON output if --json flag is set
    if cmd.json {
        let json_output = serde_json::to_string_pretty(&response.secrets)
            .context("Failed to serialize secrets to JSON")?;
        println!("{}", json_output);
    } else {
        // F117: Format as ASCII table with name, provider, created columns
        if response.secrets.is_empty() {
            println!("No secrets found.");
            println!("\nTry: sec set MY_API_KEY <value>");
        } else {
            // Find max width for name column
            let max_name_width = response
                .secrets
                .iter()
                .map(|s| s.name.len())
                .max()
                .unwrap_or(20)
                .max(20);

            let max_provider_width = 15;
            let created_width = 19; // "YYYY-MM-DD HH:MM:SS" format

            // Print header
            println!(
                "{:<name_width$}  {:<provider_width$}  {:<created_width$}",
                "NAME",
                "PROVIDER",
                "CREATED",
                name_width = max_name_width,
                provider_width = max_provider_width,
                created_width = created_width
            );

            // Print separator line
            let total_width = max_name_width + max_provider_width + created_width + 4;
            println!("{}", "-".repeat(total_width));

            // Print secrets
            for secret in &response.secrets {
                let provider = secret
                    .provider
                    .as_deref()
                    .unwrap_or("-");

                println!(
                    "{:<name_width$}  {:<provider_width$}  {:<created_width$}",
                    secret.name,
                    provider,
                    secret.created_at,
                    name_width = max_name_width,
                    provider_width = max_provider_width,
                    created_width = created_width
                );
            }

            println!();
            println!("Total: {} secret(s)", response.secrets.len());
        }
    }

    Ok(())
}

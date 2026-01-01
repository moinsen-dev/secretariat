//! Environment management commands
//!
//! Manage environment contexts (dev, staging, prod) for secrets.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::fs;
use std::path::PathBuf;

use crate::client::DaemonClient;

/// Arguments for the env command
pub struct EnvCommand {
    /// Subcommand to execute
    pub action: EnvAction,
}

/// Environment subcommands
pub enum EnvAction {
    /// List all environments
    List,
    /// Show current environment
    Current,
    /// Set current environment
    Set { name: String },
    /// Show environment config path
    Config,
}

#[derive(Debug, Deserialize)]
struct StatusResponse {
    environments: Option<Vec<String>>,
}

/// Get the path to the environment config file
fn get_env_config_path() -> PathBuf {
    let home = dirs::home_dir().expect("Could not find home directory");
    home.join(".config")
        .join("secretariat")
        .join("environment")
}

/// Read the current environment from config file
fn read_current_env() -> Option<String> {
    let path = get_env_config_path();
    fs::read_to_string(&path).ok().map(|s| s.trim().to_string())
}

/// Write the current environment to config file
fn write_current_env(env: &str) -> Result<()> {
    let path = get_env_config_path();

    // Create parent directories if they don't exist
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).context("Failed to create config directory")?;
    }

    fs::write(&path, env).context("Failed to write environment config")?;
    Ok(())
}

/// Handle the env command
pub async fn handle_env(client: DaemonClient, cmd: EnvCommand) -> Result<()> {
    match cmd.action {
        EnvAction::List => {
            // Get vault status which includes environments
            let response: StatusResponse = client
                .request("vault.status", json!({}))
                .await
                .context("Failed to get vault status")?;

            println!("Available environments:");
            println!();

            let current = read_current_env().unwrap_or_else(|| "default".to_string());

            if let Some(environments) = response.environments {
                if environments.is_empty() {
                    println!("  (no secrets yet - environments are created when you add secrets)");
                } else {
                    for env in &environments {
                        if env == &current {
                            println!("  * {} (current)", env);
                        } else {
                            println!("    {}", env);
                        }
                    }
                }
            } else {
                println!("  default");
            }

            println!();
            println!("Use 'sec env set <name>' to switch environments.");
            println!("Use 'sec set KEY VALUE --environment <name>' to add secrets to a specific environment.");

            Ok(())
        }

        EnvAction::Current => {
            let current = read_current_env().unwrap_or_else(|| "default".to_string());
            println!("{}", current);
            Ok(())
        }

        EnvAction::Set { name } => {
            // Validate environment name
            let valid_envs = ["default", "dev", "development", "staging", "stage", "prod", "production", "test", "local"];

            if !valid_envs.contains(&name.as_str()) && !name.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-') {
                anyhow::bail!(
                    "Invalid environment name: '{}'\n\
                     Environment names should be alphanumeric with underscores or hyphens.\n\
                     Common values: default, dev, staging, prod, test, local",
                    name
                );
            }

            write_current_env(&name)?;

            println!("Environment set to: {}", name);
            println!();
            println!("Future 'sec get' commands will use this environment by default.");
            println!("You can override with: sec get KEY --environment <other>");

            Ok(())
        }

        EnvAction::Config => {
            let path = get_env_config_path();
            println!("{}", path.display());
            Ok(())
        }
    }
}

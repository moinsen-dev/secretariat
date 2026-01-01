//! Agent command - AI agent access control
//!
//! Manage which AI coding assistants (Claude Code, Cursor, Copilot, etc.)
//! can access which secrets.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

use crate::client::DaemonClient;

/// Arguments for the agent command
pub struct AgentCommand {
    /// Subcommand to execute
    pub action: AgentAction,
}

/// Agent subcommands
pub enum AgentAction {
    /// List all registered agents
    List { json: bool },
    /// Register a new agent
    Register { name: String, agent_type: Option<String> },
    /// Grant agent access to a secret
    Grant { agent: String, secret: String, environment: Option<String> },
    /// Revoke agent access to a secret
    Revoke { agent: String, secret: String },
    /// Revoke ALL permissions for an agent (emergency)
    RevokeAll { agent: String, force: bool },
    /// Show what secrets an agent can access
    Explain { agent: String },
}

#[derive(Debug, Deserialize, serde::Serialize)]
struct AgentInfo {
    name: String,
    agent_type: String,
    #[allow(dead_code)]
    created_at: String,
    permission_count: i64,
}

#[derive(Debug, Deserialize)]
struct AgentListResponse {
    agents: Vec<AgentInfo>,
}

#[derive(Debug, Deserialize)]
struct AgentRegisterResponse {
    agent_id: String,
    name: String,
    agent_type: String,
}

#[derive(Debug, Deserialize)]
struct AgentPermissionResponse {
    agent_id: String,
    secret_name: String,
    status: String,
}

#[derive(Debug, Deserialize)]
struct AgentRevokeAllResponse {
    #[allow(dead_code)]
    agent_id: String,
    revoked_count: i64,
}

#[derive(Debug, Deserialize)]
struct PermissionEntry {
    secret: String,
    environment: String,
}

#[derive(Debug, Deserialize)]
struct AgentExplainResponse {
    agent_id: String,
    permissions: Vec<PermissionEntry>,
}

/// Handle the agent command
pub async fn handle_agent(client: DaemonClient, cmd: AgentCommand) -> Result<()> {
    match cmd.action {
        AgentAction::List { json: json_output } => {
            let response: AgentListResponse = client
                .request("agent.list", json!({}))
                .await
                .context("Failed to list agents")?;

            if json_output {
                println!("{}", serde_json::to_string_pretty(&response.agents)?);
            } else if response.agents.is_empty() {
                println!("No AI agents registered yet.");
                println!();
                println!("Register an agent with:");
                println!("  sec agent register <name>");
                println!();
                println!("Example:");
                println!("  sec agent register claude-code");
                println!("  sec agent register cursor --type ai-assistant");
            } else {
                println!("Registered AI Agents:");
                println!();
                println!("{:<20} {:<15} {:<10}", "NAME", "TYPE", "SECRETS");
                println!("{}", "-".repeat(45));
                for agent in &response.agents {
                    println!(
                        "{:<20} {:<15} {:<10}",
                        agent.name, agent.agent_type, agent.permission_count
                    );
                }
            }
            Ok(())
        }

        AgentAction::Register { name, agent_type } => {
            let agent_type = agent_type.unwrap_or_else(|| "ai-assistant".to_string());

            let response: AgentRegisterResponse = client
                .request("agent.register", json!({
                    "name": name,
                    "type": agent_type,
                }))
                .await
                .context("Failed to register agent")?;

            println!("Agent registered successfully");
            println!();
            println!("  ID:   {}", response.agent_id);
            println!("  Name: {}", response.name);
            println!("  Type: {}", response.agent_type);
            println!();
            println!("Grant access with:");
            println!("  sec agent grant {} <SECRET_NAME>", response.name);

            Ok(())
        }

        AgentAction::Grant { agent, secret, environment } => {
            let mut params = json!({
                "agent_id": agent,
                "secret_name": secret,
            });

            if let Some(env) = &environment {
                params["environment"] = json!(env);
            }

            let response: AgentPermissionResponse = client
                .request("agent.grant", params)
                .await
                .context("Failed to grant agent access")?;

            println!("Access granted");
            println!();
            println!("  Agent:  {}", response.agent_id);
            println!("  Secret: {}", response.secret_name);
            println!("  Status: {}", response.status);

            if let Some(env) = environment {
                println!("  Env:    {}", env);
            }

            Ok(())
        }

        AgentAction::Revoke { agent, secret } => {
            let response: AgentPermissionResponse = client
                .request("agent.revoke", json!({
                    "agent_id": agent,
                    "secret_name": secret,
                }))
                .await
                .context("Failed to revoke agent access")?;

            println!("Access revoked");
            println!();
            println!("  Agent:  {}", response.agent_id);
            println!("  Secret: {}", response.secret_name);
            println!("  Status: {}", response.status);

            Ok(())
        }

        AgentAction::RevokeAll { agent, force } => {
            if !force {
                use std::io::{self, Write};

                println!();
                println!("WARNING: This will revoke ALL secret access for agent '{}'", agent);
                println!();
                print!("Type the agent name to confirm: ");
                io::stdout().flush()?;

                let mut input = String::new();
                io::stdin().read_line(&mut input)?;

                if input.trim() != agent {
                    println!("Aborted. No changes made.");
                    return Ok(());
                }
            }

            let response: AgentRevokeAllResponse = client
                .request("agent.revoke_all", json!({
                    "agent_id": agent,
                }))
                .await
                .context("Failed to revoke all agent access")?;

            println!("All access revoked");
            println!();
            println!("  Agent: {}", agent);
            println!("  Permissions revoked: {}", response.revoked_count);

            Ok(())
        }

        AgentAction::Explain { agent } => {
            let response: AgentExplainResponse = client
                .request("agent.explain", json!({
                    "agent_id": agent,
                }))
                .await
                .context("Failed to explain agent permissions")?;

            if response.permissions.is_empty() {
                println!("Agent '{}' has no secret access.", agent);
                println!();
                println!("Grant access with:");
                println!("  sec agent grant {} <SECRET_NAME>", agent);
            } else {
                println!("Agent '{}' can access:", response.agent_id);
                println!();
                println!("{:<30} {:<15}", "SECRET", "ENVIRONMENT");
                println!("{}", "-".repeat(45));
                for perm in &response.permissions {
                    println!("{:<30} {:<15}", perm.secret, perm.environment);
                }
            }

            Ok(())
        }
    }
}

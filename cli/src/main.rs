//! Secretariat CLI - Command-line interface for secret management
//!
//! Wave 16: F087-F100 - CLI Foundation
//! Wave 17: F101-F115 - CLI Client & Commands
//!
//! This CLI provides a developer-friendly interface to the Secretariat daemon
//! for managing secrets, applications, and access control.

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};

mod client;
mod commands;

use client::DaemonClient;

// F088-F089: Cli struct with Clap derive macro and Commands enum
/// Secretariat - Local-first secrets manager
///
/// Manage API keys, tokens, and secrets securely without .env files.
#[derive(Parser)]
#[command(name = "sec")]
#[command(author = "Secretariat Team")]
#[command(version = "0.1.0")]
#[command(about = "Local-first secrets manager", long_about = None)]
struct Cli {
    /// Command to execute
    #[command(subcommand)]
    command: Commands,
}

// F090: Commands enum with variants for all 17 commands
/// Available commands
#[derive(Subcommand)]
enum Commands {
    /// Initialize vault (first run)
    Init(InitCommand),

    /// List all secrets
    List(ListCommand),

    /// Get secret value
    Get(GetCommand),

    /// Set secret value
    Set(SetCommand),

    /// Delete secret
    Delete(DeleteCommand),

    /// Rotate secret value
    Rotate(RotateCommand),

    /// Manage environments (dev, staging, prod)
    Env(EnvCommand),

    /// Grant app access to secret
    Grant(GrantCommand),

    /// Revoke app access
    Revoke(RevokeCommand),

    /// List registered apps
    Apps(AppsCommand),

    /// View access log
    Audit(AuditCommand),

    /// Manage AI agent access control (Claude Code, Cursor, etc.)
    Agent(AgentCommandStruct),

    /// Show what secrets app would receive
    Explain(ExplainCommand),

    /// Import from .env file
    Import(ImportCommand),

    /// Scan directories for .env files (discovery/audit)
    Scan(ScanCommand),

    /// Cleanup old .env files
    Cleanup(CleanupCommand),

    /// Show daemon status
    Status(StatusCommand),

    /// Unlock vault (Touch ID/password)
    Unlock(UnlockCommand),

    /// Lock vault
    Lock(LockCommand),

    /// Change master password
    ChangePassword(ChangePasswordCommand),

    /// Emergency kill-switch - revoke ALL access immediately
    Panic(PanicCommand),

    /// Guided provider onboarding (OpenAI, Anthropic, Stripe, etc.)
    Provider(ProviderCommandStruct),

    /// Cleanup expired ephemeral secrets
    CleanupExpired(CleanupExpiredCommand),

    /// List secrets expiring soon
    Expiring(ExpiringCommand),

    /// Show secret version history
    History(HistoryCommand),

    /// Rollback secret to previous version
    Rollback(RollbackCommand),

    /// Show secrets needing rotation
    RotationReminders(RotationRemindersCommand),

    /// Show version
    Version(VersionCommand),
}

// F091: InitCommand struct for sec init
/// Initialize the secrets vault
#[derive(Parser)]
struct InitCommand {
    /// Skip interactive prompts and use defaults
    #[arg(short, long)]
    yes: bool,
}

// F092: ListCommand struct for sec list with --json flag
/// List all secrets
#[derive(Parser)]
struct ListCommand {
    /// Output in JSON format
    #[arg(long)]
    json: bool,

    /// Filter by provider (e.g., openai, stripe)
    #[arg(short, long)]
    provider: Option<String>,

    /// Filter by environment
    #[arg(short, long)]
    environment: Option<String>,
}

// F093: GetCommand struct for sec get with key: String argument
/// Get secret value
#[derive(Parser)]
struct GetCommand {
    /// Secret key to retrieve
    key: String,

    /// Don't print newline after value (for scripting)
    #[arg(short = 'n', long)]
    no_newline: bool,
}

// F094: SetCommand struct for sec set with key, value, --stdin flag
/// Set secret value
#[derive(Parser)]
struct SetCommand {
    /// Secret key
    key: String,

    /// Secret value (omit to read from stdin)
    value: Option<String>,

    /// Read value from stdin
    #[arg(long)]
    stdin: bool,

    /// Provider name (e.g., openai, stripe)
    #[arg(short, long)]
    provider: Option<String>,

    /// Environment (default: 'default')
    #[arg(short, long)]
    environment: Option<String>,

    /// Notes about this secret
    #[arg(short, long)]
    notes: Option<String>,

    /// Time-to-live in seconds (ephemeral secret)
    #[arg(long)]
    ttl: Option<u64>,
}

// F095: DeleteCommand struct with key and --force flag
/// Delete secret
#[derive(Parser)]
struct DeleteCommand {
    /// Secret key to delete
    key: String,

    /// Skip confirmation prompt
    #[arg(short, long)]
    force: bool,
}

/// Rotate secret value
#[derive(Parser)]
struct RotateCommand {
    /// Secret key to rotate
    key: String,

    /// New value (omit for interactive prompt)
    new_value: Option<String>,
}

/// Manage environments (dev, staging, prod)
#[derive(Parser)]
struct EnvCommand {
    /// Subcommand
    #[command(subcommand)]
    action: EnvAction,
}

#[derive(clap::Subcommand)]
enum EnvAction {
    /// List all environments with secrets
    List,
    /// Show current environment
    Current,
    /// Set current environment
    Set {
        /// Environment name (e.g., dev, staging, prod)
        name: String,
    },
    /// Show environment config path
    Config,
}

/// Grant app access to secret
#[derive(Parser)]
struct GrantCommand {
    /// Application name or ID
    app: String,

    /// Secret key to grant access to
    key: String,
}

/// Revoke app access
#[derive(Parser)]
struct RevokeCommand {
    /// Application name or ID
    app: String,

    /// Secret key to revoke access from
    key: String,
}

/// List registered apps
#[derive(Parser)]
struct AppsCommand {
    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// View access log
#[derive(Parser)]
struct AuditCommand {
    /// Filter by application
    #[arg(short, long)]
    app: Option<String>,

    /// Filter by secret
    #[arg(short, long)]
    secret: Option<String>,

    /// Limit number of entries
    #[arg(short, long, default_value = "50")]
    limit: usize,

    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// Manage AI agent access control
#[derive(Parser)]
struct AgentCommandStruct {
    /// Subcommand
    #[command(subcommand)]
    action: AgentActionEnum,
}

#[derive(clap::Subcommand)]
enum AgentActionEnum {
    /// List all registered AI agents
    List {
        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },
    /// Register a new AI agent
    Register {
        /// Agent name (e.g., claude-code, cursor)
        name: String,
        /// Agent type (default: ai-assistant)
        #[arg(long, name = "type")]
        agent_type: Option<String>,
    },
    /// Grant agent access to a secret
    Grant {
        /// Agent name or ID
        agent: String,
        /// Secret name to grant access to
        secret: String,
        /// Environment (default: all environments agent has access to)
        #[arg(short, long)]
        environment: Option<String>,
    },
    /// Revoke agent access to a secret
    Revoke {
        /// Agent name or ID
        agent: String,
        /// Secret name to revoke access from
        secret: String,
    },
    /// Revoke ALL permissions for an agent (emergency)
    RevokeAll {
        /// Agent name or ID
        agent: String,
        /// Skip confirmation prompt
        #[arg(short, long)]
        force: bool,
    },
    /// Show what secrets an agent can access
    Explain {
        /// Agent name or ID
        agent: String,
    },
}

/// Show what secrets app would receive
#[derive(Parser)]
struct ExplainCommand {
    /// Application name or ID
    app: String,
}

// F096: ImportCommand struct with file path and --scan flag
/// Import from .env file
#[derive(Parser)]
struct ImportCommand {
    /// Path to .env file or directory to scan
    path: String,

    /// Scan directory for all .env files
    #[arg(long)]
    scan: bool,

    /// Skip confirmation prompts
    #[arg(short, long)]
    yes: bool,
}

/// Cleanup old .env files
#[derive(Parser)]
struct CleanupCommand {
    /// Show what would be deleted without deleting
    #[arg(long)]
    dry_run: bool,

    /// Execute cleanup (delete files)
    #[arg(long)]
    execute: bool,
}

/// Scan directories for .env files (discovery/audit)
#[derive(Parser)]
struct ScanCommand {
    /// Directory to scan (default: current directory)
    #[arg(default_value = ".")]
    path: String,

    /// Output as JSON
    #[arg(long)]
    json: bool,

    /// Show only summary
    #[arg(long)]
    summary: bool,

    /// Show only duplicates
    #[arg(long)]
    duplicates: bool,

    /// Show only security issues (files not in .gitignore, tracked by git)
    #[arg(long)]
    security: bool,

    /// Filter by provider (e.g., openai, stripe)
    #[arg(long)]
    provider: Option<String>,

    /// Export results to JSON file
    #[arg(long)]
    export: Option<std::path::PathBuf>,

    /// Export results as HTML report
    #[arg(long)]
    html: Option<std::path::PathBuf>,

    /// Fix security issues by adding .env* to .gitignore files
    #[arg(long)]
    fix: bool,

    /// Dry run for fix (show what would be changed without modifying files)
    #[arg(long)]
    fix_dry_run: bool,

    /// Maximum depth to scan (default: 10)
    #[arg(long, default_value = "10")]
    max_depth: usize,
}

// F097: StatusCommand struct for sec status
/// Show daemon status
#[derive(Parser)]
struct StatusCommand {
    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// Unlock vault
#[derive(Parser)]
struct UnlockCommand {
    /// Use password instead of Touch ID
    #[arg(long)]
    password: bool,
}

/// Lock vault
#[derive(Parser)]
struct LockCommand {}

/// Change master password
#[derive(Parser)]
struct ChangePasswordCommand {}

/// Emergency kill-switch - revoke ALL access immediately
#[derive(Parser)]
struct PanicCommand {
    /// Skip confirmation prompt (dangerous!)
    #[arg(short, long)]
    force: bool,
}

/// Guided provider onboarding (OpenAI, Anthropic, Stripe, etc.)
#[derive(Parser)]
struct ProviderCommandStruct {
    #[command(subcommand)]
    action: ProviderActionEnum,
}

#[derive(Subcommand)]
enum ProviderActionEnum {
    /// List supported providers
    List {
        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },
    /// Show provider information
    Info {
        /// Provider name (e.g., openai, anthropic, stripe)
        name: String,
    },
    /// Start guided setup for a provider
    Add {
        /// Provider name (e.g., openai, anthropic, stripe)
        name: String,
        /// Environment to store secret in
        #[arg(short, long)]
        environment: Option<String>,
    },
}

/// Cleanup expired ephemeral secrets
#[derive(Parser)]
struct CleanupExpiredCommand {
    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// List secrets expiring soon
#[derive(Parser)]
struct ExpiringCommand {
    /// Time window in seconds (default: 3600 = 1 hour)
    #[arg(short, long, default_value = "3600")]
    within: u64,

    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// Show secret version history
#[derive(Parser)]
struct HistoryCommand {
    /// Secret name
    name: String,

    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// Rollback secret to previous version
#[derive(Parser)]
struct RollbackCommand {
    /// Secret name
    name: String,

    /// Skip confirmation prompt
    #[arg(short, long)]
    force: bool,
}

/// Show secrets needing rotation
#[derive(Parser)]
struct RotationRemindersCommand {
    /// Days since last rotation (default: 90)
    #[arg(short, long, default_value = "90")]
    days: u64,

    /// Output in JSON format
    #[arg(long)]
    json: bool,
}

/// Show version
#[derive(Parser)]
struct VersionCommand {
    /// Show verbose version info
    #[arg(short, long)]
    verbose: bool,
}

// F098: Implement main() function that matches command and dispatches
#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing for logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    // Parse CLI arguments
    let cli = Cli::parse();

    // Create daemon client
    let client = DaemonClient::new()?;

    // Dispatch to appropriate command handler
    match cli.command {
        Commands::Init(cmd) => handle_init(client, cmd).await,
        Commands::List(cmd) => handle_list(client, cmd).await,
        Commands::Get(cmd) => handle_get(client, cmd).await,
        Commands::Set(cmd) => handle_set(client, cmd).await,
        Commands::Delete(cmd) => handle_delete(client, cmd).await,
        Commands::Rotate(cmd) => handle_rotate(client, cmd).await,
        Commands::Env(cmd) => handle_env(client, cmd).await,
        Commands::Grant(cmd) => handle_grant(client, cmd).await,
        Commands::Revoke(cmd) => handle_revoke(client, cmd).await,
        Commands::Apps(cmd) => handle_apps(client, cmd).await,
        Commands::Audit(cmd) => handle_audit(client, cmd).await,
        Commands::Agent(cmd) => handle_agent(client, cmd).await,
        Commands::Explain(cmd) => handle_explain(client, cmd).await,
        Commands::Import(cmd) => handle_import(client, cmd).await,
        Commands::Scan(cmd) => handle_scan(cmd).await,
        Commands::Cleanup(cmd) => handle_cleanup(client, cmd).await,
        Commands::Status(cmd) => handle_status(client, cmd).await,
        Commands::Unlock(cmd) => handle_unlock(client, cmd).await,
        Commands::Lock(cmd) => handle_lock(client, cmd).await,
        Commands::ChangePassword(cmd) => handle_change_password(client, cmd).await,
        Commands::Panic(cmd) => handle_panic(client, cmd).await,
        Commands::Provider(cmd) => handle_provider(client, cmd).await,
        Commands::CleanupExpired(cmd) => handle_cleanup_expired(client, cmd).await,
        Commands::Expiring(cmd) => handle_expiring(client, cmd).await,
        Commands::History(cmd) => handle_history(client, cmd).await,
        Commands::Rollback(cmd) => handle_rollback(client, cmd).await,
        Commands::RotationReminders(cmd) => handle_rotation_reminders(client, cmd).await,
        Commands::Version(cmd) => handle_version(client, cmd).await,
    }
}

// Command handlers

// F109-F113: Init command - implemented in commands/init.rs
async fn handle_init(client: DaemonClient, cmd: InitCommand) -> Result<()> {
    let cmd_args = commands::init::InitCommand { yes: cmd.yes };
    commands::handle_init(client, cmd_args).await
}

// F114-F115: List command - implemented in commands/list.rs
async fn handle_list(client: DaemonClient, cmd: ListCommand) -> Result<()> {
    let cmd_args = commands::list::ListCommand {
        json: cmd.json,
        provider: cmd.provider,
        environment: cmd.environment,
    };
    commands::handle_list(client, cmd_args).await
}

// F119-F122: Get command - implemented in commands/get.rs
async fn handle_get(client: DaemonClient, cmd: GetCommand) -> Result<()> {
    let cmd_args = commands::get::GetCommand {
        key: cmd.key,
        no_newline: cmd.no_newline,
    };
    commands::handle_get(client, cmd_args).await
}

// F123-F126: Set command - implemented in commands/set.rs
async fn handle_set(client: DaemonClient, cmd: SetCommand) -> Result<()> {
    let cmd_args = commands::set::SetCommand {
        key: cmd.key,
        value: cmd.value,
        stdin: cmd.stdin,
        provider: cmd.provider,
        environment: cmd.environment,
        notes: cmd.notes,
        ttl: cmd.ttl,
    };
    commands::handle_set(client, cmd_args).await
}

// F127-F130: Delete command - implemented in commands/delete.rs
async fn handle_delete(client: DaemonClient, cmd: DeleteCommand) -> Result<()> {
    let cmd_args = commands::delete::DeleteCommand {
        key: cmd.key,
        force: cmd.force,
    };
    commands::handle_delete(client, cmd_args).await
}

async fn handle_rotate(client: DaemonClient, cmd: RotateCommand) -> Result<()> {
    let cmd_args = commands::rotate::RotateCommand {
        key: cmd.key,
        new_value: cmd.new_value,
    };
    commands::handle_rotate(client, cmd_args).await
}

async fn handle_env(client: DaemonClient, cmd: EnvCommand) -> Result<()> {
    let action = match cmd.action {
        EnvAction::List => commands::env::EnvAction::List,
        EnvAction::Current => commands::env::EnvAction::Current,
        EnvAction::Set { name } => commands::env::EnvAction::Set { name },
        EnvAction::Config => commands::env::EnvAction::Config,
    };
    let cmd_args = commands::env::EnvCommand { action };
    commands::handle_env(client, cmd_args).await
}

async fn handle_grant(client: DaemonClient, cmd: GrantCommand) -> Result<()> {
    let cmd_args = commands::grant::GrantCommand {
        app: cmd.app,
        key: cmd.key,
    };
    commands::handle_grant(client, cmd_args).await
}

async fn handle_revoke(client: DaemonClient, cmd: RevokeCommand) -> Result<()> {
    let cmd_args = commands::revoke::RevokeCommand {
        app: cmd.app,
        key: cmd.key,
    };
    commands::handle_revoke(client, cmd_args).await
}

async fn handle_apps(client: DaemonClient, cmd: AppsCommand) -> Result<()> {
    let cmd_args = commands::apps::AppsCommand {
        json: cmd.json,
    };
    commands::handle_apps(client, cmd_args).await
}

async fn handle_audit(client: DaemonClient, cmd: AuditCommand) -> Result<()> {
    let cmd_args = commands::audit::AuditCommand {
        app: cmd.app,
        secret: cmd.secret,
        limit: cmd.limit,
        json: cmd.json,
    };
    commands::handle_audit(client, cmd_args).await
}

async fn handle_agent(client: DaemonClient, cmd: AgentCommandStruct) -> Result<()> {
    let action = match cmd.action {
        AgentActionEnum::List { json } => commands::agent::AgentAction::List { json },
        AgentActionEnum::Register { name, agent_type } => {
            commands::agent::AgentAction::Register { name, agent_type }
        }
        AgentActionEnum::Grant { agent, secret, environment } => {
            commands::agent::AgentAction::Grant { agent, secret, environment }
        }
        AgentActionEnum::Revoke { agent, secret } => {
            commands::agent::AgentAction::Revoke { agent, secret }
        }
        AgentActionEnum::RevokeAll { agent, force } => {
            commands::agent::AgentAction::RevokeAll { agent, force }
        }
        AgentActionEnum::Explain { agent } => {
            commands::agent::AgentAction::Explain { agent }
        }
    };
    let cmd_args = commands::agent::AgentCommand { action };
    commands::handle_agent(client, cmd_args).await
}

async fn handle_explain(client: DaemonClient, cmd: ExplainCommand) -> Result<()> {
    let cmd_args = commands::explain::ExplainCommand {
        app: cmd.app,
    };
    commands::handle_explain(client, cmd_args).await
}

// F131-F134: Import command - implemented in commands/import.rs
async fn handle_import(client: DaemonClient, cmd: ImportCommand) -> Result<()> {
    let cmd_args = commands::import::ImportCommand {
        path: cmd.path,
        scan: cmd.scan,
        yes: cmd.yes,
    };
    commands::handle_import(client, cmd_args).await
}

async fn handle_scan(cmd: ScanCommand) -> Result<()> {
    let cmd_args = commands::scan::ScanCommand {
        path: cmd.path,
        json: cmd.json,
        summary: cmd.summary,
        duplicates: cmd.duplicates,
        security: cmd.security,
        provider: cmd.provider,
        export: cmd.export,
        html: cmd.html,
        fix: cmd.fix,
        fix_dry_run: cmd.fix_dry_run,
        max_depth: cmd.max_depth,
    };
    commands::handle_scan(cmd_args).await
}

async fn handle_cleanup(client: DaemonClient, cmd: CleanupCommand) -> Result<()> {
    let cmd_args = commands::cleanup::CleanupCommand {
        dry_run: cmd.dry_run,
        execute: cmd.execute,
        archive: false, // Added as option
        path: None,     // Use current directory
    };
    commands::handle_cleanup(client, cmd_args).await
}

async fn handle_status(client: DaemonClient, cmd: StatusCommand) -> Result<()> {
    let cmd_args = commands::status::StatusCommand {
        json: cmd.json,
    };
    commands::handle_status(client, cmd_args).await
}

async fn handle_unlock(client: DaemonClient, cmd: UnlockCommand) -> Result<()> {
    let cmd_args = commands::unlock::UnlockCommand {
        password: cmd.password,
    };
    commands::handle_unlock(client, cmd_args).await
}

async fn handle_lock(client: DaemonClient, _cmd: LockCommand) -> Result<()> {
    let cmd_args = commands::lock::LockCommand {};
    commands::handle_lock(client, cmd_args).await
}

async fn handle_change_password(client: DaemonClient, _cmd: ChangePasswordCommand) -> Result<()> {
    let cmd_args = commands::change_password::ChangePasswordCommand;
    commands::handle_change_password(client, cmd_args).await
}

async fn handle_panic(client: DaemonClient, cmd: PanicCommand) -> Result<()> {
    let cmd_args = commands::panic::PanicCommand {
        force: cmd.force,
    };
    commands::handle_panic(client, cmd_args).await
}

async fn handle_provider(client: DaemonClient, cmd: ProviderCommandStruct) -> Result<()> {
    use commands::provider::{ProviderAction, ProviderCommand};

    let action = match cmd.action {
        ProviderActionEnum::List { json } => ProviderAction::List { json },
        ProviderActionEnum::Info { name } => ProviderAction::Info { name },
        ProviderActionEnum::Add { name, environment } => ProviderAction::Add { name, environment },
    };

    let cmd_args = ProviderCommand { action };
    commands::handle_provider(client, cmd_args).await
}

async fn handle_cleanup_expired(client: DaemonClient, cmd: CleanupExpiredCommand) -> Result<()> {
    use serde::Deserialize;

    #[derive(Debug, Deserialize)]
    struct CleanupResponse {
        status: String,
        removed_count: usize,
    }

    let response: CleanupResponse = client
        .request("secret.cleanup", serde_json::json!({}))
        .await
        .context("Failed to cleanup expired secrets")?;

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
            "status": response.status,
            "removed_count": response.removed_count
        }))?);
    } else {
        println!("Cleaned up {} expired secret(s)", response.removed_count);
    }
    Ok(())
}

async fn handle_expiring(client: DaemonClient, cmd: ExpiringCommand) -> Result<()> {
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Deserialize, Serialize)]
    struct ExpiringSecret {
        name: String,
        expires_at: String,
    }

    #[derive(Debug, Deserialize)]
    struct ExpiringResponse {
        secrets: Vec<ExpiringSecret>,
        #[allow(dead_code)]
        within_seconds: u64,
    }

    let response: ExpiringResponse = client
        .request("secret.expiring", serde_json::json!({ "within_seconds": cmd.within }))
        .await
        .context("Failed to get expiring secrets")?;

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&response.secrets)?);
    } else if response.secrets.is_empty() {
        println!("No secrets expiring within {} seconds", cmd.within);
    } else {
        println!("Secrets expiring within {} seconds:\n", cmd.within);
        for secret in &response.secrets {
            println!("  {} (expires: {})", secret.name, secret.expires_at);
        }
        println!("\nTotal: {} secret(s)", response.secrets.len());
    }
    Ok(())
}

async fn handle_history(client: DaemonClient, cmd: HistoryCommand) -> Result<()> {
    use serde::Deserialize;

    #[derive(Debug, Deserialize)]
    struct HistoryResponse {
        name: String,
        version: i64,
        has_previous: bool,
        can_rollback: bool,
        rotated_at: Option<String>,
    }

    let response: HistoryResponse = client
        .request("secret.history", serde_json::json!({ "name": cmd.name }))
        .await
        .context("Failed to get secret history")?;

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
            "name": response.name,
            "version": response.version,
            "has_previous": response.has_previous,
            "can_rollback": response.can_rollback,
            "rotated_at": response.rotated_at
        }))?);
    } else {
        println!("Secret: {}", response.name);
        println!();
        println!("  Version:      {}", response.version);
        println!("  Can rollback: {}", if response.can_rollback { "yes" } else { "no" });
        if let Some(rotated) = response.rotated_at {
            println!("  Last rotated: {}", rotated);
        } else {
            println!("  Last rotated: never");
        }
    }
    Ok(())
}

async fn handle_rollback(client: DaemonClient, cmd: RollbackCommand) -> Result<()> {
    use serde::Deserialize;
    use std::io::{self, Write};

    if !cmd.force {
        print!("Are you sure you want to rollback '{}' to the previous version? [y/N] ", cmd.name);
        io::stdout().flush()?;
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Rollback cancelled");
            return Ok(());
        }
    }

    #[derive(Debug, Deserialize)]
    struct RollbackResponse {
        name: String,
        version: i64,
        status: String,
    }

    let response: RollbackResponse = client
        .request("secret.rollback", serde_json::json!({ "name": cmd.name }))
        .await
        .context("Failed to rollback secret")?;

    println!("Secret rolled back successfully");
    println!();
    println!("  Name:    {}", response.name);
    println!("  Version: {}", response.version);
    println!("  Status:  {}", response.status);

    Ok(())
}

async fn handle_rotation_reminders(client: DaemonClient, cmd: RotationRemindersCommand) -> Result<()> {
    use serde::Deserialize;

    #[derive(Debug, Deserialize)]
    struct RemindersResponse {
        secrets: Vec<String>,
        threshold_days: u64,
        count: usize,
    }

    let response: RemindersResponse = client
        .request("secret.rotation_reminders", serde_json::json!({ "days": cmd.days }))
        .await
        .context("Failed to get rotation reminders")?;

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&serde_json::json!({
            "secrets": response.secrets,
            "threshold_days": response.threshold_days,
            "count": response.count
        }))?);
    } else if response.secrets.is_empty() {
        println!("All secrets have been rotated within the last {} days", cmd.days);
    } else {
        println!("Secrets needing rotation (not rotated in {} days):\n", cmd.days);
        for secret in &response.secrets {
            println!("  ⚠ {}", secret);
        }
        println!("\nTotal: {} secret(s)", response.count);
        println!("\nTip: Use 'sec rotate <name> <new-value>' to rotate a secret");
    }
    Ok(())
}

async fn handle_version(_client: DaemonClient, cmd: VersionCommand) -> Result<()> {
    if cmd.verbose {
        println!("sec version {}", env!("CARGO_PKG_VERSION"));
        println!("Platform: {}", std::env::consts::OS);
        println!("Architecture: {}", std::env::consts::ARCH);
    } else {
        println!("{}", env!("CARGO_PKG_VERSION"));
    }
    Ok(())
}

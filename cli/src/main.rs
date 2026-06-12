//! Secretariat CLI - Command-line interface for secret management
//!
//! Wave 16: F087-F100 - CLI Foundation
//! Wave 17: F101-F115 - CLI Client & Commands
//!
//! This CLI provides a developer-friendly interface to the Secretariat daemon
//! for managing secrets, applications, and access control.

use anyhow::Result;
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

    /// Grant app access to secret
    Grant(GrantCommand),

    /// Revoke app access
    Revoke(RevokeCommand),

    /// List registered apps
    Apps(AppsCommand),

    /// View access log
    Audit(AuditCommand),

    /// Show what secrets app would receive
    Explain(ExplainCommand),

    /// Import from .env file
    Import(ImportCommand),

    /// Cleanup old .env files
    Cleanup(CleanupCommand),

    /// Run a command with secrets injected into its environment
    Run(RunCommand),

    /// Show daemon status
    Status(StatusCommand),

    /// Manage the daemon Launch Agent (install/uninstall/status)
    Service(ServiceCommand),

    /// Run the MCP server for AI agents (stdio) — use, but never read, secrets
    Mcp(McpCommand),

    /// Unlock vault (Touch ID/password)
    Unlock(UnlockCommand),

    /// Lock vault
    Lock(LockCommand),

    /// Change master password
    ChangePassword(ChangePasswordCommand),

    /// Show version
    Version(VersionCommand),
}

/// Manage the daemon Launch Agent (macOS)
#[derive(Parser)]
struct ServiceCommand {
    #[command(subcommand)]
    action: ServiceAction,
}

#[derive(Subcommand)]
enum ServiceAction {
    /// Install + load the daemon Launch Agent (auto-start on login)
    Install,
    /// Remove the daemon Launch Agent
    Uninstall,
    /// Show Launch Agent install/running status
    Status,
}

/// Run a command with secrets injected into its environment.
///
/// Secret names come from a committable .secretariat.toml manifest (names
/// only, never values) and/or --secret flags. Child stdout/stderr are
/// scrubbed: secret values are replaced with [REDACTED:NAME].
///
/// Examples:
///   sec run -- npm run dev
///   sec run --secret OPENAI_API_KEY -- python train.py
///   sec run --secret API_KEY=prod/api_key -- ./deploy.sh
#[derive(Parser)]
struct RunCommand {
    /// Path to the manifest (default: search .secretariat.toml upwards)
    #[arg(long)]
    manifest: Option<std::path::PathBuf>,

    /// Inject a secret: NAME or ENV_VAR=VAULT_NAME (repeatable)
    #[arg(long = "secret")]
    secrets: Vec<String>,

    /// Inherit stdio instead of scrubbing output (interactive/TTY tools)
    #[arg(long)]
    no_redact: bool,

    /// The command to run (everything after --)
    #[arg(trailing_var_arg = true, allow_hyphen_values = true, required = true)]
    command: Vec<String>,
}

/// MCP server over stdio for AI agents.
///
/// Deliberately asymmetric: agents can list secret NAMES, run commands with
/// secrets injected (output redacted), create secrets, and read the audit
/// log — but there is NO tool that returns a secret value.
///
/// Claude Code (.mcp.json):
///   { "mcpServers": { "secretariat": { "command": "sec", "args": ["mcp"] } } }
#[derive(Parser)]
struct McpCommand {}

// F091: InitCommand struct for sec init
/// Initialize the secrets vault
#[derive(Parser)]
struct InitCommand {
    /// Skip interactive prompts and use defaults
    #[arg(short, long)]
    yes: bool,

    /// Master password (for headless/non-interactive use).
    /// Falls back to $SECRETARIAT_INIT_PASSWORD env var if not provided.
    #[arg(short, long)]
    password: Option<String>,
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

    /// After import: write .secretariat.toml manifest, add the .env to
    /// .gitignore, securely delete it, and scan for leftover plaintext
    #[arg(long)]
    eradicate: bool,
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

    /// Provide password directly (for non-interactive use).
    /// Falls back to $SECRETARIAT_INIT_PASSWORD env var.
    #[arg(long)]
    password_value: Option<String>,
}

/// Lock vault
#[derive(Parser)]
struct LockCommand {}

/// Change master password
#[derive(Parser)]
struct ChangePasswordCommand {}

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
    // Logs go to stderr: stdout must stay clean for piping (`sec get`) and is
    // the protocol channel in MCP mode (`sec mcp`).
    tracing_subscriber::fmt()
        .with_writer(std::io::stderr)
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
        Commands::Grant(cmd) => handle_grant(client, cmd).await,
        Commands::Revoke(cmd) => handle_revoke(client, cmd).await,
        Commands::Apps(cmd) => handle_apps(client, cmd).await,
        Commands::Audit(cmd) => handle_audit(client, cmd).await,
        Commands::Explain(cmd) => handle_explain(client, cmd).await,
        Commands::Import(cmd) => handle_import(client, cmd).await,
        Commands::Cleanup(cmd) => handle_cleanup(client, cmd).await,
        Commands::Status(cmd) => handle_status(client, cmd).await,
        Commands::Run(cmd) => {
            commands::run::handle_run(
                client,
                commands::run::RunArgs {
                    manifest: cmd.manifest,
                    secrets: cmd.secrets,
                    no_redact: cmd.no_redact,
                    command: cmd.command,
                },
            )
            .await
        }
        Commands::Service(cmd) => match cmd.action {
            ServiceAction::Install => commands::service::install(),
            ServiceAction::Uninstall => commands::service::uninstall(),
            ServiceAction::Status => commands::service::status(),
        },
        Commands::Mcp(_) => commands::mcp::serve(client).await,
        Commands::Unlock(cmd) => handle_unlock(client, cmd).await,
        Commands::Lock(cmd) => handle_lock(client, cmd).await,
        Commands::ChangePassword(cmd) => handle_change_password(client, cmd).await,
        Commands::Version(cmd) => handle_version(client, cmd).await,
    }
}

// Command handlers

// F109-F113: Init command - implemented in commands/init.rs
async fn handle_init(client: DaemonClient, cmd: InitCommand) -> Result<()> {
    let cmd_args = commands::init::InitCommand {
        yes: cmd.yes,
        password: cmd.password.or_else(|| std::env::var("SECRETARIAT_INIT_PASSWORD").ok()),
    };
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
        eradicate: cmd.eradicate,
    };
    commands::handle_import(client, cmd_args).await
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
        password_value: cmd.password_value.or_else(|| std::env::var("SECRETARIAT_INIT_PASSWORD").ok()),
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

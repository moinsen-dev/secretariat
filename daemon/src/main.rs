//! Secretariat Daemon (secd)
//!
//! Background service for secure local secrets management.
//! Provides encrypted storage and IPC-based API for secret access.
//!
//! # Usage
//!
//! ```bash
//! secd              # Start daemon in foreground
//! secd start        # Start daemon in foreground
//! secd start -d     # Start daemon in background (daemonized)
//! secd stop         # Stop running daemon
//! secd status       # Check daemon status
//! secd --help       # Show help
//! secd --version    # Show version
//! ```

mod crypto;
mod storage;
mod keychain;
mod server;
mod handlers;
mod system_events;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::Mutex;
use tracing::{info, error, warn};

use storage::Storage;

/// Secretariat Daemon - Secure local secrets management
#[derive(Parser)]
#[command(name = "secd")]
#[command(author, version, about, long_about = None)]
#[command(after_help = "Examples:
  secd              Start daemon in foreground
  secd start        Start daemon in foreground
  secd start -d     Start daemon in background (daemonized)
  secd stop         Stop running daemon
  secd status       Check if daemon is running
")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the daemon
    Start {
        /// Run in background (daemonize)
        #[arg(short, long)]
        daemonize: bool,
    },
    /// Stop the running daemon
    Stop,
    /// Check daemon status
    Status,
}

/// Application configuration
struct Config {
    /// Path to the data directory
    data_dir: PathBuf,
    /// Path to the SQLite database
    db_path: PathBuf,
    /// Path to the PID file
    pid_path: PathBuf,
    /// Path to the socket file
    socket_path: PathBuf,
}

impl Config {
    /// Create configuration with default paths
    ///
    /// Uses platform-specific application data directories:
    /// - macOS: ~/Library/Application Support/Secretariat/
    /// - Linux: ~/.local/share/secretariat/
    /// - Windows: %APPDATA%\Secretariat\
    fn default() -> Result<Self> {
        let env_data_dir = std::env::var_os("SECRETARIAT_DATA_DIR")
            .map(PathBuf::from);
        let env_db_path = std::env::var_os("SECRETARIAT_DB_PATH")
            .map(PathBuf::from);
        let env_socket_path = std::env::var_os("SECRETARIAT_SOCKET_PATH")
            .or_else(|| std::env::var_os("SECRETARIAT_SOCKET"))
            .map(PathBuf::from);

        let mut data_dir = if let Some(path) = env_data_dir {
            path
        } else if let Some(path) = env_db_path.as_ref() {
            path.parent()
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."))
        } else if let Some(path) = env_socket_path.as_ref() {
            path.parent()
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."))
        } else if cfg!(target_os = "macos") {
            dirs::home_dir()
                .context("Failed to get home directory")?
                .join("Library/Application Support/Secretariat")
        } else if cfg!(target_os = "linux") {
            dirs::home_dir()
                .context("Failed to get home directory")?
                .join(".local/share/secretariat")
        } else if cfg!(target_os = "windows") {
            dirs::data_dir()
                .context("Failed to get app data directory")?
                .join("Secretariat")
        } else {
            anyhow::bail!("Unsupported operating system");
        };

        let db_path = env_db_path.unwrap_or_else(|| data_dir.join("vault.db"));
        let socket_path = env_socket_path.unwrap_or_else(|| data_dir.join("secretariat.sock"));

        if let Some(parent) = socket_path.parent() {
            if !parent.as_os_str().is_empty() {
                data_dir = parent.to_path_buf();
            }
        } else if let Some(parent) = db_path.parent() {
            if !parent.as_os_str().is_empty() {
                data_dir = parent.to_path_buf();
            }
        }
        let pid_path = data_dir.join("secd.pid");

        Ok(Config {
            data_dir,
            db_path,
            pid_path,
            socket_path,
        })
    }
}

fn is_incompatible_database_error(error: &anyhow::Error) -> bool {
    error
        .chain()
        .any(|cause| cause.to_string().to_lowercase().contains("file is not a database"))
}

fn backup_incompatible_database(db_path: &Path) -> Result<PathBuf> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let filename = db_path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("vault.db");
    let backup_name = format!("{filename}.incompatible.{timestamp}.bak");
    let backup_path = db_path.with_file_name(backup_name);

    fs::rename(db_path, &backup_path).with_context(|| {
        format!(
            "Failed to move incompatible database from {} to {}",
            db_path.display(),
            backup_path.display()
        )
    })?;

    for suffix in ["-wal", "-shm"] {
        let sidecar_path = PathBuf::from(format!("{}{}", db_path.display(), suffix));
        if sidecar_path.exists() {
            let _ = fs::remove_file(sidecar_path);
        }
    }

    Ok(backup_path)
}

fn initialize_storage_with_recovery(db_path: &Path) -> Result<Storage> {
    match Storage::new_without_key(db_path) {
        Ok(storage) => Ok(storage),
        Err(error) => {
            if !is_incompatible_database_error(&error) || !db_path.exists() {
                return Err(error);
            }

            warn!(
                "Incompatible database detected at {}. Backing it up and creating a fresh database.",
                db_path.display()
            );
            let backup_path = backup_incompatible_database(db_path)
                .context("Failed to backup incompatible database")?;
            warn!("Backed up incompatible database to {}", backup_path.display());
            eprintln!(
                "Warning: incompatible database moved to {}",
                backup_path.display()
            );

            Storage::new_without_key(db_path)
                .context("Failed to initialize fresh database after incompatible DB recovery")
        }
    }
}

/// PID file management for single-instance enforcement
struct PidFile {
    path: PathBuf,
}

impl PidFile {
    fn new(path: PathBuf) -> Self {
        PidFile { path }
    }

    /// Check if another daemon is already running
    ///
    /// Uses kill(pid, 0) to check if process exists - this is fast and reliable
    /// unlike sysinfo which can hang on macOS.
    fn is_daemon_running(&self) -> Option<u32> {
        if let Ok(content) = fs::read_to_string(&self.path) {
            if let Ok(pid) = content.trim().parse::<u32>() {
                // Use kill(pid, 0) to check if process exists
                // This sends no signal but returns success if process exists
                let result = unsafe { libc::kill(pid as i32, 0) };

                if result == 0 {
                    // Process exists - assume it's our daemon since we wrote the PID file
                    return Some(pid);
                }

                // Process doesn't exist - stale PID file
                warn!("Removing stale PID file (process {} not running)", pid);
                let _ = fs::remove_file(&self.path);
            }
        }
        None
    }

    /// Write current process PID to file
    fn write(&self) -> Result<()> {
        let pid = std::process::id();
        fs::write(&self.path, pid.to_string())
            .context("Failed to write PID file")?;
        info!("PID file created: {} (PID: {})", self.path.display(), pid);
        Ok(())
    }

    /// Remove PID file
    fn remove(&self) {
        if self.path.exists() {
            if let Err(e) = fs::remove_file(&self.path) {
                warn!("Failed to remove PID file: {}", e);
            } else {
                info!("PID file removed");
            }
        }
    }
}

impl Drop for PidFile {
    fn drop(&mut self) {
        self.remove();
    }
}

/// Daemon state
struct Daemon {
    config: Config,
    storage: Arc<Mutex<Storage>>,
    _pid_file: PidFile,
}

impl Daemon {
    /// Initialize the daemon
    ///
    /// Sets up storage and prepares the daemon to handle requests
    fn new(config: Config) -> Result<Self> {
        // Ensure data directory exists
        fs::create_dir_all(&config.data_dir)
            .context("Failed to create data directory")?;

        // Check if another daemon is already running
        let pid_file = PidFile::new(config.pid_path.clone());
        if let Some(existing_pid) = pid_file.is_daemon_running() {
            anyhow::bail!(
                "Another daemon instance is already running (PID: {}). \
                 Use 'secd stop' to stop it first.",
                existing_pid
            );
        }

        // Write our PID file
        pid_file.write()?;

        info!("Initializing daemon with data directory: {}", config.data_dir.display());

        // Initialize storage without encryption key - encryption is handled by vault unlock
        // The actual encryption key comes from the master password via Argon2 derivation
        let storage = initialize_storage_with_recovery(&config.db_path)
            .context("Failed to initialize storage")?;

        info!("Storage initialized at: {}", config.db_path.display());

        // Verify storage is working
        storage.health_check()
            .context("Storage health check failed")?;

        Ok(Daemon {
            config,
            storage: Arc::new(Mutex::new(storage)),
            _pid_file: pid_file,
        })
    }

    /// Run the daemon
    ///
    /// Main event loop for handling IPC requests
    async fn run(&self) -> Result<()> {
        info!("Secretariat daemon starting...");

        // Display database statistics
        {
            let storage = self.storage.lock().await;
            match storage.stats() {
                Ok(stats) => {
                    info!("Database statistics:");
                    info!("  Total secrets: {}", stats.total_secrets);
                    info!("  Secrets with provider: {}", stats.with_provider);
                    info!("  Environments: {:?}", stats.environments);
                    info!("  Total applications: {}", stats.total_applications);
                    info!("  Total permissions: {}", stats.total_permissions);
                    info!("  Total audit entries: {}", stats.total_audit_entries);
                }
                Err(e) => {
                    error!("Failed to get database statistics: {}", e);
                }
            }
        } // Release lock

        info!("Daemon is ready");
        info!("Database: {}", self.config.db_path.display());

        let restore_key_on_start = std::env::var("SECRETARIAT_RESTORE_KEY_ON_START")
            .map(|value| matches!(value.as_str(), "1" | "true" | "TRUE" | "yes" | "YES"))
            .unwrap_or(false);

        let master_key = if restore_key_on_start {
            match keychain::retrieve_master_key() {
                Ok(key) => {
                    info!("Master key retrieved from keychain - vault will start unlocked");
                    Some(key)
                }
                Err(e) => {
                    info!("No master key in keychain ({}), vault will start locked", e);
                    None
                }
            }
        } else {
            info!(
                "Skipping keychain restore on startup; vault will start locked. \
                 Set SECRETARIAT_RESTORE_KEY_ON_START=1 to enable."
            );
            None
        };

        // Determine initial vault state
        let vault_starts_locked = master_key.is_none();
        if vault_starts_locked {
            info!("Vault is locked - unlock with 'sec unlock' to access secrets");
        }

        // Use a zeroed key if locked - actual key comes from unlock operation
        let initial_key = master_key.unwrap_or([0u8; 32]);

        // F047: Create server state for graceful shutdown coordination
        let server_state = server::ServerState::new_with_lock_state(
            self.storage.clone(),
            initial_key,
            vault_starts_locked,
        );

        // Start IPC server
        let listener = server::start_server()
            .await
            .context("Failed to start IPC server")?;

        // Get socket path for cleanup during shutdown
        let socket_path = server::get_socket_path()
            .context("Failed to get socket path")?;

        // F085-F086: Spawn periodic cleanup task for old audit logs with configurable retention
        let cleanup_storage = self.storage.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(3600)); // Run every hour
            loop {
                interval.tick().await;
                let storage = cleanup_storage.lock().await;
                // F086: Use default 30-day retention (configurable via None parameter)
                match storage.cleanup_old_logs(None) {
                    Ok(deleted) if deleted > 0 => {
                        info!("Audit log cleanup: removed {} old entries", deleted);
                    }
                    Ok(_) => {
                        // No logs to clean up, don't spam logs
                    }
                    Err(e) => {
                        error!("Audit log cleanup failed: {}", e);
                    }
                }
            }
        });

        // Auto-lock on system sleep (app_spec.txt line 298)
        let sleep_server_state = server_state.clone();
        let runtime_handle = tokio::runtime::Handle::current();
        let mut sleep_monitor = system_events::SystemEventMonitor::new();
        sleep_monitor.on_sleep(std::sync::Arc::new(move || {
            info!("System going to sleep - auto-locking vault");
            // Use runtime handle to spawn async lock operation
            let state = sleep_server_state.clone();
            runtime_handle.spawn(async move {
                state.lock_vault().await;
                info!("Vault auto-locked due to system sleep");
            });
        }));
        if let Err(e) = sleep_monitor.start() {
            warn!("Failed to start system sleep monitor: {}", e);
        }

        info!("Daemon initialized successfully. Press Ctrl+C to stop.");

        // Run accept loop and shutdown handler concurrently
        tokio::select! {
            result = server::accept_loop(listener, server_state.clone()) => {
                // Accept loop exited (shouldn't happen normally)
                result.context("Accept loop terminated unexpectedly")?;
            }
            _ = tokio::signal::ctrl_c() => {
                info!("Shutdown signal received");
            }
        }

        // F047: Perform graceful shutdown
        server::graceful_shutdown(server_state, socket_path).await;

        info!("Daemon stopped");

        Ok(())
    }
}

/// Check daemon status by checking PID file
fn check_daemon_status(config: &Config) -> (bool, Option<u32>) {
    let pid_file = PidFile::new(config.pid_path.clone());
    let running_pid = pid_file.is_daemon_running();

    // PID check is authoritative - socket may not exist during startup
    (running_pid.is_some(), running_pid)
}

/// Stop the running daemon by sending SIGTERM
fn stop_daemon(config: &Config) -> Result<()> {
    let pid_file = PidFile::new(config.pid_path.clone());

    if let Some(pid) = pid_file.is_daemon_running() {
        println!("Stopping daemon (PID: {})...", pid);

        #[cfg(unix)]
        {
            // Send SIGTERM to the process
            let result = Command::new("kill")
                .args(["-TERM", &pid.to_string()])
                .output();

            match result {
                Ok(output) if output.status.success() => {
                    // Wait a moment for the process to stop
                    std::thread::sleep(std::time::Duration::from_millis(500));

                    // Check if it actually stopped
                    if pid_file.is_daemon_running().is_none() {
                        println!("Daemon stopped successfully");

                        // Clean up socket file if it still exists
                        if config.socket_path.exists() {
                            let _ = fs::remove_file(&config.socket_path);
                        }

                        Ok(())
                    } else {
                        // Process still running, try SIGKILL
                        warn!("Daemon didn't respond to SIGTERM, sending SIGKILL...");
                        let _ = Command::new("kill")
                            .args(["-KILL", &pid.to_string()])
                            .output();
                        std::thread::sleep(std::time::Duration::from_millis(200));

                        // Clean up
                        let _ = fs::remove_file(&config.pid_path);
                        if config.socket_path.exists() {
                            let _ = fs::remove_file(&config.socket_path);
                        }

                        println!("Daemon killed");
                        Ok(())
                    }
                }
                Ok(output) => {
                    anyhow::bail!("Failed to stop daemon: {}", String::from_utf8_lossy(&output.stderr));
                }
                Err(e) => {
                    anyhow::bail!("Failed to send signal to daemon: {}", e);
                }
            }
        }

        #[cfg(windows)]
        {
            // On Windows, use taskkill
            let result = Command::new("taskkill")
                .args(["/PID", &pid.to_string(), "/F"])
                .output();

            match result {
                Ok(output) if output.status.success() => {
                    println!("Daemon stopped successfully");
                    Ok(())
                }
                Ok(output) => {
                    anyhow::bail!("Failed to stop daemon: {}", String::from_utf8_lossy(&output.stderr));
                }
                Err(e) => {
                    anyhow::bail!("Failed to stop daemon: {}", e);
                }
            }
        }
    } else {
        println!("No daemon is currently running");

        // Clean up stale socket if it exists
        if config.socket_path.exists() {
            println!("Removing stale socket file...");
            let _ = fs::remove_file(&config.socket_path);
        }

        Ok(())
    }
}

/// Start daemon in background (daemonized)
fn start_daemonized() -> Result<()> {
    let current_exe = std::env::current_exe()
        .context("Failed to get current executable path")?;

    println!("Starting daemon in background...");

    #[cfg(unix)]
    {
        // Fork and detach on Unix
        let child = Command::new(&current_exe)
            .arg("start")
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .context("Failed to spawn daemon process")?;

        println!("Daemon started in background (PID: {})", child.id());
        println!("Use 'secd status' to check if it's running");
    }

    #[cfg(windows)]
    {
        // On Windows, use CREATE_NO_WINDOW flag
        use std::os::windows::process::CommandExt;
        let child = Command::new(&current_exe)
            .arg("start")
            .creation_flags(0x08000000) // CREATE_NO_WINDOW
            .spawn()
            .context("Failed to spawn daemon process")?;

        println!("Daemon started in background (PID: {})", child.id());
    }

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Load configuration first (needed for all commands)
    let config = Config::default()
        .context("Failed to load configuration")?;

    match cli.command {
        // No subcommand = start in foreground (same as `secd start`)
        None | Some(Commands::Start { daemonize: false }) => {
            // Initialize logging
            tracing_subscriber::fmt()
                .with_env_filter(
                    tracing_subscriber::EnvFilter::try_from_default_env()
                        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"))
                )
                .init();

            info!("Secretariat Daemon v{}", env!("CARGO_PKG_VERSION"));

            // Initialize daemon
            let daemon = Daemon::new(config)
                .context("Failed to initialize daemon")?;

            // Run daemon
            daemon.run().await
                .context("Daemon encountered an error")?;
        }

        Some(Commands::Start { daemonize: true }) => {
            // Check if already running first
            if let (true, Some(pid)) = check_daemon_status(&config) {
                println!("Daemon is already running (PID: {})", pid);
                return Ok(());
            }

            start_daemonized()?;
        }

        Some(Commands::Stop) => {
            stop_daemon(&config)?;
        }

        Some(Commands::Status) => {
            let (running, pid) = check_daemon_status(&config);

            if running {
                println!("Daemon is running (PID: {})", pid.unwrap());
                println!("Socket: {}", config.socket_path.display());
                println!("Database: {}", config.db_path.display());
            } else {
                println!("Daemon is not running");

                if config.socket_path.exists() {
                    println!("Warning: Stale socket file exists at {}", config.socket_path.display());
                }
                if config.pid_path.exists() {
                    println!("Warning: Stale PID file exists at {}", config.pid_path.display());
                }
            }
        }
    }

    Ok(())
}

//! Secretariat Daemon (secd)
//!
//! Background service for secure local secrets management.
//! Provides encrypted storage and IPC-based API for secret access.

mod crypto;
mod storage;
mod keychain;
mod server;
mod handlers;

use anyhow::{Context, Result};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{info, error};

use storage::Storage;

/// Application configuration
struct Config {
    /// Path to the data directory
    data_dir: PathBuf,
    /// Path to the SQLite database
    db_path: PathBuf,
}

impl Config {
    /// Create configuration with default paths
    ///
    /// Uses platform-specific application data directories:
    /// - macOS: ~/Library/Application Support/Secretariat/
    /// - Linux: ~/.local/share/secretariat/
    /// - Windows: %APPDATA%\Secretariat\
    fn default() -> Result<Self> {
        let data_dir = if cfg!(target_os = "macos") {
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

        let db_path = data_dir.join("vault.db");

        Ok(Config {
            data_dir,
            db_path,
        })
    }
}

/// Daemon state
struct Daemon {
    config: Config,
    storage: Arc<Mutex<Storage>>,
}

impl Daemon {
    /// Initialize the daemon
    ///
    /// Sets up storage and prepares the daemon to handle requests
    fn new(config: Config) -> Result<Self> {
        // Ensure data directory exists
        std::fs::create_dir_all(&config.data_dir)
            .context("Failed to create data directory")?;

        info!("Initializing daemon with data directory: {}", config.data_dir.display());

        // TODO: In production, the encryption key should come from the system keychain
        // For now, using a placeholder for initial implementation
        let encryption_key = "development_key_change_in_production";

        // Initialize storage
        let storage = Storage::new(&config.db_path, encryption_key)
            .context("Failed to initialize storage")?;

        info!("Storage initialized at: {}", config.db_path.display());

        // Verify storage is working
        storage.health_check()
            .context("Storage health check failed")?;

        Ok(Daemon {
            config,
            storage: Arc::new(Mutex::new(storage)),
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

        // F061: Retrieve master key from keychain (or use development key)
        let master_key = match keychain::retrieve_master_key() {
            Ok(key) => {
                info!("Master key retrieved from keychain");
                key
            }
            Err(e) => {
                // For development, generate a temporary key
                // In production, this should fail if keychain access fails
                info!("Failed to retrieve master key from keychain: {}", e);
                info!("Using development master key (WARNING: NOT SECURE FOR PRODUCTION)");
                crypto::generate_master_key()
            }
        };

        // F047: Create server state for graceful shutdown coordination
        let server_state = server::ServerState::new(self.storage.clone(), master_key);

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

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"))
        )
        .init();

    info!("Secretariat Daemon v{}", env!("CARGO_PKG_VERSION"));

    // Load configuration
    let config = Config::default()
        .context("Failed to load configuration")?;

    // Initialize daemon
    let daemon = Daemon::new(config)
        .context("Failed to initialize daemon")?;

    // Run daemon
    daemon.run().await
        .context("Daemon encountered an error")?;

    info!("Daemon stopped");

    Ok(())
}

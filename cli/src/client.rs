//! F099-F108: Daemon client for CLI
//!
//! This module provides the DaemonClient struct for communicating with the daemon
//! over Unix domain sockets (macOS/Linux) or named pipes (Windows).
//!
//! Features F101-F108:
//! - F101: DaemonClient::new() constructor
//! - F102: connect() with retry logic
//! - F103: send_request() method
//! - F104: JSON serialization with serde_json
//! - F105: Write JSON to UnixStream
//! - F106: Read response with timeout
//! - F107: Parse response and extract result/error
//! - F108: Exponential backoff retry (3 attempts, 100ms/200ms/400ms)
//! - Auto-start daemon if not running

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::time::timeout;

/// F100-F101: DaemonClient struct with socket path field
///
/// Client for communicating with the Secretariat daemon over IPC.
pub struct DaemonClient {
    /// Path to the Unix domain socket
    socket_path: PathBuf,
    /// Maximum number of retry attempts
    max_retries: usize,
    /// Base delay for exponential backoff (milliseconds)
    base_delay_ms: u64,
}

impl DaemonClient {
    /// F101: Create a new daemon client with default retry configuration
    ///
    /// Automatically determines the socket path based on platform conventions:
    /// - macOS: ~/Library/Application Support/Secretariat/secretariat.sock
    /// - Linux: ~/.local/share/secretariat/secretariat.sock
    ///
    /// Default retry configuration:
    /// - 3 attempts (initial + 2 retries)
    /// - Exponential backoff: 100ms, 200ms, 400ms
    pub fn new() -> Result<Self> {
        let socket_path = Self::get_socket_path()
            .context("Failed to determine daemon socket path")?;

        Ok(Self {
            socket_path,
            max_retries: 3,
            base_delay_ms: 100,
        })
    }

    /// Get the platform-specific socket path
    fn get_socket_path() -> Result<PathBuf> {
        if let Some(socket_path) = std::env::var_os("SECRETARIAT_SOCKET_PATH")
            .or_else(|| std::env::var_os("SECRETARIAT_SOCKET"))
        {
            return Ok(PathBuf::from(socket_path));
        }

        #[cfg(target_os = "macos")]
        let base_dir = dirs::home_dir()
            .context("Failed to get home directory")?
            .join("Library")
            .join("Application Support")
            .join("Secretariat");

        #[cfg(target_os = "linux")]
        let base_dir = dirs::data_local_dir()
            .context("Failed to get local data directory")?
            .join("secretariat");

        #[cfg(target_os = "windows")]
        let base_dir = dirs::data_local_dir()
            .context("Failed to get local data directory")?
            .join("Secretariat");

        Ok(base_dir.join("secretariat.sock"))
    }

    /// F102, F108: Connect to the daemon with exponential backoff retry
    ///
    /// Establishes a connection to the daemon's Unix domain socket.
    /// If the daemon is not running, automatically starts it in the background.
    /// Retries connection with exponential backoff on failure.
    ///
    /// # Returns
    ///
    /// Returns a connected UnixStream on success.
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The daemon cannot be started
    /// - Connection fails after all retry attempts
    ///
    /// Retry strategy:
    /// - Attempt 1: Immediate
    /// - Attempt 2: After 100ms delay
    /// - Attempt 3: After 200ms delay (total 300ms)
    /// - If all fail and daemon not running: auto-start daemon
    /// - Then retry with longer delays for daemon startup
    pub async fn connect(&self) -> Result<UnixStream> {
        // First, try to connect normally
        match self.try_connect().await {
            Ok(stream) => return Ok(stream),
            Err(_) => {
                // Connection failed, try to start the daemon
                if self.start_daemon_if_needed().await? {
                    // Daemon was started, wait a bit longer for it to initialize
                    eprintln!("Starting daemon...");
                    tokio::time::sleep(Duration::from_millis(500)).await;

                    // Retry with more attempts and longer delays for daemon startup
                    self.try_connect_with_startup_delay().await
                } else {
                    // Daemon was already running but we couldn't connect
                    self.try_connect().await
                }
            }
        }
    }

    /// Try to connect with standard retry logic
    async fn try_connect(&self) -> Result<UnixStream> {
        let mut last_error = None;

        for attempt in 0..self.max_retries {
            match UnixStream::connect(&self.socket_path).await {
                Ok(stream) => {
                    if attempt > 0 {
                        tracing::debug!(
                            "Connected to daemon on attempt {} after retries",
                            attempt + 1
                        );
                    }
                    return Ok(stream);
                }
                Err(e) => {
                    last_error = Some(e);

                    // Don't sleep after the last attempt
                    if attempt < self.max_retries - 1 {
                        // F108: Exponential backoff - 100ms * 2^attempt
                        let delay_ms = self.base_delay_ms * (1 << attempt);
                        tracing::debug!(
                            "Connection attempt {} failed, retrying in {}ms",
                            attempt + 1,
                            delay_ms
                        );
                        tokio::time::sleep(Duration::from_millis(delay_ms)).await;
                    }
                }
            }
        }

        // All retries exhausted
        Err(last_error.unwrap()).with_context(|| {
            format!(
                "Failed to connect to daemon at {} after {} attempts",
                self.socket_path.display(),
                self.max_retries
            )
        })
    }

    /// Try to connect with longer delays for daemon startup
    async fn try_connect_with_startup_delay(&self) -> Result<UnixStream> {
        let startup_attempts = 10; // More attempts during startup
        let startup_delay_ms = 500; // 500ms between attempts

        for attempt in 0..startup_attempts {
            match UnixStream::connect(&self.socket_path).await {
                Ok(stream) => {
                    eprintln!("Daemon started successfully");
                    return Ok(stream);
                }
                Err(e) => {
                    if attempt < startup_attempts - 1 {
                        tracing::debug!(
                            "Waiting for daemon startup, attempt {} of {}",
                            attempt + 1,
                            startup_attempts
                        );
                        tokio::time::sleep(Duration::from_millis(startup_delay_ms)).await;
                    } else {
                        return Err(e).with_context(|| {
                            format!(
                                "Daemon started but failed to connect after {}s. Check daemon logs.",
                                (startup_attempts * startup_delay_ms) / 1000
                            )
                        });
                    }
                }
            }
        }

        // This is logically unreachable since the for loop always returns,
        // but we provide a proper error for safety instead of panicking
        Err(anyhow::anyhow!(
            "Unexpected state: daemon startup loop completed without returning"
        ))
    }

    /// Check if daemon is running and start it if not
    ///
    /// Returns true if daemon was started, false if already running
    async fn start_daemon_if_needed(&self) -> Result<bool> {
        // Check if socket exists - if not, daemon is likely not running
        if !self.socket_path.exists() {
            return self.start_daemon().await.map(|_| true);
        }

        // Socket exists but we couldn't connect - might be stale
        // Try to start daemon anyway (it will handle duplicate detection)
        match self.start_daemon().await {
            Ok(_) => Ok(true),
            Err(e) => {
                // If daemon reports already running, that's fine
                let err_str = e.to_string();
                if err_str.contains("already running") {
                    Ok(false)
                } else {
                    Err(e)
                }
            }
        }
    }

    /// Start the daemon in the background
    async fn start_daemon(&self) -> Result<()> {
        // Find the secd binary - check common locations
        let secd_path = self.find_secd_binary()?;

        tracing::debug!("Starting daemon from: {}", secd_path.display());

        let mut command = Command::new(&secd_path);
        command
            .arg("start")
            .arg("-d") // Daemonize
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .env("SECRETARIAT_SOCKET_PATH", &self.socket_path)
            .env("SECRETARIAT_SOCKET", &self.socket_path);

        // Start daemon in background (daemonized mode)
        let child = command
            .spawn()
            .with_context(|| format!("Failed to start daemon from {}", secd_path.display()))?;

        // Wait briefly for the command to complete (it should exit quickly in daemon mode)
        let output = child.wait_with_output()
            .context("Failed to wait for daemon start command")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            // Check if error is "already running" which is fine
            if stderr.contains("already running") {
                tracing::debug!("Daemon already running");
                return Ok(());
            }
            anyhow::bail!("Failed to start daemon: {}", stderr);
        }

        Ok(())
    }

    /// Find the secd binary
    fn find_secd_binary(&self) -> Result<PathBuf> {
        if let Some(path) = std::env::var_os("SECRETARIAT_SECD_PATH") {
            let path = PathBuf::from(path);
            if path.exists() {
                return Ok(path);
            }
        }

        if let Ok(current_exe) = std::env::current_exe() {
            if let Some(parent) = current_exe.parent() {
                let sibling = parent.join("secd");
                if sibling.exists() {
                    return Ok(sibling);
                }
            }
        }

        // Check if secd is in PATH
        if let Ok(path) = which::which("secd") {
            return Ok(path);
        }

        // Check common locations
        let home = dirs::home_dir().context("Failed to get home directory")?;

        let candidates = [
            home.join("bin/secd"),
            home.join(".local/bin/secd"),
            PathBuf::from("/usr/local/bin/secd"),
        ];

        for candidate in &candidates {
            if candidate.exists() {
                return Ok(candidate.clone());
            }
        }

        anyhow::bail!(
            "Could not find secd binary. Please ensure it's installed and in your PATH, \
             or run 'secd' manually to start the daemon."
        )
    }

    /// F103-F105: Send a JSON-RPC request to the daemon
    ///
    /// This method implements:
    /// - F103: send_request(method: &str, params: Value) method
    /// - F104: Serialize request to JSON with serde_json
    /// - F105: Write JSON bytes to UnixStream
    ///
    /// # Arguments
    ///
    /// * `stream` - Connected socket stream
    /// * `method` - JSON-RPC method name (e.g., "secret.list")
    /// * `params` - Request parameters as a serializable value
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if serialization or writing fails
    pub async fn send_request<T: Serialize>(
        &self,
        stream: &mut UnixStream,
        method: &str,
        params: T,
    ) -> Result<()> {
        // F104: Serialize request to JSON
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
        });

        let request_str = serde_json::to_string(&request)
            .context("Failed to serialize request")?;

        // F105: Write JSON bytes to UnixStream
        stream
            .write_all(request_str.as_bytes())
            .await
            .context("Failed to write request to socket")?;

        stream
            .write_all(b"\n")
            .await
            .context("Failed to write newline to socket")?;

        stream.flush().await.context("Failed to flush socket")?;

        Ok(())
    }

    /// F106-F107: Receive a JSON-RPC response from the daemon with timeout
    ///
    /// This method implements:
    /// - F106: Read response JSON from stream with timeout
    /// - F107: Parse response and extract result or error
    ///
    /// # Arguments
    ///
    /// * `stream` - Connected socket stream
    ///
    /// # Returns
    ///
    /// Returns the deserialized response on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Reading from socket fails or times out (30 second timeout)
    /// - Response is not valid JSON
    /// - Response indicates an error
    pub async fn recv_response<T: for<'de> Deserialize<'de>>(
        &self,
        stream: &mut UnixStream,
    ) -> Result<T> {
        let mut reader = BufReader::new(stream);
        let mut response_str = String::new();

        // F106: Read with timeout (30 seconds for potentially long operations)
        let read_result = timeout(
            Duration::from_secs(30),
            reader.read_line(&mut response_str),
        )
        .await
        .context("Timeout waiting for daemon response (30s)")?;

        read_result.context("Failed to read response from socket")?;

        // F107: Parse response and extract result or error
        let response: serde_json::Value = serde_json::from_str(&response_str)
            .context("Failed to parse response JSON")?;

        // Check for JSON-RPC error
        if let Some(error) = response.get("error") {
            let error_message = error
                .get("message")
                .and_then(|m| m.as_str())
                .unwrap_or("Unknown error");
            let error_code = error
                .get("code")
                .and_then(|c| c.as_i64())
                .unwrap_or(-1);
            anyhow::bail!("Daemon error ({}): {}", error_code, error_message);
        }

        // Extract result field
        let result = response
            .get("result")
            .context("Response missing 'result' field")?;

        serde_json::from_value(result.clone())
            .context("Failed to deserialize result")
    }

    /// Send a request and receive a response (convenience method)
    ///
    /// # Arguments
    ///
    /// * `method` - JSON-RPC method name
    /// * `params` - Request parameters
    ///
    /// # Returns
    ///
    /// Returns the deserialized response on success
    pub async fn request<P: Serialize, R: for<'de> Deserialize<'de>>(
        &self,
        method: &str,
        params: P,
    ) -> Result<R> {
        let mut stream = self.connect().await?;
        self.send_request(&mut stream, method, params).await?;
        self.recv_response(&mut stream).await
    }
}

impl Default for DaemonClient {
    fn default() -> Self {
        Self::new().expect("Failed to create DaemonClient")
    }
}

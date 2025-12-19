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

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
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
    /// Retries connection with exponential backoff on failure.
    ///
    /// # Returns
    ///
    /// Returns a connected UnixStream on success.
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The socket doesn't exist (daemon not running)
    /// - Connection fails after all retry attempts
    ///
    /// Retry strategy:
    /// - Attempt 1: Immediate
    /// - Attempt 2: After 100ms delay
    /// - Attempt 3: After 200ms delay (total 300ms)
    /// - Attempt 4: After 400ms delay (total 700ms)
    pub async fn connect(&self) -> Result<UnixStream> {
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
                "Failed to connect to daemon at {} after {} attempts. Is the daemon running? Try 'secd' to start it.",
                self.socket_path.display(),
                self.max_retries
            )
        })
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

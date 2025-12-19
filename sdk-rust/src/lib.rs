//! F231-F235: Rust SDK for Secretariat
//!
//! Features:
//! - F231: Create sdk-rust/src/lib.rs file
//! - F232: Define pub struct Secretariat with socket path field
//! - F233: Define pub enum Error with variants for each error type
//! - F234: Implement pub fn get(&self, key: &str) -> Result<String, Error>
//! - F235: Use std::os::unix::net::UnixStream for connection
//!
//! # Secretariat Rust SDK
//!
//! A lightweight Rust client for the Secretariat secrets manager daemon.
//!
//! ## Example
//!
//! ```no_run
//! use secretariat::Secretariat;
//!
//! fn main() -> Result<(), secretariat::Error> {
//!     let client = Secretariat::new()?;
//!     let api_key = client.get("OPENAI_API_KEY")?;
//!     println!("API Key: {}", api_key);
//!     Ok(())
//! }
//! ```
//!
//! ## Features
//!
//! - Zero-copy where possible
//! - Sync API (async available with tokio feature)
//! - Result-based error handling
//! - Environment variable fallback

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::time::Duration;

// F235: Use std::os::unix::net::UnixStream for connection
#[cfg(unix)]
use std::os::unix::net::UnixStream;

/// F233: Define pub enum Error with variants for each error type
#[derive(Debug)]
pub enum Error {
    /// Failed to connect to the daemon
    ConnectionFailed(String),
    /// Request timed out
    Timeout,
    /// Failed to send request
    SendFailed(std::io::Error),
    /// Failed to receive response
    ReceiveFailed(std::io::Error),
    /// Failed to parse JSON response
    ParseFailed(String),
    /// Secret not found
    NotFound(String),
    /// Permission denied
    PermissionDenied(String),
    /// Invalid response from daemon
    InvalidResponse(String),
    /// RPC error from daemon
    RpcError { code: i32, message: String },
    /// Platform not supported
    UnsupportedPlatform,
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::ConnectionFailed(msg) => write!(f, "Connection failed: {}", msg),
            Error::Timeout => write!(f, "Request timed out"),
            Error::SendFailed(e) => write!(f, "Failed to send request: {}", e),
            Error::ReceiveFailed(e) => write!(f, "Failed to receive response: {}", e),
            Error::ParseFailed(msg) => write!(f, "Failed to parse response: {}", msg),
            Error::NotFound(key) => write!(f, "Secret not found: {}", key),
            Error::PermissionDenied(key) => write!(f, "Permission denied for secret: {}", key),
            Error::InvalidResponse(msg) => write!(f, "Invalid response: {}", msg),
            Error::RpcError { code, message } => write!(f, "RPC error ({}): {}", code, message),
            Error::UnsupportedPlatform => write!(f, "Platform not supported"),
        }
    }
}

impl std::error::Error for Error {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Error::SendFailed(e) | Error::ReceiveFailed(e) => Some(e),
            _ => None,
        }
    }
}

/// Default socket path on Unix systems
const DEFAULT_SOCKET_PATH: &str = "/tmp/secretariat.sock";

/// F232: Define pub struct Secretariat with socket path field
pub struct Secretariat {
    /// Path to Unix domain socket
    socket_path: PathBuf,
    /// Request timeout
    timeout: Duration,
    /// Request ID counter
    request_id: std::sync::atomic::AtomicU64,
}

impl Secretariat {
    /// Create a new Secretariat client with default settings.
    ///
    /// Uses the default socket path `/tmp/secretariat.sock` on Unix.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use secretariat::Secretariat;
    ///
    /// let client = Secretariat::new().expect("Failed to create client");
    /// ```
    pub fn new() -> Result<Self, Error> {
        Self::with_socket_path(DEFAULT_SOCKET_PATH)
    }

    /// Create a new Secretariat client with custom socket path.
    ///
    /// # Arguments
    ///
    /// * `path` - Path to Unix domain socket
    ///
    /// # Example
    ///
    /// ```no_run
    /// use secretariat::Secretariat;
    ///
    /// let client = Secretariat::with_socket_path("/custom/path.sock")
    ///     .expect("Failed to create client");
    /// ```
    pub fn with_socket_path<P: Into<PathBuf>>(path: P) -> Result<Self, Error> {
        Ok(Self {
            socket_path: path.into(),
            timeout: Duration::from_secs(5),
            request_id: std::sync::atomic::AtomicU64::new(0),
        })
    }

    /// Set request timeout.
    ///
    /// # Arguments
    ///
    /// * `timeout` - Request timeout duration
    pub fn set_timeout(&mut self, timeout: Duration) {
        self.timeout = timeout;
    }

    /// Connect to the daemon socket.
    #[cfg(unix)]
    fn connect(&self) -> Result<UnixStream, Error> {
        let stream = UnixStream::connect(&self.socket_path)
            .map_err(|e| Error::ConnectionFailed(e.to_string()))?;

        stream
            .set_read_timeout(Some(self.timeout))
            .map_err(|e| Error::ConnectionFailed(e.to_string()))?;

        stream
            .set_write_timeout(Some(self.timeout))
            .map_err(|e| Error::ConnectionFailed(e.to_string()))?;

        Ok(stream)
    }

    #[cfg(not(unix))]
    fn connect(&self) -> Result<std::net::TcpStream, Error> {
        // Windows named pipes would need different handling
        Err(Error::UnsupportedPlatform)
    }

    /// Send JSON-RPC request and receive response.
    fn send_request(
        &self,
        method: &str,
        params: serde_json::Value,
    ) -> Result<serde_json::Value, Error> {
        let mut stream = self.connect()?;

        let request_id = self
            .request_id
            .fetch_add(1, std::sync::atomic::Ordering::SeqCst);

        // Build JSON-RPC 2.0 request
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params,
        });

        // Send request
        let request_str = serde_json::to_string(&request)
            .map_err(|e| Error::ParseFailed(e.to_string()))?;

        stream
            .write_all(format!("{}\n", request_str).as_bytes())
            .map_err(Error::SendFailed)?;

        stream.flush().map_err(Error::SendFailed)?;

        // Read response
        let mut reader = BufReader::new(stream);
        let mut response_str = String::new();
        reader
            .read_line(&mut response_str)
            .map_err(Error::ReceiveFailed)?;

        // Parse response
        let response: serde_json::Value = serde_json::from_str(&response_str)
            .map_err(|e| Error::ParseFailed(e.to_string()))?;

        // Validate response ID
        if response["id"] != request_id {
            return Err(Error::InvalidResponse("Response ID mismatch".to_string()));
        }

        // Check for errors
        if let Some(error) = response.get("error") {
            let code = error["code"].as_i64().unwrap_or(-1) as i32;
            let message = error["message"]
                .as_str()
                .unwrap_or("Unknown error")
                .to_string();
            return Err(Error::RpcError { code, message });
        }

        // Return result
        response
            .get("result")
            .cloned()
            .ok_or_else(|| Error::InvalidResponse("Missing result".to_string()))
    }

    /// F234: Implement pub fn get(&self, key: &str) -> Result<String, Error>
    ///
    /// Get secret value by key.
    ///
    /// # Arguments
    ///
    /// * `key` - Secret name/key (e.g., "OPENAI_API_KEY")
    ///
    /// # Returns
    ///
    /// Returns the decrypted secret value.
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Cannot connect to daemon
    /// - Secret not found
    /// - Permission denied
    /// - Communication error
    ///
    /// # Example
    ///
    /// ```no_run
    /// use secretariat::Secretariat;
    ///
    /// let client = Secretariat::new().unwrap();
    /// let api_key = client.get("OPENAI_API_KEY").unwrap();
    /// println!("API Key: {}", api_key);
    /// ```
    pub fn get(&self, key: &str) -> Result<String, Error> {
        let params = serde_json::json!({ "key": key });
        let result = self.send_request("secret.get", params)?;

        result["value"]
            .as_str()
            .map(|s| s.to_string())
            .ok_or_else(|| Error::InvalidResponse("Missing value in response".to_string()))
    }

    /// Get multiple secrets at once.
    ///
    /// # Arguments
    ///
    /// * `keys` - Slice of secret names to retrieve
    ///
    /// # Returns
    ///
    /// Returns a HashMap of key -> value pairs.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use secretariat::Secretariat;
    ///
    /// let client = Secretariat::new().unwrap();
    /// let secrets = client.get_many(&["OPENAI_API_KEY", "DATABASE_URL"]).unwrap();
    /// println!("API Key: {}", secrets["OPENAI_API_KEY"]);
    /// ```
    pub fn get_many(&self, keys: &[&str]) -> Result<std::collections::HashMap<String, String>, Error> {
        let mut results = std::collections::HashMap::new();
        for key in keys {
            results.insert(key.to_string(), self.get(key)?);
        }
        Ok(results)
    }

    /// List all available secret names.
    ///
    /// # Returns
    ///
    /// Returns a Vec of secret names (not values).
    ///
    /// # Example
    ///
    /// ```no_run
    /// use secretariat::Secretariat;
    ///
    /// let client = Secretariat::new().unwrap();
    /// let names = client.list().unwrap();
    /// println!("Available secrets: {:?}", names);
    /// ```
    pub fn list(&self) -> Result<Vec<String>, Error> {
        let result = self.send_request("secret.list", serde_json::json!({}))?;

        let secrets = result["secrets"]
            .as_array()
            .ok_or_else(|| Error::InvalidResponse("Missing secrets in response".to_string()))?;

        secrets
            .iter()
            .map(|s| {
                s.as_str()
                    .map(|s| s.to_string())
                    .ok_or_else(|| Error::InvalidResponse("Invalid secret name".to_string()))
            })
            .collect()
    }
}

impl Default for Secretariat {
    fn default() -> Self {
        Self::new().expect("Failed to create Secretariat client")
    }
}

/// Get a secret with environment variable fallback.
///
/// Tries to get the secret from the daemon. If unavailable,
/// falls back to the environment variable.
///
/// # Arguments
///
/// * `key` - Secret name/key
///
/// # Returns
///
/// Returns the secret value from daemon or environment.
///
/// # Errors
///
/// Returns an error if neither daemon nor environment has the value.
///
/// # Example
///
/// ```no_run
/// use secretariat::get_or_env;
///
/// let api_key = get_or_env("OPENAI_API_KEY").unwrap();
/// ```
pub fn get_or_env(key: &str) -> Result<String, Error> {
    match Secretariat::new().and_then(|c| c.get(key)) {
        Ok(value) => Ok(value),
        Err(_) => std::env::var(key).map_err(|_| {
            Error::NotFound(format!(
                "Secret '{}' not found in daemon or environment",
                key
            ))
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = Error::NotFound("API_KEY".to_string());
        assert_eq!(err.to_string(), "Secret not found: API_KEY");

        let err = Error::RpcError {
            code: -32600,
            message: "Invalid request".to_string(),
        };
        assert_eq!(err.to_string(), "RPC error (-32600): Invalid request");
    }

    #[test]
    fn test_client_creation() {
        let client = Secretariat::with_socket_path("/custom/path.sock");
        assert!(client.is_ok());
    }
}

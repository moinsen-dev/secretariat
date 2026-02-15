//! IPC Server for Secretariat Daemon
//!
//! Provides Unix domain socket (macOS/Linux) and named pipe (Windows)
//! communication interface for clients to interact with the daemon.
//!
//! Implements JSON-RPC 2.0-inspired protocol for structured message handling.
//!
//! ## Wave 10 Features (Server Hardening):
//! - F046: 30-second idle timeout for connections
//! - F047: Graceful shutdown with connection draining
//! - F048: Request/response logging for debugging
//! - F049: Malformed JSON error handling
//! - F050: Rate limiting (100 req/sec per connection)

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::time::{Duration, Instant};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{broadcast, Mutex};
use tokio::time::timeout;
use tracing::{debug, error, info, warn, trace};

/// F046: Connection idle timeout (30 seconds)
const CONNECTION_IDLE_TIMEOUT: Duration = Duration::from_secs(30);

/// F047: Maximum time to wait for graceful shutdown (5 seconds)
const GRACEFUL_SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(5);

/// F050: Maximum requests per second per connection
const MAX_REQUESTS_PER_SECOND: usize = 100;

/// F050: Rate limiter using token bucket algorithm
struct RateLimiter {
    /// Maximum number of tokens (requests) allowed
    capacity: usize,
    /// Current number of available tokens
    tokens: usize,
    /// Last time tokens were refilled
    last_refill: Instant,
}

impl RateLimiter {
    /// Create a new rate limiter with specified capacity
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            tokens: capacity,
            last_refill: Instant::now(),
        }
    }

    /// Check if a request is allowed and consume a token if so
    ///
    /// Refills tokens based on elapsed time (1 token per 1/capacity seconds)
    fn allow_request(&mut self) -> bool {
        // Refill tokens based on elapsed time
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        let tokens_to_add = (elapsed * self.capacity as f64) as usize;

        if tokens_to_add > 0 {
            self.tokens = (self.tokens + tokens_to_add).min(self.capacity);
            self.last_refill = now;
        }

        // Check if we have tokens available
        if self.tokens > 0 {
            self.tokens -= 1;
            true
        } else {
            false
        }
    }
}

/// F047: Server state for graceful shutdown coordination
#[derive(Clone)]
pub struct ServerState {
    /// Number of active connections
    active_connections: Arc<AtomicUsize>,
    /// Broadcast channel for shutdown signal
    shutdown_tx: broadcast::Sender<()>,
    /// Shared reference to storage layer (protected by mutex for thread safety)
    storage: Arc<Mutex<crate::storage::Storage>>,
    /// Master encryption key (from keychain) - wrapped in RwLock for lock/unlock
    master_key: Arc<tokio::sync::RwLock<Option<[u8; 32]>>>,
    /// Whether the vault is currently locked
    is_locked: Arc<AtomicBool>,
}

impl ServerState {
    /// Create a new server state (vault starts unlocked)
    ///
    /// # Arguments
    ///
    /// * `storage` - Reference to the storage layer
    /// * `master_key` - The 32-byte master encryption key from keychain
    #[allow(dead_code)] // Used for testing and backwards compatibility
    pub fn new(storage: Arc<Mutex<crate::storage::Storage>>, master_key: [u8; 32]) -> Self {
        Self::new_with_lock_state(storage, master_key, false)
    }

    /// Create a new server state with explicit lock state
    ///
    /// # Arguments
    ///
    /// * `storage` - Reference to the storage layer
    /// * `master_key` - The 32-byte master encryption key (may be zeroed if locked)
    /// * `starts_locked` - Whether the vault starts in locked state
    pub fn new_with_lock_state(
        storage: Arc<Mutex<crate::storage::Storage>>,
        master_key: [u8; 32],
        starts_locked: bool,
    ) -> Self {
        let (shutdown_tx, _) = broadcast::channel(16);
        let initial_key = if starts_locked { None } else { Some(master_key) };

        Self {
            active_connections: Arc::new(AtomicUsize::new(0)),
            shutdown_tx,
            storage,
            master_key: Arc::new(tokio::sync::RwLock::new(initial_key)),
            is_locked: Arc::new(AtomicBool::new(starts_locked)),
        }
    }

    /// Increment active connection count
    fn connection_started(&self) {
        self.active_connections.fetch_add(1, Ordering::SeqCst);
    }

    /// Decrement active connection count
    fn connection_finished(&self) {
        self.active_connections.fetch_sub(1, Ordering::SeqCst);
    }

    /// Get current number of active connections
    pub fn active_connection_count(&self) -> usize {
        self.active_connections.load(Ordering::SeqCst)
    }

    /// Send shutdown signal to all connections
    pub fn shutdown(&self) {
        let _ = self.shutdown_tx.send(());
    }

    /// Subscribe to shutdown signal
    fn subscribe_shutdown(&self) -> broadcast::Receiver<()> {
        self.shutdown_tx.subscribe()
    }

    /// Lock the vault - clears master key from memory
    pub async fn lock_vault(&self) {
        let mut key_guard = self.master_key.write().await;
        // Zero out the key before clearing
        if let Some(ref mut key) = *key_guard {
            key.fill(0);
        }
        *key_guard = None;
        self.is_locked.store(true, Ordering::SeqCst);
        info!("Vault locked - master key cleared from memory");
    }

    /// Unlock the vault with a new master key
    pub async fn unlock_vault(&self, new_key: [u8; 32]) {
        let mut key_guard = self.master_key.write().await;
        *key_guard = Some(new_key);
        self.is_locked.store(false, Ordering::SeqCst);
        info!("Vault unlocked - master key loaded");
    }

    /// Check if the vault is locked
    pub fn is_vault_locked(&self) -> bool {
        self.is_locked.load(Ordering::SeqCst)
    }

    /// Get the master key if vault is unlocked
    pub async fn get_master_key(&self) -> Option<[u8; 32]> {
        let key_guard = self.master_key.read().await;
        *key_guard
    }
}

/// JSON-RPC request ID (can be string, number, or null per JSON-RPC 2.0 spec)
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(untagged)]
pub enum RequestId {
    String(String),
    Number(i64),
    Null,
}

impl std::fmt::Display for RequestId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RequestId::String(s) => write!(f, "{}", s),
            RequestId::Number(n) => write!(f, "{}", n),
            RequestId::Null => write!(f, "null"),
        }
    }
}

impl From<RequestId> for String {
    fn from(id: RequestId) -> Self {
        id.to_string()
    }
}

/// JSON-RPC request structure
///
/// Represents an incoming request from a client following JSON-RPC style.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Request {
    /// Unique request identifier (used to match request with response)
    /// Accepts string, number, or null per JSON-RPC 2.0 specification
    pub id: RequestId,
    /// Method name to invoke (e.g., "secret.get", "app.register")
    pub method: String,
    /// Method parameters as a JSON value
    pub params: serde_json::Value,
}

/// Error information for failed requests
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ErrorInfo {
    /// Error code (e.g., -32600 for invalid request, -32601 for method not found)
    pub code: i32,
    /// Human-readable error message
    pub message: String,
    /// Optional additional error data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
}

impl ErrorInfo {
    /// Create a new error with code and message
    pub fn new(code: i32, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            data: None,
        }
    }

    /// Create an error for invalid JSON parsing
    pub fn parse_error(message: impl Into<String>) -> Self {
        Self::new(-32700, message)
    }

    /// Create an error for invalid request structure
    #[allow(dead_code)] // Available for JSON-RPC protocol compliance
    pub fn invalid_request(message: impl Into<String>) -> Self {
        Self::new(-32600, message)
    }

    /// Create an error for unknown method
    pub fn method_not_found(method: &str) -> Self {
        Self::new(-32601, format!("Method not found: {}", method))
    }

    /// Create an error for invalid method parameters
    pub fn invalid_params(message: impl Into<String>) -> Self {
        Self::new(-32602, message)
    }

    /// Create a generic internal error
    pub fn internal_error(message: impl Into<String>) -> Self {
        Self::new(-32603, message)
    }
}

/// JSON-RPC response structure
///
/// Represents a response to a client request, containing either a result or an error.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Response {
    /// Request ID this response corresponds to
    pub id: RequestId,
    /// Successful result (mutually exclusive with error)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    /// Error information (mutually exclusive with result)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorInfo>,
}

impl Response {
    /// Create a successful response
    pub fn success(id: RequestId, result: serde_json::Value) -> Self {
        Self {
            id,
            result: Some(result),
            error: None,
        }
    }

    /// Create an error response
    pub fn error(id: RequestId, error: ErrorInfo) -> Self {
        Self {
            id,
            result: None,
            error: Some(error),
        }
    }
}

/// Get the platform-specific socket path
///
/// Returns:
/// - macOS: ~/Library/Application Support/Secretariat/secretariat.sock
/// - Linux: ~/.local/share/secretariat/secretariat.sock
/// - Windows: Will use named pipes (not implemented yet)
pub fn get_socket_path() -> Result<PathBuf> {
    if let Some(socket_path) = std::env::var_os("SECRETARIAT_SOCKET_PATH")
        .or_else(|| std::env::var_os("SECRETARIAT_SOCKET"))
    {
        return Ok(PathBuf::from(socket_path));
    }

    let socket_path = if cfg!(target_os = "macos") {
        dirs::home_dir()
            .context("Failed to get home directory")?
            .join("Library/Application Support/Secretariat/secretariat.sock")
    } else if cfg!(target_os = "linux") {
        dirs::home_dir()
            .context("Failed to get home directory")?
            .join(".local/share/secretariat/secretariat.sock")
    } else if cfg!(target_os = "windows") {
        // Windows is not yet supported
        anyhow::bail!(
            "Secretariat is not yet available for Windows.\n\
             Currently supported platforms: macOS, Linux.\n\
             Windows support (using named pipes) is planned for a future release.\n\
             For updates, visit: https://github.com/moinsen/secretariat"
        );
    } else {
        anyhow::bail!(
            "Unsupported operating system: {}.\n\
             Secretariat currently supports macOS and Linux only.",
            std::env::consts::OS
        );
    };

    Ok(socket_path)
}

/// Parse a JSON-RPC request from a string
///
/// # Arguments
///
/// * `json` - Raw JSON string to parse
///
/// # Returns
///
/// A parsed `Request` on success, or an error if parsing fails
///
/// # Errors
///
/// Returns an error if:
/// - The JSON is malformed
/// - Required fields are missing
/// - Field types don't match the expected structure
pub fn parse_request(json: &str) -> Result<Request> {
    serde_json::from_str(json)
        .context("Failed to parse JSON-RPC request")
}

/// Send a response to the client
///
/// Serializes the response to JSON and writes it to the stream with a newline delimiter.
///
/// # Arguments
///
/// * `response` - The response to send
/// * `stream` - The Unix stream to write to
///
/// # Returns
///
/// Ok(()) on success
///
/// # Errors
///
/// Returns an error if:
/// - JSON serialization fails
/// - Writing to the stream fails
/// - Flushing the stream fails
pub async fn send_response(response: Response, stream: &mut UnixStream) -> Result<()> {
    let json = serde_json::to_string(&response)
        .context("Failed to serialize response to JSON")?;

    // F048: Log response at trace level for debugging
    trace!("IPC Response [id={}]: {}", response.id, json);

    // Send response with newline delimiter
    stream.write_all(json.as_bytes()).await
        .context("Failed to write response to stream")?;
    stream.write_all(b"\n").await
        .context("Failed to write newline delimiter")?;
    stream.flush().await
        .context("Failed to flush stream")?;

    debug!("Sent response for request ID: {}", response.id);

    Ok(())
}

/// Route a request to the appropriate handler function
///
/// Dispatches method calls to their corresponding handler functions.
///
/// # Supported Methods
///
/// - `secret.list` - List all secrets (names only)
/// - `secret.get` - Get secret value (requires app authorization)
/// - `secret.set` - Create/update secret
/// - `secret.delete` - Delete secret
/// - `secret.rotate` - Rotate secret value
/// - `app.register` - Register application for access
/// - `app.authorize` - Grant app access to secrets
/// - `app.revoke` - Revoke app access
/// - `app.list` - List registered applications
/// - `audit.log` - Get access audit log
/// - `health.check` - Daemon health status
///
/// # Arguments
///
/// * `request` - The parsed request to route
/// * `storage` - Reference to the storage layer (locked mutex guard)
/// * `master_key` - The 32-byte master encryption key from keychain
///
/// # Returns
///
/// A response containing either the result or an error
///
/// This is the top-level async request handler that coordinates:
/// 1. Checking vault lock state
/// 2. Getting master key (async)
/// 3. Calling vault.lock/unlock (async for server state update)
/// 4. Locking storage and calling sync route_request for other methods
async fn handle_request(request: Request, server_state: &ServerState) -> Response {
    debug!("Handling request: method={}, id={}", request.method, request.id);

    // Check vault lock state for operations that need the master key
    let requires_unlock = matches!(
        request.method.as_str(),
        "secret.get" | "secret.set" | "secret.delete" | "secret.rotate"
    );

    if requires_unlock && server_state.is_vault_locked() {
        return Response::error(
            request.id,
            ErrorInfo::new(-32002, "Vault is locked. Please unlock first with 'sec unlock'")
        );
    }

    // Handle vault.lock specially - async operation
    if request.method == "vault.lock" {
        if server_state.is_vault_locked() {
            return Response::success(
                request.id,
                serde_json::json!({
                    "status": "already_locked"
                })
            );
        }
        server_state.lock_vault().await;
        return Response::success(
            request.id,
            serde_json::json!({
                "status": "locked"
            })
        );
    }

    // Handle vault.unlock specially - async operation
    if request.method == "vault.unlock" {
        if !server_state.is_vault_locked() {
            return Response::success(
                request.id,
                serde_json::json!({
                    "status": "already_unlocked"
                })
            );
        }

        let password = match request.params.get("password").and_then(|v| v.as_str()) {
            Some(p) => p,
            None => {
                return Response::error(
                    request.id,
                    ErrorInfo::invalid_params("Missing required parameter: password")
                );
            }
        };

        // Optional: store master key in keychain for biometric unlock
        let store_for_biometric = request.params.get("store_for_biometric")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

        // Need storage for password verification
        let storage = server_state.storage.lock().await;
        match crate::handlers::handle_vault_unlock(password, &storage) {
            Ok(result) => {
                drop(storage); // Release storage lock before async operation

                // Store master key in keychain for Touch ID if requested
                let biometric_enabled = if store_for_biometric {
                    match crate::keychain::store_master_key(&result.master_key) {
                        Ok(()) => {
                            tracing::info!("Master key stored in keychain for biometric unlock");
                            true
                        }
                        Err(e) => {
                            tracing::warn!("Failed to store key in keychain: {}", e);
                            false
                        }
                    }
                } else {
                    false
                };

                server_state.unlock_vault(result.master_key).await;
                return Response::success(
                    request.id,
                    serde_json::json!({
                        "status": "unlocked",
                        "biometric_enabled": biometric_enabled
                    })
                );
            },
            Err(e) => {
                return Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to unlock vault: {}", e))
                );
            }
        }
    }

    // Handle vault.unlock_biometric - unlock using keychain-stored master key
    if request.method == "vault.unlock_biometric" {
        if !server_state.is_vault_locked() {
            return Response::success(
                request.id,
                serde_json::json!({
                    "status": "already_unlocked"
                })
            );
        }

        // Retrieve master key from keychain (requires Touch ID / system auth)
        match crate::keychain::retrieve_master_key() {
            Ok(master_key) => {
                server_state.unlock_vault(master_key).await;
                tracing::info!("Vault unlocked via biometric authentication");
                return Response::success(
                    request.id,
                    serde_json::json!({
                        "status": "unlocked",
                        "method": "biometric"
                    })
                );
            }
            Err(e) => {
                tracing::warn!("Biometric unlock failed: {}", e);
                return Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!(
                        "Biometric unlock failed: {}. Please use password unlock.",
                        e
                    ))
                );
            }
        }
    }

    // Handle vault.biometric_status - check if biometric unlock is available
    if request.method == "vault.biometric_status" {
        // Check if we're on macOS and if a master key is stored in keychain
        let is_available = crate::keychain::is_biometric_available();
        let is_enabled = if is_available {
            // Try to check if key exists in keychain without actually retrieving it
            // For now, we just report if biometric hardware is available
            // The actual key retrieval will trigger Touch ID
            crate::keychain::retrieve_master_key().is_ok()
        } else {
            false
        };

        return Response::success(
            request.id,
            serde_json::json!({
                "available": is_available,
                "enabled": is_enabled,
                "platform": std::env::consts::OS
            })
        );
    }

    // Handle vault.biometric_disable - remove stored key from keychain
    if request.method == "vault.biometric_disable" {
        match crate::keychain::delete_master_key() {
            Ok(()) => {
                tracing::info!("Biometric unlock disabled - master key removed from keychain");
                return Response::success(
                    request.id,
                    serde_json::json!({
                        "status": "disabled"
                    })
                );
            }
            Err(e) => {
                return Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to disable biometric: {}", e))
                );
            }
        }
    }

    // Handle vault.panic - Security Kill-Switch
    // Revokes ALL permissions, locks vault, clears master key, disables biometric
    if request.method == "vault.panic" {
        tracing::warn!("SECURITY: vault.panic command received - initiating emergency lockdown");

        // Lock storage and execute panic
        let storage = server_state.storage.lock().await;
        let panic_result = match crate::handlers::handle_vault_panic(&storage) {
            Ok(result) => result,
            Err(e) => {
                return Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to execute panic: {}", e))
                );
            }
        };
        drop(storage); // Release storage lock before async operations

        // Lock the vault (clear master key from memory)
        server_state.lock_vault().await;

        // Delete master key from keychain (disable biometric)
        let biometric_disabled = match crate::keychain::delete_master_key() {
            Ok(()) => {
                tracing::info!("Biometric disabled during panic - master key removed from keychain");
                true
            }
            Err(e) => {
                tracing::warn!("Failed to disable biometric during panic: {}", e);
                false
            }
        };

        tracing::warn!(
            "SECURITY: Panic complete. Revoked {} permissions for {} apps. Vault locked.",
            panic_result.permissions_revoked,
            panic_result.apps_affected
        );

        return Response::success(
            request.id,
            serde_json::json!({
                "status": "panic_executed",
                "permissions_revoked": panic_result.permissions_revoked,
                "apps_affected": panic_result.apps_affected,
                "vault_locked": true,
                "biometric_disabled": biometric_disabled
            })
        );
    }

    // Handle vault.change_password specially - async operation to update master key
    if request.method == "vault.change_password" {
        if server_state.is_vault_locked() {
            return Response::error(
                request.id,
                ErrorInfo::internal_error("Vault is locked. Unlock first before changing password.")
            );
        }

        let current_password = match request.params.get("current_password").and_then(|v| v.as_str()) {
            Some(p) => p,
            None => {
                return Response::error(
                    request.id,
                    ErrorInfo::invalid_params("Missing required parameter: current_password")
                );
            }
        };

        let new_password = match request.params.get("new_password").and_then(|v| v.as_str()) {
            Some(p) => p,
            None => {
                return Response::error(
                    request.id,
                    ErrorInfo::invalid_params("Missing required parameter: new_password")
                );
            }
        };

        let storage = server_state.storage.lock().await;
        match crate::handlers::handle_vault_change_password(current_password, new_password, &storage) {
            Ok(result) => {
                drop(storage); // Release storage lock before async operation
                // Update server state with new master key
                server_state.unlock_vault(result.new_master_key).await;
                return Response::success(
                    request.id,
                    serde_json::json!({
                        "secrets_migrated": result.secrets_migrated,
                        "status": "password_changed"
                    })
                );
            },
            Err(e) => {
                return Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to change password: {}", e))
                );
            }
        }
    }

    // Get master key (may be None if locked)
    let master_key_opt = server_state.get_master_key().await;

    // Lock storage and call sync route_request
    let storage = server_state.storage.lock().await;
    route_request(request, &storage, &master_key_opt, server_state.is_vault_locked())
}

/// Route request to the appropriate handler (synchronous)
fn route_request(
    request: Request,
    storage: &crate::storage::Storage,
    master_key_opt: &Option<[u8; 32]>,
    is_locked: bool,
) -> Response {

    match request.method.as_str() {
        "secret.list" => {
            // F053-F055: Call actual secret.list handler
            match crate::handlers::handle_secret_list(storage) {
                Ok(secrets) => Response::success(
                    request.id,
                    serde_json::json!({
                        "secrets": secrets
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to list secrets: {}", e))
                ),
            }
        }
        "secret.get" => {
            // F057-F062: Call actual secret.get handler with permission checks and decryption
            // Extract parameters from request
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            let app_id = match request.params.get("app_id").and_then(|v| v.as_str()) {
                Some(a) => a,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: app_id")
                    );
                }
            };

            // master_key is guaranteed to be Some since we checked requires_unlock above
            let master_key = master_key_opt.as_ref().unwrap();
            match crate::handlers::handle_secret_get(name, app_id, storage, master_key) {
                Ok(decrypted_value) => Response::success(
                    request.id,
                    serde_json::json!({
                        "name": name,
                        "value": decrypted_value
                    })
                ),
                Err(e) => {
                    // F059: Check if this is a PermissionDenied error
                    if let Some(_perm_err) = e.downcast_ref::<crate::handlers::PermissionDeniedError>() {
                        Response::error(
                            request.id,
                            ErrorInfo::new(-32001, format!("Permission denied: {}", e))
                        )
                    } else {
                        Response::error(
                            request.id,
                            ErrorInfo::internal_error(format!("Failed to get secret: {}", e))
                        )
                    }
                }
            }
        }
        "secret.set" => {
            // F063-F065: Call actual secret.set handler with encryption
            // Extract parameters from request
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            let value = match request.params.get("value").and_then(|v| v.as_str()) {
                Some(v) => v,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: value")
                    );
                }
            };

            // Extract optional environment, provider, and ttl parameters
            let environment = request.params.get("environment").and_then(|v| v.as_str());
            let provider = request.params.get("provider").and_then(|v| v.as_str());
            let ttl_seconds = request.params.get("ttl").and_then(|v| v.as_u64());

            // master_key is guaranteed to be Some since we checked requires_unlock above
            let master_key = master_key_opt.as_ref().unwrap();
            match crate::handlers::handle_secret_set(name, value, storage, master_key, environment, provider, ttl_seconds) {
                Ok(()) => {
                    let mut response_data = serde_json::json!({
                        "name": name,
                        "status": if ttl_seconds.is_some() { "created_ephemeral" } else { "created" },
                        "environment": environment.unwrap_or("default")
                    });
                    if let Some(ttl) = ttl_seconds {
                        response_data["ttl_seconds"] = serde_json::json!(ttl);
                    }
                    Response::success(request.id, response_data)
                }
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to set secret: {}", e))
                ),
            }
        }
        "secret.delete" => {
            // F068-F070: Call actual secret.delete handler with cascade
            // Extract parameters from request
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            match crate::handlers::handle_secret_delete(name, storage) {
                Ok(()) => Response::success(
                    request.id,
                    serde_json::json!({
                        "name": name,
                        "status": "deleted"
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to delete secret: {}", e))
                ),
            }
        }
        "secret.rotate" => {
            // Secret rotation with version tracking
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            let new_value = match request.params.get("value").and_then(|v| v.as_str()) {
                Some(v) => v,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: value")
                    );
                }
            };

            // master_key is guaranteed to be Some since we checked requires_unlock above
            let master_key = master_key_opt.as_ref().unwrap();
            match crate::handlers::handle_secret_rotate(name, new_value, storage, master_key) {
                Ok(result) => Response::success(
                    request.id,
                    serde_json::json!({
                        "name": result.name,
                        "version": result.version,
                        "status": result.status
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to rotate secret: {}", e))
                ),
            }
        }
        "secret.rollback" => {
            // Rollback a secret to its previous version
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            match storage.rollback_secret(name) {
                Ok(new_version) => {
                    // Log the rollback
                    let _ = storage.log_audit("system", name, "rollback", true,
                        Some(&format!("Rolled back to version {}", new_version)));
                    Response::success(
                        request.id,
                        serde_json::json!({
                            "name": name,
                            "version": new_version,
                            "status": "rolled_back"
                        })
                    )
                },
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to rollback secret: {}", e))
                ),
            }
        }
        "secret.history" => {
            // Get secret version history
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };

            match storage.get_secret_history(name) {
                Ok(Some((version, has_previous, rotated_at))) => Response::success(
                    request.id,
                    serde_json::json!({
                        "name": name,
                        "version": version,
                        "has_previous": has_previous,
                        "can_rollback": has_previous,
                        "rotated_at": rotated_at
                    })
                ),
                Ok(None) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Secret '{}' not found", name))
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to get secret history: {}", e))
                ),
            }
        }
        "secret.rotation_reminders" => {
            // Get secrets needing rotation
            let days = request.params.get("days")
                .and_then(|v| v.as_u64())
                .unwrap_or(90); // Default: 90 days

            match storage.get_secrets_needing_rotation(days) {
                Ok(secrets) => Response::success(
                    request.id,
                    serde_json::json!({
                        "secrets": secrets,
                        "threshold_days": days,
                        "count": secrets.len()
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to get rotation reminders: {}", e))
                ),
            }
        }
        "app.register" => {
            // F071-F075: Call actual app.register handler with process extraction
            // Extract parameters from request
            let pid = match request.params.get("pid").and_then(|v| v.as_u64()) {
                Some(p) => p as u32,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: pid")
                    );
                }
            };

            match crate::handlers::handle_app_register(pid, storage) {
                Ok(app_info) => Response::success(
                    request.id,
                    serde_json::json!({
                        "app_id": app_info.fingerprint,
                        "name": app_info.name,
                        "path": app_info.path,
                        "bundle_id": app_info.bundle_id,
                        "fingerprint": app_info.fingerprint
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to register app: {}", e))
                ),
            }
        }
        "app.authorize" => {
            // F077-F080: Call actual app.authorize handler with validation
            // Extract parameters from request
            let app_id = match request.params.get("app_id").and_then(|v| v.as_str()) {
                Some(a) => a,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: app_id")
                    );
                }
            };

            let secret_name = match request.params.get("secret_name").and_then(|v| v.as_str()) {
                Some(s) => s,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: secret_name")
                    );
                }
            };

            match crate::handlers::handle_app_authorize(app_id, secret_name, storage) {
                Ok(()) => Response::success(
                    request.id,
                    serde_json::json!({
                        "app_id": app_id,
                        "secret_name": secret_name,
                        "status": "authorized"
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to authorize app: {}", e))
                ),
            }
        }
        "app.revoke" => {
            // Call actual app.revoke handler with permission deletion and audit logging
            let app_id = match request.params.get("app_id").and_then(|v| v.as_str()) {
                Some(a) => a,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: app_id")
                    );
                }
            };

            let secret_name = match request.params.get("secret_name").and_then(|v| v.as_str()) {
                Some(s) => s,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: secret_name")
                    );
                }
            };

            match crate::handlers::handle_app_revoke(app_id, secret_name, storage) {
                Ok(()) => Response::success(
                    request.id,
                    serde_json::json!({
                        "app_id": app_id,
                        "secret_name": secret_name,
                        "status": "revoked"
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to revoke app access: {}", e))
                ),
            }
        }
        "app.list" => {
            // Call actual app.list handler to get registered applications
            match crate::handlers::handle_app_list(storage) {
                Ok(apps) => Response::success(
                    request.id,
                    serde_json::json!({
                        "apps": apps
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to list apps: {}", e))
                ),
            }
        }
        "audit.log" => {
            // F082-F084: Call actual audit log query handler
            // Extract optional parameters from request
            let app_filter = request.params.get("app_id").and_then(|v| v.as_str());
            let limit = request.params.get("limit")
                .and_then(|v| v.as_u64())
                .unwrap_or(100) as usize; // Default to 100 entries

            match storage.query_audit_log(app_filter, limit) {
                Ok(entries) => Response::success(
                    request.id,
                    serde_json::json!({
                        "entries": entries
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to query audit log: {}", e))
                ),
            }
        }
        // AI Agent Access Control Commands
        "agent.register" => {
            let name = match request.params.get("name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: name")
                    );
                }
            };
            let agent_type = request.params.get("type")
                .and_then(|v| v.as_str())
                .unwrap_or("ai-assistant");

            match crate::handlers::handle_agent_register(storage, name, agent_type) {
                Ok(result) => Response::success(request.id, serde_json::to_value(result).unwrap()),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to register agent: {}", e))
                ),
            }
        }
        "agent.list" => {
            match crate::handlers::handle_agent_list(storage) {
                Ok(agents) => Response::success(
                    request.id,
                    serde_json::json!({ "agents": agents })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to list agents: {}", e))
                ),
            }
        }
        "agent.grant" => {
            let agent_id = match request.params.get("agent_id").and_then(|v| v.as_str()) {
                Some(id) => id,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: agent_id")
                    );
                }
            };
            let secret_name = match request.params.get("secret_name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: secret_name")
                    );
                }
            };
            let environment = request.params.get("environment").and_then(|v| v.as_str());

            match crate::handlers::handle_agent_grant(storage, agent_id, secret_name, environment) {
                Ok(result) => Response::success(request.id, serde_json::to_value(result).unwrap()),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to grant agent access: {}", e))
                ),
            }
        }
        "agent.revoke" => {
            let agent_id = match request.params.get("agent_id").and_then(|v| v.as_str()) {
                Some(id) => id,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: agent_id")
                    );
                }
            };
            let secret_name = match request.params.get("secret_name").and_then(|v| v.as_str()) {
                Some(n) => n,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: secret_name")
                    );
                }
            };

            match crate::handlers::handle_agent_revoke(storage, agent_id, secret_name) {
                Ok(result) => Response::success(request.id, serde_json::to_value(result).unwrap()),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to revoke agent access: {}", e))
                ),
            }
        }
        "agent.revoke_all" => {
            let agent_id = match request.params.get("agent_id").and_then(|v| v.as_str()) {
                Some(id) => id,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: agent_id")
                    );
                }
            };

            match crate::handlers::handle_agent_revoke_all(storage, agent_id) {
                Ok(result) => Response::success(request.id, serde_json::to_value(result).unwrap()),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to revoke all agent access: {}", e))
                ),
            }
        }
        "agent.explain" => {
            let agent_id = match request.params.get("agent_id").and_then(|v| v.as_str()) {
                Some(id) => id,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: agent_id")
                    );
                }
            };

            match crate::handlers::handle_agent_explain(storage, agent_id) {
                Ok(permissions) => Response::success(
                    request.id,
                    serde_json::json!({
                        "agent_id": agent_id,
                        "permissions": permissions.iter().map(|(s, e)| {
                            serde_json::json!({ "secret": s, "environment": e })
                        }).collect::<Vec<_>>()
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to explain agent permissions: {}", e))
                ),
            }
        }
        "health.check" => {
            // Health check returns daemon status
            Response::success(
                request.id,
                serde_json::json!({
                    "status": "healthy",
                    "version": env!("CARGO_PKG_VERSION")
                })
            )
        }
        "vault.init" => {
            // Initialize vault with master password
            let password = match request.params.get("password").and_then(|v| v.as_str()) {
                Some(p) => p,
                None => {
                    return Response::error(
                        request.id,
                        ErrorInfo::invalid_params("Missing required parameter: password")
                    );
                }
            };

            // Pass current master_key for re-encryption if secrets exist
            let old_key = if storage.has_secrets().unwrap_or(false) {
                master_key_opt.as_ref()
            } else {
                None
            };

            match crate::handlers::handle_vault_init(password, storage, old_key) {
                Ok(result) => Response::success(
                    request.id,
                    serde_json::json!({
                        "vault_path": result.vault_path,
                        "secrets_migrated": result.secrets_migrated
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to initialize vault: {}", e))
                ),
            }
        }
        // vault.lock, vault.unlock, vault.unlock_biometric, vault.change_password are handled in handle_request (async operations)
        "vault.lock" | "vault.unlock" | "vault.unlock_biometric" => {
            // Should not reach here - handled in handle_request
            Response::error(
                request.id,
                ErrorInfo::internal_error("Method should be handled by async handler")
            )
        }
        "vault.status" => {
            // Get vault status (state, secret count, app count)
            // is_locked is passed from handle_request
            match crate::handlers::handle_vault_status(storage, is_locked) {
                Ok(result) => Response::success(
                    request.id,
                    serde_json::json!({
                        "state": result.state.to_string(),
                        "secret_count": result.secret_count,
                        "app_count": result.app_count
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to get vault status: {}", e))
                ),
            }
        }
        // vault.change_password is handled in handle_request (async operation for state update)
        "vault.change_password" => {
            Response::error(
                request.id,
                ErrorInfo::internal_error("Method should be handled by async handler")
            )
        }
        "secret.cleanup" => {
            // Cleanup expired ephemeral secrets
            match storage.cleanup_expired_secrets() {
                Ok(count) => Response::success(
                    request.id,
                    serde_json::json!({
                        "status": "cleaned",
                        "removed_count": count
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to cleanup expired secrets: {}", e))
                ),
            }
        }
        "secret.expiring" => {
            // Get secrets expiring soon
            let within_seconds = request.params.get("within_seconds")
                .and_then(|v| v.as_u64())
                .unwrap_or(3600); // Default: 1 hour

            match storage.get_expiring_secrets(within_seconds) {
                Ok(secrets) => Response::success(
                    request.id,
                    serde_json::json!({
                        "secrets": secrets.iter().map(|(name, expires)| {
                            serde_json::json!({ "name": name, "expires_at": expires })
                        }).collect::<Vec<_>>(),
                        "within_seconds": within_seconds
                    })
                ),
                Err(e) => Response::error(
                    request.id,
                    ErrorInfo::internal_error(format!("Failed to get expiring secrets: {}", e))
                ),
            }
        }
        _ => {
            // Unknown method
            Response::error(
                request.id,
                ErrorInfo::method_not_found(&request.method)
            )
        }
    }
}

/// Handle a single client connection
///
/// Reads requests from the stream, routes them to handlers, and sends responses.
/// Handles connection lifecycle and error recovery gracefully.
///
/// # Wave 10 Features:
/// - F046: 30-second idle timeout for connections
/// - F047: Graceful shutdown signal handling
/// - F048: Request logging at debug level
/// - F049: Malformed JSON error handling
/// - F050: Rate limiting (100 req/sec)
///
/// # Arguments
///
/// * `mut stream` - The Unix stream for this connection
/// * `server_state` - Server state for shutdown coordination
async fn handle_connection(mut stream: UnixStream, server_state: ServerState) {
    debug!("New connection established");

    // F047: Track active connection
    server_state.connection_started();
    let _guard = ConnectionGuard::new(server_state.clone());

    // F047: Subscribe to shutdown signal
    let mut shutdown_rx = server_state.subscribe_shutdown();

    // F050: Initialize rate limiter (100 requests per second)
    let mut rate_limiter = RateLimiter::new(MAX_REQUESTS_PER_SECOND);

    // Buffer for reading data
    let mut buffer = vec![0u8; 4096];
    let mut accumulated = String::new();

    loop {
        // F046: Apply idle timeout to read operation
        let read_result = timeout(CONNECTION_IDLE_TIMEOUT, stream.read(&mut buffer)).await;

        tokio::select! {
            // F047: Check for shutdown signal
            _ = shutdown_rx.recv() => {
                info!("Connection received shutdown signal, closing gracefully");
                break;
            }
            // Handle read operation with timeout
            result = async { read_result } => {
                match result {
                    // F046: Timeout occurred
                    Err(_) => {
                        warn!("Connection idle timeout ({}s), closing connection", CONNECTION_IDLE_TIMEOUT.as_secs());
                        break;
                    }
                    Ok(read_result) => {
                        match read_result {
                            Ok(0) => {
                                // Connection closed by client
                                debug!("Connection closed by client");
                                break;
                            }
                            Ok(n) => {
                                // Append received data to accumulated buffer
                                match std::str::from_utf8(&buffer[..n]) {
                                    Ok(data) => {
                                        accumulated.push_str(data);

                                        // Process all complete messages (delimited by newlines)
                                        while let Some(newline_pos) = accumulated.find('\n') {
                                            let message = accumulated[..newline_pos].trim().to_string();
                                            accumulated = accumulated[newline_pos + 1..].to_string();

                                            if message.is_empty() {
                                                continue;
                                            }

                                            // F048: Log incoming request at debug level
                                            debug!("IPC Request: {}", message);

                                            // F050: Check rate limit
                                            if !rate_limiter.allow_request() {
                                                warn!("Rate limit exceeded, rejecting request");
                                                let response = Response::error(
                                                    RequestId::Null,
                                                    ErrorInfo::new(-32000, "Rate limit exceeded. Maximum 100 requests per second.")
                                                );
                                                if let Err(e) = send_response(response, &mut stream).await {
                                                    error!("Failed to send rate limit error: {}", e);
                                                    break;
                                                }
                                                continue;
                                            }

                                            // F049: Parse request with improved error handling
                                            let response = match parse_request(&message) {
                                                Ok(request) => {
                                                    // Handle the request - this may need async for vault lock/unlock
                                                    handle_request(request, &server_state).await
                                                }
                                                Err(e) => {
                                                    // F049: Handle malformed JSON with descriptive error
                                                    error!("Failed to parse request (malformed JSON): {}", e);
                                                    Response::error(
                                                        RequestId::Null,
                                                        ErrorInfo::parse_error(format!("Malformed JSON request: {}", e))
                                                    )
                                                }
                                            };

                                            // Send response
                                            if let Err(e) = send_response(response, &mut stream).await {
                                                error!("Failed to send response: {}", e);
                                                break;
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        // F049: Handle invalid UTF-8 with error response
                                        error!("Received invalid UTF-8 data: {}", e);
                                        let response = Response::error(
                                            RequestId::Null,
                                            ErrorInfo::parse_error("Invalid UTF-8 encoding in request")
                                        );
                                        if let Err(e) = send_response(response, &mut stream).await {
                                            error!("Failed to send UTF-8 error response: {}", e);
                                        }
                                        break;
                                    }
                                }
                            }
                            Err(e) => {
                                error!("Error reading from stream: {}", e);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    debug!("Connection handler finished");
}

/// F047: RAII guard to ensure connection count is decremented
struct ConnectionGuard {
    server_state: ServerState,
}

impl ConnectionGuard {
    fn new(server_state: ServerState) -> Self {
        Self { server_state }
    }
}

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        self.server_state.connection_finished();
    }
}

/// Start the IPC server and accept connections
///
/// Creates the socket parent directory if needed, removes any stale socket file,
/// binds a UnixListener to the socket path, and spawns concurrent handlers for
/// each incoming connection.
///
/// # Returns
///
/// A bound `UnixListener` ready to accept connections
///
/// # Errors
///
/// Returns an error if:
/// - The socket parent directory cannot be created
/// - A stale socket file cannot be removed
/// - The listener cannot bind to the socket path
pub async fn start_server() -> Result<UnixListener> {
    let socket_path = get_socket_path()
        .context("Failed to determine socket path")?;

    info!("Starting IPC server at: {}", socket_path.display());

    // Create socket parent directory if it doesn't exist
    if let Some(parent) = socket_path.parent() {
        if !parent.exists() {
            info!("Creating socket directory: {}", parent.display());
            std::fs::create_dir_all(parent)
                .context("Failed to create socket parent directory")?;
        }
        // SECURITY: Ensure directory is user-only (0o700)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let dir_permissions = std::fs::Permissions::from_mode(0o700);
            std::fs::set_permissions(parent, dir_permissions)
                .context("Failed to set socket directory permissions")?;
        }
    }

    // Remove stale socket file if it exists
    if socket_path.exists() {
        warn!("Removing stale socket file: {}", socket_path.display());
        std::fs::remove_file(&socket_path)
            .context("Failed to remove stale socket file")?;
    }

    // Bind UnixListener to socket path
    let listener = UnixListener::bind(&socket_path)
        .context("Failed to bind UnixListener to socket path")?;

    // SECURITY: Set socket permissions to user-only (0o600)
    // This prevents other users on the system from connecting to the socket
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let permissions = std::fs::Permissions::from_mode(0o600);
        std::fs::set_permissions(&socket_path, permissions)
            .context("Failed to set socket permissions")?;
        info!("Socket permissions set to 0600 (user-only access)");
    }

    info!("IPC server listening on: {}", socket_path.display());

    Ok(listener)
}

/// Run the accept loop, spawning a task for each connection
///
/// Accepts incoming connections and spawns a new tokio task for each one,
/// enabling concurrent request handling.
///
/// # Wave 10 Features:
/// - F047: Graceful shutdown with connection draining
///
/// # Arguments
///
/// * `listener` - The Unix listener to accept connections from
/// * `server_state` - Server state for shutdown coordination
///
/// # Returns
///
/// Never returns normally (runs until error or shutdown signal)
///
/// # Errors
///
/// Returns an error if accepting a connection fails critically
pub async fn accept_loop(listener: UnixListener, server_state: ServerState) -> Result<()> {
    info!("Accept loop started, waiting for connections...");

    loop {
        match listener.accept().await {
            Ok((stream, _addr)) => {
                debug!("Accepted new connection");

                // Clone server state for this connection
                let state = server_state.clone();

                // Spawn a new task to handle this connection concurrently
                tokio::spawn(async move {
                    handle_connection(stream, state).await;
                });
            }
            Err(e) => {
                error!("Failed to accept connection: {}", e);
                // Continue accepting other connections despite this error
                continue;
            }
        }
    }
}

/// F047: Gracefully shutdown the server
///
/// Sends shutdown signal to all active connections and waits for them to finish.
/// If connections don't finish within GRACEFUL_SHUTDOWN_TIMEOUT, they are forcefully closed.
///
/// # Arguments
///
/// * `server_state` - Server state for shutdown coordination
/// * `socket_path` - Path to the Unix socket (for cleanup)
pub async fn graceful_shutdown(server_state: ServerState, socket_path: PathBuf) {
    info!("Initiating graceful shutdown...");

    // Send shutdown signal to all active connections
    server_state.shutdown();

    // Wait for active connections to finish (with timeout)
    let start = Instant::now();
    let mut check_interval = tokio::time::interval(Duration::from_millis(100));

    while server_state.active_connection_count() > 0 {
        // Check if we've exceeded the shutdown timeout
        if start.elapsed() >= GRACEFUL_SHUTDOWN_TIMEOUT {
            warn!(
                "Graceful shutdown timeout exceeded ({:?}), {} connections still active",
                GRACEFUL_SHUTDOWN_TIMEOUT,
                server_state.active_connection_count()
            );
            break;
        }

        // Wait a bit before checking again
        check_interval.tick().await;
        debug!(
            "Waiting for {} active connections to close...",
            server_state.active_connection_count()
        );
    }

    if server_state.active_connection_count() == 0 {
        info!("All connections closed gracefully");
    }

    // Clean up socket file
    if socket_path.exists() {
        if let Err(e) = std::fs::remove_file(&socket_path) {
            warn!("Failed to remove socket file during shutdown: {}", e);
        } else {
            info!("Socket file removed: {}", socket_path.display());
        }
    }

    info!("Graceful shutdown complete");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_socket_path() {
        let socket_path = get_socket_path().expect("Failed to get socket path");

        #[cfg(target_os = "macos")]
        assert!(socket_path.to_string_lossy().contains("Library/Application Support/Secretariat"));

        #[cfg(target_os = "linux")]
        assert!(socket_path.to_string_lossy().contains(".local/share/secretariat"));

        assert!(socket_path.to_string_lossy().ends_with("secretariat.sock"));
    }

    #[tokio::test]
    async fn test_start_server() {
        // This test would create a real socket, so we'll keep it minimal
        // In a real test suite, we'd use a temporary directory
        // For now, just verify the function signature compiles
        // let listener = start_server().await.expect("Failed to start server");
        // Clean up would be needed here
    }
}

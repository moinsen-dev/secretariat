//! Handler modules for daemon IPC methods
//!
//! This module organizes all handler functions that process JSON-RPC requests
//! from clients. Each handler corresponds to a specific API method.
//!
//! ## Wave 11 Features:
//! - F051: Create handlers/mod.rs to organize handler modules
//!
//! ## Wave 12 Features:
//! - F056: Add secret_get module
//!
//! ## Wave 13 Features:
//! - F063: Add secret_set module
//!
//! ## Wave 14 Features:
//! - F068: Add secret_delete module
//! - F071: Add app_register module
//!
//! ## Wave 15 Features:
//! - F077: Add app_authorize module
//!
//! ## Vault Features:
//! - vault_init: Initialize vault with master password

pub mod secret_list;
pub mod secret_get;
pub mod secret_set;
pub mod secret_delete;
pub mod secret_rotate;
pub mod app_register;
pub mod app_authorize;
pub mod app_list;
pub mod app_revoke;
pub mod vault_init;
pub mod vault_lock;
pub mod vault_unlock;
pub mod vault_status;
pub mod vault_change_password;

pub use secret_list::handle_secret_list;
pub use secret_get::{handle_secret_get, PermissionDeniedError};
pub use secret_set::handle_secret_set;
pub use secret_delete::handle_secret_delete;
pub use secret_rotate::handle_secret_rotate;
pub use app_register::handle_app_register;
pub use app_authorize::handle_app_authorize;
pub use app_list::handle_app_list;
pub use app_revoke::handle_app_revoke;
pub use vault_init::handle_vault_init;
// vault_lock is handled directly in server.rs (async for memory clearing)
pub use vault_unlock::handle_vault_unlock;
pub use vault_status::handle_vault_status;
pub use vault_change_password::handle_vault_change_password;

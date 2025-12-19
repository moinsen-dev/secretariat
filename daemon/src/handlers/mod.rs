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

pub mod secret_list;
pub mod secret_get;
pub mod secret_set;
pub mod secret_delete;
pub mod app_register;
pub mod app_authorize;

pub use secret_list::handle_secret_list;
pub use secret_get::{handle_secret_get, PermissionDeniedError};
pub use secret_set::handle_secret_set;
pub use secret_delete::handle_secret_delete;
pub use app_register::handle_app_register;
pub use app_authorize::handle_app_authorize;

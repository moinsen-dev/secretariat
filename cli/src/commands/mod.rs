//! Command handlers for Secretariat CLI
//!
//! This module contains implementation of all CLI commands.
//! Each command is in its own module.

pub mod apps;
pub mod audit;
pub mod change_password;
pub mod cleanup;
pub mod delete;
pub mod explain;
pub mod get;
pub mod grant;
pub mod import;
pub mod init;
pub mod list;
pub mod lock;
pub mod revoke;
pub mod rotate;
pub mod mcp;
pub mod run;
pub mod service;
pub mod set;
pub mod status;
pub mod unlock;

pub use apps::handle_apps;
pub use audit::handle_audit;
pub use change_password::handle_change_password;
pub use cleanup::handle_cleanup;
pub use delete::handle_delete;
pub use explain::handle_explain;
pub use get::handle_get;
pub use grant::handle_grant;
pub use import::handle_import;
pub use init::handle_init;
pub use list::handle_list;
pub use lock::handle_lock;
pub use revoke::handle_revoke;
pub use rotate::handle_rotate;
pub use set::handle_set;
pub use status::handle_status;
pub use unlock::handle_unlock;

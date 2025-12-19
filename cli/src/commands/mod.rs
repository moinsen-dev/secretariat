//! Command handlers for Secretariat CLI
//!
//! This module contains implementation of all CLI commands.
//! Each command is in its own module.

pub mod delete;
pub mod get;
pub mod import;
pub mod init;
pub mod list;
pub mod set;

pub use delete::handle_delete;
pub use get::handle_get;
pub use import::handle_import;
pub use init::handle_init;
pub use list::handle_list;
pub use set::handle_set;

//! Handler for app.list method
//!
//! Lists all registered applications with their permission counts.

use anyhow::Result;
use crate::storage::{Storage, ApplicationRecord};

/// Handle app.list method
///
/// Returns a list of all registered applications with their details
/// and the number of secrets each has access to.
///
/// # Arguments
///
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// Returns a vector of `ApplicationRecord` on success
///
/// # Errors
///
/// Returns an error if the database query fails
pub fn handle_app_list(storage: &Storage) -> Result<Vec<ApplicationRecord>> {
    storage.list_applications()
}

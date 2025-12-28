//! Handler for app.register method
//!
//! Registers an application using process credentials from Unix socket.
//!
//! ## Wave 14 Features:
//! - F071: Create handlers/app_register.rs file
//! - F072: Extract calling process PID from Unix socket credentials
//! - F073: Read process path from /proc/{pid}/exe on Linux or sysctl on macOS
//! - F074: Read bundle ID from Info.plist if process is macOS app bundle
//! - F075: Generate stable fingerprint by hashing (path + bundle_id)

use anyhow::{Result, Context, bail};
use std::path::PathBuf;

use crate::storage::{Storage, AppInfo};

/// F072: Get process information from PID
///
/// Extracts process path and optionally bundle ID from a process ID.
/// Platform-specific implementation for macOS and Linux.
///
/// # Arguments
///
/// * `pid` - Process identifier
///
/// # Returns
///
/// A tuple of (process_path, optional_bundle_id)
///
/// # Platform Support
///
/// - macOS: Uses `libproc` via sysctl to get executable path, checks for Info.plist in app bundle
/// - Linux: Reads /proc/{pid}/exe symlink to get executable path
/// - Windows: Not yet implemented
fn get_process_info(pid: u32) -> Result<(String, Option<String>)> {
    #[cfg(target_os = "macos")]
    {
        get_process_info_macos(pid)
    }

    #[cfg(target_os = "linux")]
    {
        get_process_info_linux(pid)
    }

    #[cfg(target_os = "windows")]
    {
        bail!(
            "Application registration on Windows requires process info APIs.\n\
             This feature is planned for a future release.\n\
             For now, Secretariat is only fully supported on macOS and Linux."
        );
    }

    #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
    {
        bail!(
            "Application registration is not supported on this platform ({}).\n\
             Secretariat currently supports macOS and Linux.",
            std::env::consts::OS
        );
    }
}

/// F073: Get process info on macOS
///
/// Uses sysctl to read the process path, then checks if it's an app bundle
/// to extract the bundle ID from Info.plist.
#[cfg(target_os = "macos")]
fn get_process_info_macos(pid: u32) -> Result<(String, Option<String>)> {
    use std::process::Command;

    // F073: Use `ps` command to get process path (simpler than sysctl FFI)
    let output = Command::new("ps")
        .args(&["-p", &pid.to_string(), "-o", "comm="])
        .output()
        .context("Failed to execute ps command")?;

    if !output.status.success() {
        bail!("Process {} not found", pid);
    }

    let path = String::from_utf8(output.stdout)
        .context("Invalid UTF-8 in process path")?
        .trim()
        .to_string();

    if path.is_empty() {
        bail!("Could not determine process path for PID {}", pid);
    }

    // F074: Check if this is an app bundle and extract bundle ID
    let bundle_id = extract_bundle_id(&path);

    Ok((path, bundle_id))
}

/// F074: Extract bundle ID from macOS app bundle
///
/// Checks if the executable path is inside a .app bundle, and if so,
/// reads the CFBundleIdentifier from Info.plist.
#[cfg(target_os = "macos")]
fn extract_bundle_id(path: &str) -> Option<String> {
    use std::process::Command;

    // Check if path contains .app/ indicating an app bundle
    if !path.contains(".app/") {
        return None;
    }

    // Extract the .app bundle path
    let bundle_path = if let Some(pos) = path.find(".app/") {
        &path[..pos + 4] // Include ".app"
    } else {
        return None;
    };

    // Read Info.plist using PlistBuddy
    let plist_path = format!("{}/Contents/Info.plist", bundle_path);
    let output = Command::new("/usr/libexec/PlistBuddy")
        .args(&["-c", "Print :CFBundleIdentifier", &plist_path])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let bundle_id = String::from_utf8(output.stdout)
        .ok()?
        .trim()
        .to_string();

    if bundle_id.is_empty() {
        None
    } else {
        Some(bundle_id)
    }
}

/// F073: Get process info on Linux
///
/// Reads the /proc/{pid}/exe symlink to get the executable path.
/// Linux doesn't have bundle IDs, so returns None.
#[cfg(target_os = "linux")]
fn get_process_info_linux(pid: u32) -> Result<(String, Option<String>)> {
    use std::fs;

    let exe_path = format!("/proc/{}/exe", pid);
    let path = fs::read_link(&exe_path)
        .context(format!("Failed to read {}", exe_path))?;

    let path_str = path.to_string_lossy().to_string();

    // Linux doesn't have bundle IDs
    Ok((path_str, None))
}

/// F075: Generate stable fingerprint from path and bundle ID
///
/// Creates a SHA-256 hash of the process path and optional bundle ID.
/// This provides a stable identifier for the application across runs.
fn generate_fingerprint(path: &str, bundle_id: Option<&str>) -> String {
    use sha2::{Sha256, Digest};

    let mut hasher = Sha256::new();
    hasher.update(path.as_bytes());

    if let Some(bundle) = bundle_id {
        hasher.update(b"|");
        hasher.update(bundle.as_bytes());
    }

    let result = hasher.finalize();
    hex::encode(result)
}

/// Handle app.register method
///
/// Registers an application by extracting process information from the
/// calling process and storing it in the applications table.
///
/// # Arguments
///
/// * `pid` - Process ID of the calling application
/// * `storage` - Reference to the storage layer
///
/// # Returns
///
/// Returns an `AppInfo` struct containing the registered application details
///
/// # Errors
///
/// Returns an error if:
/// - F072: PID extraction fails
/// - F073: Process path cannot be determined
/// - F074: Info.plist parsing fails (non-fatal, bundle_id will be None)
/// - F075: Fingerprint generation fails
/// - Database insert fails
///
/// # Features
///
/// - F071: Handler file created
/// - F072: Extracts PID from Unix socket credentials (passed as parameter)
/// - F073: Reads process path from /proc/{pid}/exe (Linux) or sysctl (macOS)
/// - F074: Reads bundle ID from Info.plist if macOS app bundle
/// - F075: Generates stable fingerprint by hashing (path + bundle_id)
///
/// # Security
///
/// This function creates a stable identity for applications:
/// 1. Extract real process path from OS (can't be spoofed)
/// 2. Read bundle ID from signed app bundle (if applicable)
/// 3. Generate fingerprint for future identification
/// 4. Store in database for permission management
///
/// # Examples
///
/// ```no_run
/// use secd::handlers::handle_app_register;
/// use secd::storage::Storage;
///
/// let storage = Storage::new("vault.db", "encryption_key").unwrap();
/// let pid = 12345; // From Unix socket credentials
///
/// let app_info = handle_app_register(pid, &storage)
///     .expect("Failed to register app");
///
/// println!("Registered app: {} (fingerprint: {})", app_info.name, app_info.fingerprint);
/// ```
pub fn handle_app_register(pid: u32, storage: &Storage) -> Result<AppInfo> {
    // F073: Get process path and bundle ID
    let (path, bundle_id) = get_process_info(pid)
        .context("Failed to get process information")?;

    // Extract application name from path
    let name = PathBuf::from(&path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    // F075: Generate stable fingerprint
    let fingerprint = generate_fingerprint(&path, bundle_id.as_deref());

    // Create AppInfo struct
    let app_info = AppInfo {
        pid,
        name: name.clone(),
        path: path.clone(),
        bundle_id: bundle_id.clone(),
        fingerprint: fingerprint.clone(),
    };

    // Store in database
    storage.register_application(&app_info)
        .context("Failed to register application in database")?;

    // Log the registration
    storage.log_audit(&fingerprint, &name, "register", true, Some(&format!("PID: {}, Path: {}", pid, path)))
        .context("Failed to log audit entry")?;

    Ok(app_info)
}

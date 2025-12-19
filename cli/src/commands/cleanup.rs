//! Cleanup command implementation
//!
//! Safely remove or archive .env files after importing secrets.
//!
//! Milestone 2: Cleanup imported .env files

use anyhow::{Context, Result};
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::client::DaemonClient;

/// CleanupCommand arguments
pub struct CleanupCommand {
    pub dry_run: bool,
    pub execute: bool,
    pub archive: bool,
    pub path: Option<String>,
}

/// Handle the cleanup command
///
/// Finds .env files and either:
/// - Shows what would be deleted (--dry-run, default)
/// - Deletes files (--execute)
/// - Moves to archive directory (--archive)
pub async fn handle_cleanup(_client: DaemonClient, cmd: CleanupCommand) -> Result<()> {
    let search_path = cmd.path.as_deref().unwrap_or(".");
    let path = Path::new(search_path);

    // Find all .env files
    let env_files = find_env_files(path)?;

    if env_files.is_empty() {
        println!("No .env files found in {}", path.display());
        return Ok(());
    }

    println!("Found {} .env file(s):", env_files.len());
    println!();

    for file in &env_files {
        let size = fs::metadata(file)
            .map(|m| format_size(m.len()))
            .unwrap_or_else(|_| "?".to_string());
        println!("  {} ({})", file.display(), size);
    }
    println!();

    if cmd.dry_run || (!cmd.execute && !cmd.archive) {
        println!("Dry run - no files were modified.");
        println!();
        println!("To delete these files:  sec cleanup --execute");
        println!("To archive these files: sec cleanup --archive");
        return Ok(());
    }

    if cmd.archive {
        // Archive mode - move to ~/.secretariat/archived-env/
        let archive_dir = get_archive_dir()?;
        fs::create_dir_all(&archive_dir)
            .context("Failed to create archive directory")?;

        println!("Archiving {} file(s) to {}...", env_files.len(), archive_dir.display());
        println!();

        for file in &env_files {
            let archive_name = generate_archive_name(file);
            let dest = archive_dir.join(&archive_name);

            match fs::copy(file, &dest) {
                Ok(_) => {
                    match fs::remove_file(file) {
                        Ok(_) => println!("  ✓ {} → {}", file.display(), archive_name),
                        Err(e) => println!("  ⚠ {} (copied but not removed: {})", file.display(), e),
                    }
                }
                Err(e) => println!("  ✗ {}: {}", file.display(), e),
            }
        }

        println!();
        println!("Archive location: {}", archive_dir.display());
    } else if cmd.execute {
        // Execute mode - delete files
        print!("Delete {} .env file(s)? This cannot be undone! [y/N]: ", env_files.len());
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;

        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Cleanup cancelled.");
            return Ok(());
        }

        println!();
        println!("Deleting {} file(s)...", env_files.len());

        let mut deleted = 0;
        let mut failed = 0;

        for file in &env_files {
            match fs::remove_file(file) {
                Ok(_) => {
                    deleted += 1;
                    println!("  ✓ {}", file.display());
                }
                Err(e) => {
                    failed += 1;
                    println!("  ✗ {}: {}", file.display(), e);
                }
            }
        }

        println!();
        println!("Cleanup complete:");
        println!("  Deleted: {}", deleted);
        if failed > 0 {
            println!("  Failed:  {}", failed);
        }
    }

    Ok(())
}

/// Find all .env files in a directory recursively
fn find_env_files(dir: &Path) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();

    for entry in WalkDir::new(dir)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| !is_hidden(e) && !is_ignored_dir(e))
    {
        let entry = entry?;
        let path = entry.path();

        if is_env_file(path) {
            files.push(path.to_path_buf());
        }
    }

    Ok(files)
}

/// Check if entry is hidden (starts with . except .env)
fn is_hidden(entry: &walkdir::DirEntry) -> bool {
    entry.file_name()
        .to_str()
        .map(|s| s.starts_with('.') && !s.starts_with(".env"))
        .unwrap_or(false)
}

/// Check if directory should be ignored
fn is_ignored_dir(entry: &walkdir::DirEntry) -> bool {
    if !entry.file_type().is_dir() {
        return false;
    }

    let ignored = ["node_modules", "target", "build", "dist", ".git", "vendor", "__pycache__"];
    entry.file_name()
        .to_str()
        .map(|s| ignored.contains(&s))
        .unwrap_or(false)
}

/// Check if a file is an .env file
fn is_env_file(path: &Path) -> bool {
    let name = path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("");

    name == ".env" ||
    name.starts_with(".env.") ||
    name.ends_with(".env")
}

/// Get archive directory path
fn get_archive_dir() -> Result<PathBuf> {
    let home = dirs::home_dir().context("Failed to get home directory")?;

    #[cfg(target_os = "macos")]
    let base = home.join("Library/Application Support/Secretariat");

    #[cfg(not(target_os = "macos"))]
    let base = home.join(".secretariat");

    Ok(base.join("archived-env"))
}

/// Generate archive name with timestamp and path info
fn generate_archive_name(file: &Path) -> String {
    let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");

    // Create a sanitized version of the path
    let path_part = file
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("root");

    let file_name = file
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(".env");

    format!("{}_{}_{}",  timestamp, sanitize_filename(path_part), file_name)
}

/// Sanitize a string for use in filename
fn sanitize_filename(s: &str) -> String {
    s.chars()
        .map(|c| if c.is_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect()
}

/// Format file size in human-readable format
fn format_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;

    if bytes < KB {
        format!("{} B", bytes)
    } else if bytes < MB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    }
}

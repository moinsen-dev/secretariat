//! F131-F134: Import command implementation
//!
//! Import secrets from .env files.
//!
//! Features:
//! - F131: Create commands/import.rs file
//! - F132: Read .env file line by line
//! - F133: Parse KEY=VALUE format with support for quotes (single, double)
//! - F134: Detect provider from key prefix (OPENAI_, STRIPE_, ANTHROPIC_, AWS_, etc.)
//! - Milestone 2: --scan directory recursively, duplicate detection, interactive merge

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::io::{self, BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::client::DaemonClient;

/// ImportCommand arguments
pub struct ImportCommand {
    pub path: String,
    pub scan: bool,
    pub yes: bool,
}

/// A secret parsed from .env file
#[derive(Debug, Clone)]
struct ParsedSecret {
    key: String,
    value: String,
    provider: Option<String>,
    source_file: PathBuf,
}

/// Scan result containing all .env files found
#[derive(Debug)]
struct ScanResult {
    files: Vec<PathBuf>,
    secrets: Vec<ParsedSecret>,
    duplicates: HashMap<String, Vec<ParsedSecret>>,
}

/// Response from secret.set
#[derive(Debug, Deserialize)]
#[allow(dead_code)] // Fields used for deserialization validation
struct SetResponse {
    name: String,
    status: String,
}

/// F131-F134: Handle the import command
///
/// This command imports secrets from .env files by:
/// 1. F132: Reading .env file line by line
/// 2. F133: Parsing KEY=VALUE format with support for quotes
/// 3. F134: Detecting provider from key prefix
/// 4. Milestone 2: Scan directories recursively for .env files
/// 5. Milestone 2: Detect duplicates across multiple files
///
/// # Arguments
///
/// * `client` - Daemon client for communication
/// * `cmd` - Command arguments containing file path and options
///
/// # Returns
///
/// Returns Ok(()) on success, error if import fails
///
/// # Examples
///
/// ```bash
/// # Import from .env file
/// sec import .env
///
/// # Import without confirmation
/// sec import .env --yes
///
/// # Scan directory for .env files
/// sec import . --scan
/// ```
pub async fn handle_import(client: DaemonClient, cmd: ImportCommand) -> Result<()> {
    let path = Path::new(&cmd.path);

    let secrets_to_import = if cmd.scan {
        // Milestone 2: Scan directory recursively
        handle_scan_import(path, cmd.yes)?
    } else {
        // Single file import
        let secrets = parse_env_file(path)
            .with_context(|| format!("Failed to parse .env file: {}", cmd.path))?;

        if secrets.is_empty() {
            println!("No secrets found in {}", cmd.path);
            return Ok(());
        }

        display_secrets_preview(&secrets);

        if !cmd.yes && !confirm_import()? {
            println!("Import cancelled");
            return Ok(());
        }

        secrets
    };

    if secrets_to_import.is_empty() {
        return Ok(());
    }

    // Import each secret
    let mut imported = 0;
    let mut failed = 0;

    for secret in secrets_to_import {
        let mut params = json!({
            "name": secret.key,
            "value": secret.value,
        });

        if let Some(provider) = &secret.provider {
            params["provider"] = json!(provider);
        }

        match client.request::<Value, SetResponse>("secret.set", params).await {
            Ok(_) => {
                imported += 1;
                println!("  ✓ {}", secret.key);
            }
            Err(e) => {
                eprintln!("  ✗ {}: {}", secret.key, e);
                failed += 1;
            }
        }
    }

    println!();
    println!("Import complete:");
    println!("  Imported: {}", imported);
    if failed > 0 {
        println!("  Failed:   {}", failed);
    }

    Ok(())
}

/// Handle scan mode - recursively find and import .env files
fn handle_scan_import(dir: &Path, auto_yes: bool) -> Result<Vec<ParsedSecret>> {
    println!("Scanning {} for .env files...", dir.display());

    let scan_result = scan_directory(dir)?;

    if scan_result.files.is_empty() {
        println!("No .env files found in {}", dir.display());
        return Ok(vec![]);
    }

    println!();
    println!("Found {} .env file(s):", scan_result.files.len());
    for file in &scan_result.files {
        println!("  • {}", file.display());
    }
    println!();

    println!("Total secrets found: {}", scan_result.secrets.len());

    // Handle duplicates
    if !scan_result.duplicates.is_empty() {
        println!();
        println!("⚠️  Found {} duplicate key(s):", scan_result.duplicates.len());

        for (key, occurrences) in &scan_result.duplicates {
            println!();
            println!("  {} appears in {} files:", key, occurrences.len());
            for (i, secret) in occurrences.iter().enumerate() {
                let masked = mask_value(&secret.value);
                println!("    {}. {} = {} ({})",
                    i + 1,
                    key,
                    masked,
                    secret.source_file.display()
                );
            }
        }
        println!();
    }

    // Display unique secrets
    let unique_secrets = get_unique_secrets(&scan_result);

    if unique_secrets.is_empty() {
        println!("No unique secrets to import.");
        return Ok(vec![]);
    }

    println!();
    println!("Secrets to import ({}):", unique_secrets.len());
    display_secrets_preview(&unique_secrets);

    if !auto_yes && !confirm_import()? {
        println!("Import cancelled");
        return Ok(vec![]);
    }

    Ok(unique_secrets)
}

/// Scan a directory recursively for .env files
fn scan_directory(dir: &Path) -> Result<ScanResult> {
    let mut files = Vec::new();
    let mut all_secrets = Vec::new();
    let mut key_occurrences: HashMap<String, Vec<ParsedSecret>> = HashMap::new();

    for entry in WalkDir::new(dir)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| !is_hidden(e) && !is_ignored_dir(e))
    {
        let entry = entry?;
        let path = entry.path();

        if is_env_file(path) {
            files.push(path.to_path_buf());

            if let Ok(secrets) = parse_env_file(path) {
                for secret in secrets {
                    key_occurrences
                        .entry(secret.key.clone())
                        .or_default()
                        .push(secret.clone());
                    all_secrets.push(secret);
                }
            }
        }
    }

    // Identify duplicates (keys that appear more than once)
    let duplicates: HashMap<String, Vec<ParsedSecret>> = key_occurrences
        .into_iter()
        .filter(|(_, v)| v.len() > 1)
        .collect();

    Ok(ScanResult {
        files,
        secrets: all_secrets,
        duplicates,
    })
}

/// Check if a path is a hidden file/directory
fn is_hidden(entry: &walkdir::DirEntry) -> bool {
    entry.file_name()
        .to_str()
        .map(|s| s.starts_with('.') && s != ".env")
        .unwrap_or(false)
}

/// Check if directory should be ignored (node_modules, target, etc.)
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

    // Match .env, .env.local, .env.development, .env.production, etc.
    name == ".env" ||
    name.starts_with(".env.") ||
    name.ends_with(".env")
}

/// Get unique secrets (for duplicates, take the first occurrence)
fn get_unique_secrets(scan_result: &ScanResult) -> Vec<ParsedSecret> {
    let mut seen = std::collections::HashSet::new();
    let mut unique = Vec::new();

    for secret in &scan_result.secrets {
        if seen.insert(secret.key.clone()) {
            unique.push(secret.clone());
        }
    }

    unique
}

/// Display preview of secrets to import
fn display_secrets_preview(secrets: &[ParsedSecret]) {
    println!();
    for secret in secrets {
        let provider_str = secret
            .provider
            .as_ref()
            .map(|p| format!(" ({})", p))
            .unwrap_or_default();
        let masked_value = mask_value(&secret.value);
        println!("  {} = {}{}", secret.key, masked_value, provider_str);
    }
    println!();
}

/// Confirm import with user
fn confirm_import() -> Result<bool> {
    print!("Import these secrets? [y/N]: ");
    io::stdout().flush()?;

    let mut input = String::new();
    io::stdin().read_line(&mut input)?;

    Ok(input.trim().eq_ignore_ascii_case("y"))
}

/// F132-F133: Parse .env file and extract secrets
///
/// Reads the file line by line and parses KEY=VALUE format.
/// Supports:
/// - Comments (lines starting with #)
/// - Empty lines
/// - Values with double quotes: KEY="value"
/// - Values with single quotes: KEY='value'
/// - Unquoted values: KEY=value
/// - Values with spaces when quoted
///
/// # Arguments
///
/// * `path` - Path to .env file
///
/// # Returns
///
/// Returns vector of parsed secrets
fn parse_env_file(path: &Path) -> Result<Vec<ParsedSecret>> {
    let file = fs::File::open(path).context("Failed to open file")?;
    let reader = BufReader::new(file);
    let mut secrets = Vec::new();

    for (line_num, line) in reader.lines().enumerate() {
        let line = line?;
        let line = line.trim();

        // Skip empty lines and comments
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        // F133: Parse KEY=VALUE format
        if let Some((key, value)) = parse_env_line(line) {
            // F134: Detect provider from key prefix
            let provider = detect_provider(&key);

            secrets.push(ParsedSecret {
                key,
                value,
                provider,
                source_file: path.to_path_buf(),
            });
        } else {
            eprintln!(
                "Warning: Failed to parse line {}: {}",
                line_num + 1,
                line
            );
        }
    }

    Ok(secrets)
}

/// F133: Parse a single KEY=VALUE line
///
/// Supports quotes (single and double) and unquoted values.
fn parse_env_line(line: &str) -> Option<(String, String)> {
    let equals_pos = line.find('=')?;
    let key = line[..equals_pos].trim();
    let value_part = line[equals_pos + 1..].trim();

    if key.is_empty() {
        return None;
    }

    let value = if (value_part.starts_with('"') && value_part.ends_with('"'))
        || (value_part.starts_with('\'') && value_part.ends_with('\''))
    {
        // Remove quotes
        if value_part.len() >= 2 {
            value_part[1..value_part.len() - 1].to_string()
        } else {
            String::new()
        }
    } else {
        // Unquoted value
        value_part.to_string()
    };

    Some((key.to_string(), value))
}

/// F134: Detect provider from key prefix
///
/// Common provider prefixes:
/// - OPENAI_ -> openai
/// - STRIPE_ -> stripe
/// - ANTHROPIC_ -> anthropic
/// - AWS_ -> aws
/// - GOOGLE_ -> google
/// - GITHUB_ -> github
/// - SLACK_ -> slack
/// - TWILIO_ -> twilio
/// - SENDGRID_ -> sendgrid
/// - FIREBASE_ -> firebase
fn detect_provider(key: &str) -> Option<String> {
    let upper_key = key.to_uppercase();

    let prefixes: HashMap<&str, &str> = [
        ("OPENAI_", "openai"),
        ("ANTHROPIC_", "anthropic"),
        ("STRIPE_", "stripe"),
        ("AWS_", "aws"),
        ("GOOGLE_", "google"),
        ("GITHUB_", "github"),
        ("GITLAB_", "gitlab"),
        ("SLACK_", "slack"),
        ("TWILIO_", "twilio"),
        ("SENDGRID_", "sendgrid"),
        ("FIREBASE_", "firebase"),
        ("HEROKU_", "heroku"),
        ("VERCEL_", "vercel"),
        ("NETLIFY_", "netlify"),
        ("CLOUDFLARE_", "cloudflare"),
        ("DIGITALOCEAN_", "digitalocean"),
        ("AZURE_", "azure"),
        ("GCP_", "google"),
    ]
    .iter()
    .copied()
    .collect();

    for (prefix, provider) in prefixes {
        if upper_key.starts_with(prefix) {
            return Some(provider.to_string());
        }
    }

    None
}

/// Mask value for display (show first and last 4 chars)
fn mask_value(value: &str) -> String {
    if value.len() <= 8 {
        "*".repeat(value.len())
    } else {
        format!(
            "{}...{}",
            &value[..4],
            &value[value.len() - 4..]
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_env_line_unquoted() {
        assert_eq!(
            parse_env_line("KEY=value"),
            Some(("KEY".to_string(), "value".to_string()))
        );
    }

    #[test]
    fn test_parse_env_line_double_quotes() {
        assert_eq!(
            parse_env_line("KEY=\"value with spaces\""),
            Some(("KEY".to_string(), "value with spaces".to_string()))
        );
    }

    #[test]
    fn test_parse_env_line_single_quotes() {
        assert_eq!(
            parse_env_line("KEY='value with spaces'"),
            Some(("KEY".to_string(), "value with spaces".to_string()))
        );
    }

    #[test]
    fn test_detect_provider() {
        assert_eq!(detect_provider("OPENAI_API_KEY"), Some("openai".to_string()));
        assert_eq!(detect_provider("STRIPE_SECRET_KEY"), Some("stripe".to_string()));
        assert_eq!(detect_provider("ANTHROPIC_API_KEY"), Some("anthropic".to_string()));
        assert_eq!(detect_provider("AWS_ACCESS_KEY_ID"), Some("aws".to_string()));
        assert_eq!(detect_provider("RANDOM_KEY"), None);
    }

    #[test]
    fn test_mask_value() {
        assert_eq!(mask_value("short"), "*****");
        assert_eq!(mask_value("sk-1234567890abcdef"), "sk-1...cdef");
    }
}

//! F131-F134: Import command implementation
//!
//! Import secrets from .env files.
//!
//! Features:
//! - F131: Create commands/import.rs file
//! - F132: Read .env file line by line
//! - F133: Parse KEY=VALUE format with support for quotes (single, double)
//! - F134: Detect provider from key prefix (OPENAI_, STRIPE_, ANTHROPIC_, AWS_, etc.)

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::io::{self, BufRead, BufReader};

use crate::client::DaemonClient;

/// ImportCommand arguments
pub struct ImportCommand {
    pub path: String,
    pub scan: bool,
    pub yes: bool,
}

/// A secret parsed from .env file
#[derive(Debug)]
struct ParsedSecret {
    key: String,
    value: String,
    provider: Option<String>,
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
    if cmd.scan {
        anyhow::bail!("Scan mode is not yet implemented");
    }

    // F132: Read .env file line by line
    let secrets = parse_env_file(&cmd.path)
        .with_context(|| format!("Failed to parse .env file: {}", cmd.path))?;

    if secrets.is_empty() {
        println!("No secrets found in {}", cmd.path);
        return Ok(());
    }

    // Display preview of secrets to import
    println!("Found {} secret(s) in {}:", secrets.len(), cmd.path);
    println!();

    for secret in &secrets {
        let provider_str = secret
            .provider
            .as_ref()
            .map(|p| format!(" ({})", p))
            .unwrap_or_default();
        let masked_value = mask_value(&secret.value);
        println!("  {} = {}{}", secret.key, masked_value, provider_str);
    }
    println!();

    // Confirm import unless --yes flag is set
    if !cmd.yes {
        print!("Import these secrets? [y/N]: ");
        io::Write::flush(&mut io::stdout())?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;

        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Import cancelled");
            return Ok(());
        }
    }

    // Import each secret
    let mut imported = 0;
    let mut failed = 0;

    for secret in secrets {
        let mut params = json!({
            "name": secret.key,
            "value": secret.value,
        });

        if let Some(provider) = secret.provider {
            params["provider"] = json!(provider);
        }

        match client.request::<Value, SetResponse>("secret.set", params).await {
            Ok(_) => {
                imported += 1;
            }
            Err(e) => {
                eprintln!("Failed to import {}: {}", secret.key, e);
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
fn parse_env_file(path: &str) -> Result<Vec<ParsedSecret>> {
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

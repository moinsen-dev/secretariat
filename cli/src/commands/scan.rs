//! sec scan - Environment variable discovery and audit command
//!
//! Recursively scans directories for .env files to:
//! - Discover what environment variables exist across projects
//! - Detect which directories/projects use which secrets
//! - Identify patterns: providers, duplicates, inconsistencies
//! - Aid onboarding by helping users migrate secrets to Secretariat
//!
//! This command operates independently of the daemon (CLI-only).

use anyhow::{Context, Result};
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// ScanCommand arguments
pub struct ScanCommand {
    /// Directory to scan (default: current directory)
    pub path: String,
    /// Output as JSON
    pub json: bool,
    /// Show only summary
    pub summary: bool,
    /// Show only duplicates
    pub duplicates: bool,
    /// Filter by provider
    pub provider: Option<String>,
    /// Export results to file
    pub export: Option<PathBuf>,
    /// Maximum depth to scan
    pub max_depth: usize,
}

/// Complete scan report
#[derive(Debug, Serialize)]
pub struct ScanReport {
    pub scanned_at: String,
    pub root_path: PathBuf,
    pub projects: Vec<Project>,
    pub variables: Vec<Variable>,
    pub duplicates: Vec<Duplicate>,
    pub summary: Summary,
}

/// A discovered project
#[derive(Debug, Clone, Serialize)]
pub struct Project {
    pub name: String,
    pub path: PathBuf,
    pub files: Vec<PathBuf>,
    pub variable_count: usize,
    pub providers: Vec<String>,
}

/// A discovered variable
#[derive(Debug, Clone, Serialize)]
pub struct Variable {
    pub name: String,
    pub provider: Option<String>,
    pub occurrences: Vec<Occurrence>,
    pub is_duplicate: bool,
}

/// Where a variable was found
#[derive(Debug, Clone, Serialize)]
pub struct Occurrence {
    pub file: PathBuf,
    pub project: String,
    pub value_hash: String,
    pub masked_value: String,
}

/// Variables with same key but different values
#[derive(Debug, Serialize)]
pub struct Duplicate {
    pub name: String,
    pub occurrences: Vec<Occurrence>,
    pub unique_values: usize,
}

/// Summary statistics
#[derive(Debug, Serialize)]
pub struct Summary {
    pub total_files: usize,
    pub total_projects: usize,
    pub total_variables: usize,
    pub unique_variables: usize,
    pub duplicate_count: usize,
    pub providers_found: Vec<String>,
}

/// Internal struct for parsed secrets
#[derive(Debug, Clone)]
struct ParsedSecret {
    key: String,
    value: String,
    provider: Option<String>,
    source_file: PathBuf,
    project_name: String,
}

/// Project markers for detection
const PROJECT_MARKERS: &[&str] = &[
    "package.json",
    "Cargo.toml",
    "pubspec.yaml",
    "pyproject.toml",
    "go.mod",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "Gemfile",
    "composer.json",
    ".git",
];

/// Directories to ignore during scanning
const IGNORED_DIRS: &[&str] = &[
    "node_modules",
    "target",
    "build",
    "dist",
    ".git",
    "vendor",
    "__pycache__",
    ".venv",
    "venv",
    ".next",
    ".nuxt",
    "coverage",
    ".cache",
];

/// Handle the scan command
///
/// Scans directories recursively for .env files and generates a comprehensive
/// report of discovered variables, projects, and potential issues.
pub async fn handle_scan(cmd: ScanCommand) -> Result<()> {
    let root_path = PathBuf::from(&cmd.path).canonicalize()
        .with_context(|| format!("Invalid path: {}", cmd.path))?;

    if !cmd.json && !cmd.summary {
        println!("Scanning {} for .env files...", root_path.display());
        println!();
    }

    // Perform the scan
    let report = scan_directory(&root_path, cmd.max_depth, cmd.provider.as_deref())?;

    // Handle output
    if let Some(export_path) = &cmd.export {
        let json = serde_json::to_string_pretty(&report)?;
        fs::write(export_path, &json)?;
        if !cmd.json {
            println!("Report exported to {}", export_path.display());
        }
    }

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&report)?);
    } else if cmd.summary {
        display_summary(&report);
    } else if cmd.duplicates {
        display_duplicates_only(&report);
    } else {
        display_full_report(&report);
    }

    Ok(())
}

/// Scan a directory recursively for .env files
fn scan_directory(root: &Path, max_depth: usize, provider_filter: Option<&str>) -> Result<ScanReport> {
    let mut env_files: Vec<PathBuf> = Vec::new();
    let mut all_secrets: Vec<ParsedSecret> = Vec::new();
    let mut project_map: HashMap<PathBuf, Vec<PathBuf>> = HashMap::new();

    // Walk directory tree
    for entry in WalkDir::new(root)
        .max_depth(max_depth)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| !is_hidden(e) && !is_ignored_dir(e))
    {
        let entry = entry?;
        let path = entry.path();

        if is_env_file(path) {
            env_files.push(path.to_path_buf());

            // Detect project for this file
            let project_root = detect_project_root(path);
            project_map
                .entry(project_root.clone())
                .or_default()
                .push(path.to_path_buf());

            // Parse the file
            if let Ok(secrets) = parse_env_file(path, &project_root) {
                for secret in secrets {
                    // Apply provider filter
                    if let Some(filter) = provider_filter {
                        if secret.provider.as_deref() != Some(filter) {
                            continue;
                        }
                    }
                    all_secrets.push(secret);
                }
            }
        }
    }

    // Build project list
    let projects = build_projects(&project_map, &all_secrets);

    // Build variable list with duplicate detection
    let (variables, duplicates) = build_variables(&all_secrets);

    // Build summary
    let summary = Summary {
        total_files: env_files.len(),
        total_projects: projects.len(),
        total_variables: all_secrets.len(),
        unique_variables: variables.len(),
        duplicate_count: duplicates.len(),
        providers_found: collect_providers(&all_secrets),
    };

    Ok(ScanReport {
        scanned_at: chrono_now(),
        root_path: root.to_path_buf(),
        projects,
        variables,
        duplicates,
        summary,
    })
}

/// Check if entry is a hidden file/directory (except .env files)
fn is_hidden(entry: &walkdir::DirEntry) -> bool {
    entry
        .file_name()
        .to_str()
        .map(|s| s.starts_with('.') && !s.starts_with(".env"))
        .unwrap_or(false)
}

/// Check if directory should be ignored
fn is_ignored_dir(entry: &walkdir::DirEntry) -> bool {
    if !entry.file_type().is_dir() {
        return false;
    }
    entry
        .file_name()
        .to_str()
        .map(|s| IGNORED_DIRS.contains(&s))
        .unwrap_or(false)
}

/// Check if file is an .env file
fn is_env_file(path: &Path) -> bool {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");

    // Match .env, .env.local, .env.development, .env.production, etc.
    name == ".env" || name.starts_with(".env.") || name.ends_with(".env")
}

/// Detect project root by finding nearest project marker
fn detect_project_root(env_file: &Path) -> PathBuf {
    let mut current = env_file.parent();

    while let Some(dir) = current {
        for marker in PROJECT_MARKERS {
            if dir.join(marker).exists() {
                return dir.to_path_buf();
            }
        }
        current = dir.parent();
    }

    // Fallback to parent directory of .env file
    env_file
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Get project name from path
fn get_project_name(path: &Path) -> String {
    path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string()
}

/// Parse .env file and extract secrets
fn parse_env_file(path: &Path, project_root: &Path) -> Result<Vec<ParsedSecret>> {
    let file = fs::File::open(path).context("Failed to open file")?;
    let reader = BufReader::new(file);
    let mut secrets = Vec::new();
    let project_name = get_project_name(project_root);

    for line in reader.lines() {
        let line = line?;
        let line = line.trim();

        // Skip empty lines and comments
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        if let Some((key, value)) = parse_env_line(line) {
            let provider = detect_provider(&key);

            secrets.push(ParsedSecret {
                key,
                value,
                provider,
                source_file: path.to_path_buf(),
                project_name: project_name.clone(),
            });
        }
    }

    Ok(secrets)
}

/// Parse a single KEY=VALUE line
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
        value_part.to_string()
    };

    Some((key.to_string(), value))
}

/// Detect provider from key prefix
fn detect_provider(key: &str) -> Option<String> {
    let upper_key = key.to_uppercase();

    let prefixes: &[(&str, &str)] = &[
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
        ("SUPABASE_", "supabase"),
        ("POSTGRES", "database"),
        ("MYSQL", "database"),
        ("MONGO", "database"),
        ("REDIS_", "redis"),
        ("DATABASE_", "database"),
        ("DB_", "database"),
    ];

    for (prefix, provider) in prefixes {
        if upper_key.starts_with(prefix) || upper_key.contains(prefix) {
            return Some(provider.to_string());
        }
    }

    None
}

/// Mask value for display (show first and last 4 chars)
fn mask_value(value: &str) -> String {
    if value.is_empty() {
        "<empty>".to_string()
    } else if value.len() <= 8 {
        "*".repeat(value.len())
    } else {
        format!("{}...{}", &value[..4], &value[value.len() - 4..])
    }
}

/// Hash value for duplicate detection
fn hash_value(value: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    let result = hasher.finalize();
    hex::encode(&result[..8]) // Short hash
}

/// Build project list from discovered data
fn build_projects(
    project_map: &HashMap<PathBuf, Vec<PathBuf>>,
    all_secrets: &[ParsedSecret],
) -> Vec<Project> {
    let mut projects: Vec<Project> = Vec::new();

    for (project_path, files) in project_map {
        let project_name = get_project_name(project_path);

        // Get variables and providers for this project
        let project_secrets: Vec<_> = all_secrets
            .iter()
            .filter(|s| s.project_name == project_name)
            .collect();

        let providers: Vec<String> = project_secrets
            .iter()
            .filter_map(|s| s.provider.clone())
            .collect::<HashSet<_>>()
            .into_iter()
            .collect();

        projects.push(Project {
            name: project_name,
            path: project_path.clone(),
            files: files.clone(),
            variable_count: project_secrets.len(),
            providers,
        });
    }

    projects.sort_by(|a, b| a.name.cmp(&b.name));
    projects
}

/// Build variable list with duplicate detection
fn build_variables(all_secrets: &[ParsedSecret]) -> (Vec<Variable>, Vec<Duplicate>) {
    let mut var_map: HashMap<String, Vec<&ParsedSecret>> = HashMap::new();

    // Group by variable name
    for secret in all_secrets {
        var_map.entry(secret.key.clone()).or_default().push(secret);
    }

    let mut variables: Vec<Variable> = Vec::new();
    let mut duplicates: Vec<Duplicate> = Vec::new();

    for (name, secrets) in var_map {
        let occurrences: Vec<Occurrence> = secrets
            .iter()
            .map(|s| Occurrence {
                file: s.source_file.clone(),
                project: s.project_name.clone(),
                value_hash: hash_value(&s.value),
                masked_value: mask_value(&s.value),
            })
            .collect();

        // Check for duplicates (same key, different values)
        let unique_hashes: HashSet<String> = occurrences.iter().map(|o| o.value_hash.clone()).collect();
        let unique_count = unique_hashes.len();
        let is_duplicate = unique_count > 1;

        let provider = secrets.first().and_then(|s| s.provider.clone());

        if is_duplicate {
            duplicates.push(Duplicate {
                name: name.clone(),
                occurrences: occurrences.clone(),
                unique_values: unique_count,
            });
        }

        variables.push(Variable {
            name,
            provider,
            occurrences,
            is_duplicate,
        });
    }

    variables.sort_by(|a, b| a.name.cmp(&b.name));
    duplicates.sort_by(|a, b| a.name.cmp(&b.name));

    (variables, duplicates)
}

/// Collect all unique providers
fn collect_providers(secrets: &[ParsedSecret]) -> Vec<String> {
    let mut providers: Vec<String> = secrets
        .iter()
        .filter_map(|s| s.provider.clone())
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    providers.sort();
    providers
}

/// Get current timestamp
fn chrono_now() -> String {
    use std::time::SystemTime;
    let duration = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default();
    format!("{}", duration.as_secs())
}

/// Display full report
fn display_full_report(report: &ScanReport) {
    if report.summary.total_files == 0 {
        println!("No .env files found in {}", report.root_path.display());
        return;
    }

    // Header
    println!("Found {} .env file(s) across {} project(s)",
        report.summary.total_files,
        report.summary.total_projects
    );
    println!();

    // Projects discovered
    println!("PROJECTS DISCOVERED");
    println!("{}", "─".repeat(70));
    println!("{:<30} {:>8} {:>10} {:<20}",
        "PROJECT", "FILES", "VARIABLES", "PROVIDERS"
    );
    println!("{}", "─".repeat(70));

    for project in &report.projects {
        let providers = if project.providers.is_empty() {
            "-".to_string()
        } else {
            project.providers.join(", ")
        };
        println!("{:<30} {:>8} {:>10} {:<20}",
            truncate_str(&project.name, 29),
            project.files.len(),
            project.variable_count,
            truncate_str(&providers, 19)
        );
    }
    println!("{}", "─".repeat(70));
    println!();

    // Variables summary
    println!("VARIABLES SUMMARY");
    println!("{}", "─".repeat(70));
    println!("{:<35} {:>12} {:>10} {:>10}",
        "VARIABLE", "OCCURRENCES", "PROVIDER", "STATUS"
    );
    println!("{}", "─".repeat(70));

    for var in &report.variables {
        let provider = var.provider.as_deref().unwrap_or("-");
        let status = if var.is_duplicate {
            "⚠️  duplicate"
        } else {
            "✓ unique"
        };
        println!("{:<35} {:>12} {:>10} {:>10}",
            truncate_str(&var.name, 34),
            var.occurrences.len(),
            truncate_str(provider, 9),
            status
        );
    }
    println!("{}", "─".repeat(70));
    println!();

    // Duplicates
    if !report.duplicates.is_empty() {
        display_duplicates_section(&report.duplicates);
    }

    // Recommendations
    display_recommendations(report);

    // Footer
    println!();
    println!("Total: {} variables, {} files, {} projects",
        report.summary.unique_variables,
        report.summary.total_files,
        report.summary.total_projects
    );
}

/// Display only duplicates
fn display_duplicates_only(report: &ScanReport) {
    if report.duplicates.is_empty() {
        println!("No duplicate variables found.");
        return;
    }

    display_duplicates_section(&report.duplicates);
}

/// Display duplicates section
fn display_duplicates_section(duplicates: &[Duplicate]) {
    println!("DUPLICATES (same key, different values)");
    println!("{}", "─".repeat(70));

    for dup in duplicates {
        println!();
        println!("{}:", dup.name);
        for occ in &dup.occurrences {
            // Make path relative if possible
            let display_path = occ.file.file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("?");
            println!("  • {:<40} {}",
                format!("{}/{}", occ.project, display_path),
                occ.masked_value
            );
        }
    }
    println!();
    println!("{}", "─".repeat(70));
}

/// Display recommendations
fn display_recommendations(report: &ScanReport) {
    println!("RECOMMENDATIONS");
    println!("{}", "─".repeat(70));

    let centralize_count = report.variables.iter()
        .filter(|v| v.occurrences.len() > 1)
        .count();

    if centralize_count > 0 {
        println!("• {} secret(s) could be centralized in Secretariat", centralize_count);
    }

    if !report.duplicates.is_empty() {
        println!("• {} variable(s) have inconsistent values across projects", report.duplicates.len());
    }

    if report.summary.unique_variables > 0 {
        println!("• Consider using `sec import --scan` to migrate secrets");
    }

    if !report.summary.providers_found.is_empty() {
        println!("• Detected providers: {}", report.summary.providers_found.join(", "));
    }

    println!("{}", "─".repeat(70));
}

/// Display summary only
fn display_summary(report: &ScanReport) {
    println!("SCAN SUMMARY");
    println!("{}", "─".repeat(40));
    println!("  Files scanned:      {}", report.summary.total_files);
    println!("  Projects found:     {}", report.summary.total_projects);
    println!("  Total variables:    {}", report.summary.total_variables);
    println!("  Unique variables:   {}", report.summary.unique_variables);
    println!("  Duplicates:         {}", report.summary.duplicate_count);
    if !report.summary.providers_found.is_empty() {
        println!("  Providers:          {}", report.summary.providers_found.join(", "));
    }
    println!("{}", "─".repeat(40));
}

/// Truncate string for display
fn truncate_str(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        s.to_string()
    } else {
        format!("{}…", &s[..max_len - 1])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_env_file() {
        assert!(is_env_file(Path::new(".env")));
        assert!(is_env_file(Path::new(".env.local")));
        assert!(is_env_file(Path::new(".env.production")));
        assert!(is_env_file(Path::new("production.env")));
        assert!(!is_env_file(Path::new("config.json")));
        assert!(!is_env_file(Path::new(".gitignore")));
    }

    #[test]
    fn test_parse_env_line() {
        assert_eq!(
            parse_env_line("KEY=value"),
            Some(("KEY".to_string(), "value".to_string()))
        );
        assert_eq!(
            parse_env_line("KEY=\"quoted value\""),
            Some(("KEY".to_string(), "quoted value".to_string()))
        );
        assert_eq!(
            parse_env_line("KEY='single quoted'"),
            Some(("KEY".to_string(), "single quoted".to_string()))
        );
        assert_eq!(parse_env_line("# comment"), None);
        assert_eq!(parse_env_line(""), None);
    }

    #[test]
    fn test_detect_provider() {
        assert_eq!(detect_provider("OPENAI_API_KEY"), Some("openai".to_string()));
        assert_eq!(detect_provider("STRIPE_SECRET_KEY"), Some("stripe".to_string()));
        assert_eq!(detect_provider("DATABASE_URL"), Some("database".to_string()));
        assert_eq!(detect_provider("CUSTOM_KEY"), None);
    }

    #[test]
    fn test_mask_value() {
        assert_eq!(mask_value("short"), "*****");
        assert_eq!(mask_value("sk-1234567890abcdef"), "sk-1...cdef");
        assert_eq!(mask_value(""), "<empty>");
    }

    #[test]
    fn test_hash_value() {
        let hash1 = hash_value("secret1");
        let hash2 = hash_value("secret2");
        let hash3 = hash_value("secret1");

        assert_ne!(hash1, hash2);
        assert_eq!(hash1, hash3);
    }
}

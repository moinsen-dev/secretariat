//! sec scan - Environment variable discovery and audit command
//!
//! Recursively scans directories for .env files to:
//! - Discover what environment variables exist across projects
//! - Detect which directories/projects use which secrets
//! - Identify patterns: providers, duplicates, inconsistencies
//! - Detect security issues: files not in .gitignore, committed secrets
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
use std::process::Command;
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
    /// Show only security issues (files not in .gitignore)
    pub security: bool,
    /// Filter by provider
    pub provider: Option<String>,
    /// Export results to file
    pub export: Option<PathBuf>,
    /// Export as HTML report
    pub html: Option<PathBuf>,
    /// Fix security issues (add .env* to .gitignore)
    pub fix: bool,
    /// Dry run for fix (show what would be changed)
    pub fix_dry_run: bool,
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
    pub security_issues: Vec<SecurityIssue>,
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
    pub security_issue_count: usize,
    pub providers_found: Vec<String>,
}

/// Security issue - files that may be exposed
#[derive(Debug, Clone, Serialize)]
pub struct SecurityIssue {
    pub file: PathBuf,
    pub project: String,
    pub issue_type: SecurityIssueType,
    pub severity: Severity,
    pub variable_count: usize,
    pub has_sensitive_providers: bool,
}

/// Type of security issue
#[derive(Debug, Clone, Serialize, PartialEq)]
pub enum SecurityIssueType {
    /// File is tracked by git (committed)
    GitTracked,
    /// File exists but not in .gitignore
    NotInGitignore,
    /// File is in .gitignore but was previously committed
    WasCommitted,
}

impl std::fmt::Display for SecurityIssueType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SecurityIssueType::GitTracked => write!(f, "Tracked by git"),
            SecurityIssueType::NotInGitignore => write!(f, "Not in .gitignore"),
            SecurityIssueType::WasCommitted => write!(f, "Previously committed"),
        }
    }
}

/// Severity level
#[derive(Debug, Clone, Serialize, PartialEq, Eq, PartialOrd, Ord)]
pub enum Severity {
    Critical,  // File is tracked and has sensitive secrets
    High,      // File is tracked
    Medium,    // Not in .gitignore
    Low,       // Was committed but now ignored
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

    let is_quiet = cmd.json || cmd.fix_dry_run;
    if !is_quiet && !cmd.summary {
        println!("Scanning {} for .env files...", root_path.display());
        println!();
    }

    // Perform the scan
    let report = scan_directory(&root_path, cmd.max_depth, cmd.provider.as_deref())?;

    // Handle fix mode first (dry-run or actual fix)
    if cmd.fix_dry_run || cmd.fix {
        return handle_fix_mode(&report, cmd.fix_dry_run);
    }

    // Handle output exports
    if let Some(export_path) = &cmd.export {
        let json = serde_json::to_string_pretty(&report)?;
        fs::write(export_path, &json)?;
        if !cmd.json {
            println!("Report exported to {}", export_path.display());
        }
    }

    if let Some(html_path) = &cmd.html {
        let html = generate_html_report(&report)?;
        fs::write(html_path, &html)?;
        println!("HTML report generated: {}", html_path.display());
        println!("Open in browser: file://{}", html_path.canonicalize()?.display());
    }

    if cmd.json {
        println!("{}", serde_json::to_string_pretty(&report)?);
    } else if cmd.summary {
        display_summary(&report);
    } else if cmd.duplicates {
        display_duplicates_only(&report);
    } else if cmd.security {
        display_security_only(&report);
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
    let mut file_secrets_count: HashMap<PathBuf, usize> = HashMap::new();
    let mut file_has_sensitive: HashMap<PathBuf, bool> = HashMap::new();

    // Walk directory tree
    for entry in WalkDir::new(root)
        .max_depth(max_depth)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| !is_hidden(e) && !is_ignored_dir(e))
    {
        // Skip entries we can't access (permission denied, etc.)
        let entry = match entry {
            Ok(e) => e,
            Err(err) => {
                // Log the error but continue scanning
                if let Some(path) = err.path() {
                    eprintln!("Warning: Skipping {} ({})", path.display(),
                        err.io_error().map(|e| e.to_string()).unwrap_or_else(|| "unknown error".to_string()));
                }
                continue;
            }
        };
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
                let secret_count = secrets.len();
                let has_sensitive = secrets.iter().any(|s| is_sensitive_provider(s.provider.as_deref()));

                file_secrets_count.insert(path.to_path_buf(), secret_count);
                file_has_sensitive.insert(path.to_path_buf(), has_sensitive);

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

    // Detect security issues
    let security_issues = detect_security_issues(
        &env_files,
        &project_map,
        &file_secrets_count,
        &file_has_sensitive,
    );

    // Build summary
    let summary = Summary {
        total_files: env_files.len(),
        total_projects: projects.len(),
        total_variables: all_secrets.len(),
        unique_variables: variables.len(),
        duplicate_count: duplicates.len(),
        security_issue_count: security_issues.len(),
        providers_found: collect_providers(&all_secrets),
    };

    Ok(ScanReport {
        scanned_at: chrono_now(),
        root_path: root.to_path_buf(),
        projects,
        variables,
        duplicates,
        security_issues,
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

/// Check if a provider is considered sensitive (API keys, payment, etc.)
fn is_sensitive_provider(provider: Option<&str>) -> bool {
    matches!(
        provider,
        Some("openai") | Some("anthropic") | Some("stripe") | Some("aws") |
        Some("github") | Some("gitlab") | Some("twilio") | Some("sendgrid") |
        Some("firebase") | Some("database") | Some("redis") | Some("supabase")
    )
}

/// Detect security issues for .env files
fn detect_security_issues(
    env_files: &[PathBuf],
    project_map: &HashMap<PathBuf, Vec<PathBuf>>,
    file_secrets_count: &HashMap<PathBuf, usize>,
    file_has_sensitive: &HashMap<PathBuf, bool>,
) -> Vec<SecurityIssue> {
    let mut issues: Vec<SecurityIssue> = Vec::new();

    for file in env_files {
        // Find the project for this file
        let project_name = project_map
            .iter()
            .find(|(_, files)| files.contains(file))
            .map(|(path, _)| get_project_name(path))
            .unwrap_or_else(|| "unknown".to_string());

        let variable_count = *file_secrets_count.get(file).unwrap_or(&0);
        let has_sensitive = *file_has_sensitive.get(file).unwrap_or(&false);

        // Check git status for this file
        if let Some(issue_type) = check_git_status(file) {
            let severity = match (&issue_type, has_sensitive) {
                (SecurityIssueType::GitTracked, true) => Severity::Critical,
                (SecurityIssueType::GitTracked, false) => Severity::High,
                (SecurityIssueType::NotInGitignore, _) => Severity::Medium,
                (SecurityIssueType::WasCommitted, _) => Severity::Low,
            };

            issues.push(SecurityIssue {
                file: file.clone(),
                project: project_name,
                issue_type,
                severity,
                variable_count,
                has_sensitive_providers: has_sensitive,
            });
        }
    }

    // Sort by severity (Critical first)
    issues.sort_by(|a, b| a.severity.cmp(&b.severity));
    issues
}

/// Check if file is an example/template file (not a security concern)
fn is_example_file(file: &Path) -> bool {
    let name = file.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_lowercase();

    // Example files with placeholder values - not security concerns
    name.contains("example") ||
    name.contains("sample") ||
    name.contains("template") ||
    name.contains(".dist") ||
    name.ends_with(".example") ||
    name.ends_with(".sample") ||
    name.ends_with(".template")
}

/// Check git status of a file
/// Returns None if file is properly ignored, Some(issue_type) if there's a problem
fn check_git_status(file: &Path) -> Option<SecurityIssueType> {
    // Skip example/template files - they're meant to be committed
    if is_example_file(file) {
        return None;
    }

    // Find the git repository root
    let git_root = find_git_root(file)?;

    // Get relative path from git root
    let rel_path = file.strip_prefix(&git_root).ok()?;

    // Check if file is tracked by git
    let is_tracked = Command::new("git")
        .args(["ls-files", "--error-unmatch"])
        .arg(rel_path)
        .current_dir(&git_root)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if is_tracked {
        return Some(SecurityIssueType::GitTracked);
    }

    // Check if file is ignored by .gitignore
    let is_ignored = Command::new("git")
        .args(["check-ignore", "-q"])
        .arg(rel_path)
        .current_dir(&git_root)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    if !is_ignored {
        // File exists but is not in .gitignore
        // Check if it was ever committed (in git history)
        let was_committed = Command::new("git")
            .args(["log", "--follow", "--diff-filter=D", "--", rel_path.to_str().unwrap_or("")])
            .current_dir(&git_root)
            .output()
            .map(|o| !o.stdout.is_empty())
            .unwrap_or(false);

        if was_committed {
            return Some(SecurityIssueType::WasCommitted);
        }

        return Some(SecurityIssueType::NotInGitignore);
    }

    // File is properly ignored
    None
}

/// Find the git repository root for a file
fn find_git_root(file: &Path) -> Option<PathBuf> {
    let dir = file.parent()?;

    Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .current_dir(dir)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| {
            String::from_utf8(o.stdout)
                .ok()
                .map(|s| PathBuf::from(s.trim()))
        })
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

    // Security issues
    if !report.security_issues.is_empty() {
        println!();
        display_security_section(&report.security_issues);
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

    // Security recommendations first (highest priority)
    let critical_count = report.security_issues.iter()
        .filter(|i| i.severity == Severity::Critical)
        .count();
    let exposed_count = report.security_issues.iter()
        .filter(|i| i.issue_type == SecurityIssueType::GitTracked)
        .count();

    if critical_count > 0 {
        println!("• 🔴 URGENT: {} file(s) with sensitive secrets are tracked by git!", critical_count);
    }

    if exposed_count > 0 {
        println!("• {} .env file(s) are tracked by git - run `sec scan --security` for details", exposed_count);
    }

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
    println!("  Security issues:    {}", report.summary.security_issue_count);
    if !report.summary.providers_found.is_empty() {
        println!("  Providers:          {}", report.summary.providers_found.join(", "));
    }
    println!("{}", "─".repeat(40));
}

/// Display security issues only
fn display_security_only(report: &ScanReport) {
    if report.security_issues.is_empty() {
        println!("✓ No security issues found. All .env files are properly gitignored.");
        return;
    }

    display_security_section(&report.security_issues);
}

/// Display security section
fn display_security_section(issues: &[SecurityIssue]) {
    println!("SECURITY ISSUES");
    println!("{}", "─".repeat(80));

    // Group by severity
    let critical: Vec<_> = issues.iter().filter(|i| i.severity == Severity::Critical).collect();
    let high: Vec<_> = issues.iter().filter(|i| i.severity == Severity::High).collect();
    let medium: Vec<_> = issues.iter().filter(|i| i.severity == Severity::Medium).collect();
    let low: Vec<_> = issues.iter().filter(|i| i.severity == Severity::Low).collect();

    if !critical.is_empty() {
        println!();
        println!("🔴 CRITICAL ({}) - Secrets committed to git with sensitive API keys!", critical.len());
        println!();
        for issue in &critical {
            display_security_issue(issue);
        }
    }

    if !high.is_empty() {
        println!();
        println!("🟠 HIGH ({}) - Files tracked by git", high.len());
        println!();
        for issue in &high {
            display_security_issue(issue);
        }
    }

    if !medium.is_empty() {
        println!();
        println!("🟡 MEDIUM ({}) - Files not in .gitignore", medium.len());
        println!();
        for issue in &medium {
            display_security_issue(issue);
        }
    }

    if !low.is_empty() {
        println!();
        println!("🔵 LOW ({}) - Files were previously committed", low.len());
        println!();
        for issue in &low {
            display_security_issue(issue);
        }
    }

    println!();
    println!("{}", "─".repeat(80));
    println!();
    println!("REMEDIATION STEPS:");
    println!();

    if !critical.is_empty() || !high.is_empty() {
        println!("For tracked files:");
        println!("  1. Add to .gitignore: echo '.env*' >> .gitignore");
        println!("  2. Remove from git: git rm --cached <file>");
        println!("  3. Rotate ALL secrets that were exposed");
        println!("  4. Consider using BFG or git-filter-repo to remove from history");
        println!();
    }

    if !medium.is_empty() {
        println!("For untracked files not in .gitignore:");
        println!("  1. Add to .gitignore: echo '.env*' >> .gitignore");
        println!("  2. Or use global gitignore: git config --global core.excludesfile ~/.gitignore");
        println!();
    }

    println!("To migrate secrets to Secretariat:");
    println!("  sec import --scan .");
}

/// Display a single security issue
fn display_security_issue(issue: &SecurityIssue) {
    let sensitive_marker = if issue.has_sensitive_providers { " 🔑" } else { "" };
    let file_name = issue.file.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("?");

    println!("  {} {}/{}{}",
        match issue.severity {
            Severity::Critical => "🔴",
            Severity::High => "🟠",
            Severity::Medium => "🟡",
            Severity::Low => "🔵",
        },
        issue.project,
        file_name,
        sensitive_marker
    );
    println!("     Issue: {}", issue.issue_type);
    println!("     Variables: {}", issue.variable_count);
}

/// Truncate string for display
fn truncate_str(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        s.to_string()
    } else {
        format!("{}…", &s[..max_len - 1])
    }
}

/// Handle fix mode - add .env* to .gitignore files
fn handle_fix_mode(report: &ScanReport, dry_run: bool) -> Result<()> {
    if report.security_issues.is_empty() {
        println!("✓ No security issues to fix. All .env files are properly gitignored.");
        return Ok(());
    }

    // Group issues by git repository root
    let mut repos_to_fix: HashMap<PathBuf, Vec<&SecurityIssue>> = HashMap::new();

    for issue in &report.security_issues {
        // Only fix NotInGitignore issues (tracked files need manual intervention)
        if issue.issue_type == SecurityIssueType::NotInGitignore {
            if let Some(git_root) = find_git_root(&issue.file) {
                repos_to_fix.entry(git_root).or_default().push(issue);
            }
        }
    }

    if repos_to_fix.is_empty() {
        println!("No automatically fixable issues found.");
        println!();
        println!("Issues that require manual intervention:");
        for issue in &report.security_issues {
            if issue.issue_type == SecurityIssueType::GitTracked {
                println!("  • {} - File is tracked by git", issue.file.display());
                println!("    Fix: git rm --cached {} && add to .gitignore", issue.file.display());
            }
        }
        return Ok(());
    }

    let mode_str = if dry_run { "DRY RUN" } else { "FIXING" };
    println!("{}: Adding .env* to .gitignore files", mode_str);
    println!("{}", "─".repeat(60));
    println!();

    let mut fixed_count = 0;
    let mut skipped_count = 0;

    for (git_root, issues) in &repos_to_fix {
        let gitignore_path = git_root.join(".gitignore");
        let project_name = get_project_name(git_root);

        // Check if .gitignore already has .env* pattern
        let already_has_pattern = if gitignore_path.exists() {
            fs::read_to_string(&gitignore_path)
                .map(|content| {
                    content.lines().any(|line| {
                        let trimmed = line.trim();
                        trimmed == ".env*" || trimmed == ".env" || trimmed == "*.env"
                    })
                })
                .unwrap_or(false)
        } else {
            false
        };

        if already_has_pattern {
            println!("  ⏭️  {} - .gitignore already has .env pattern", project_name);
            skipped_count += 1;
            continue;
        }

        println!("  📁 {} ({} issue(s))", project_name, issues.len());
        println!("     Path: {}", gitignore_path.display());

        for issue in issues {
            let file_name = issue.file.file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("?");
            println!("     • {}", file_name);
        }

        if dry_run {
            println!("     → Would add '.env*' to .gitignore");
        } else {
            // Actually add to .gitignore
            let entry = "\n# Environment files (added by sec scan --fix)\n.env*\n";
            let mut file = fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(&gitignore_path)
                .with_context(|| format!("Failed to open {}", gitignore_path.display()))?;

            use std::io::Write;
            file.write_all(entry.as_bytes())
                .with_context(|| format!("Failed to write to {}", gitignore_path.display()))?;

            println!("     ✓ Added '.env*' to .gitignore");
        }

        fixed_count += 1;
        println!();
    }

    println!("{}", "─".repeat(60));
    println!();

    if dry_run {
        println!("DRY RUN SUMMARY:");
        println!("  Would fix: {} repository(ies)", fixed_count);
        println!("  Skipped:   {} (already configured)", skipped_count);
        println!();
        println!("To apply these fixes, run: sec scan --fix");
    } else {
        println!("FIX SUMMARY:");
        println!("  Fixed:   {} repository(ies)", fixed_count);
        println!("  Skipped: {} (already configured)", skipped_count);
    }

    // Show tracked files that need manual intervention
    let tracked_issues: Vec<_> = report.security_issues.iter()
        .filter(|i| i.issue_type == SecurityIssueType::GitTracked)
        .collect();

    if !tracked_issues.is_empty() {
        println!();
        println!("⚠️  {} file(s) are TRACKED by git and need manual intervention:", tracked_issues.len());
        for issue in tracked_issues {
            println!("  • {}", issue.file.display());
        }
        println!();
        println!("To fix tracked files:");
        println!("  1. git rm --cached <file>");
        println!("  2. Commit the removal");
        println!("  3. Rotate any exposed secrets!");
    }

    Ok(())
}

/// Generate HTML report
fn generate_html_report(report: &ScanReport) -> Result<String> {
    let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string();

    let html = format!(r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Secretariat Scan Report</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --text-primary: #e6edf3;
            --text-secondary: #8b949e;
            --border-color: #30363d;
            --accent: #58a6ff;
            --success: #3fb950;
            --warning: #d29922;
            --error: #f85149;
            --critical: #ff7b72;
        }}

        * {{ box-sizing: border-box; margin: 0; padding: 0; }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 20px;
        }}

        .container {{ max-width: 1200px; margin: 0 auto; }}

        header {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
        }}

        header h1 {{
            font-size: 24px;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 12px;
        }}

        header h1::before {{
            content: '🔐';
            font-size: 28px;
        }}

        .meta {{ color: var(--text-secondary); font-size: 14px; }}

        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 16px;
            margin: 24px 0;
        }}

        .stat-card {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 16px;
            text-align: center;
        }}

        .stat-card .value {{
            font-size: 32px;
            font-weight: bold;
            color: var(--accent);
        }}

        .stat-card.warning .value {{ color: var(--warning); }}
        .stat-card.error .value {{ color: var(--error); }}
        .stat-card.success .value {{ color: var(--success); }}

        .stat-card .label {{
            color: var(--text-secondary);
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        section {{
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            margin-bottom: 24px;
            overflow: hidden;
        }}

        section h2 {{
            background: var(--bg-tertiary);
            padding: 16px 20px;
            font-size: 16px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        table {{
            width: 100%;
            border-collapse: collapse;
        }}

        th, td {{
            padding: 12px 16px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
        }}

        th {{
            background: var(--bg-tertiary);
            color: var(--text-secondary);
            font-weight: 500;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        tr:last-child td {{ border-bottom: none; }}
        tr:hover td {{ background: var(--bg-tertiary); }}

        .badge {{
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
        }}

        .badge-critical {{ background: rgba(255, 123, 114, 0.2); color: var(--critical); }}
        .badge-high {{ background: rgba(248, 81, 73, 0.2); color: var(--error); }}
        .badge-medium {{ background: rgba(210, 153, 34, 0.2); color: var(--warning); }}
        .badge-low {{ background: rgba(63, 185, 80, 0.2); color: var(--success); }}
        .badge-duplicate {{ background: rgba(210, 153, 34, 0.2); color: var(--warning); }}
        .badge-unique {{ background: rgba(63, 185, 80, 0.2); color: var(--success); }}
        .badge-provider {{ background: rgba(88, 166, 255, 0.2); color: var(--accent); }}

        .provider-list {{ display: flex; gap: 4px; flex-wrap: wrap; }}

        .mono {{ font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace; font-size: 13px; }}

        .empty {{ padding: 40px; text-align: center; color: var(--text-secondary); }}

        .security-item {{
            padding: 16px 20px;
            border-bottom: 1px solid var(--border-color);
        }}

        .security-item:last-child {{ border-bottom: none; }}

        .security-item .header {{
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }}

        .security-item .file {{ font-weight: 500; }}
        .security-item .details {{ color: var(--text-secondary); font-size: 14px; }}

        footer {{
            text-align: center;
            padding: 24px;
            color: var(--text-secondary);
            font-size: 14px;
        }}

        footer a {{ color: var(--accent); text-decoration: none; }}
        footer a:hover {{ text-decoration: underline; }}

        .btn {{
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 500;
            text-decoration: none;
            transition: all 0.2s ease;
            border: 1px solid transparent;
        }}

        .btn-vscode {{
            background: rgba(0, 122, 204, 0.15);
            color: #007ACC;
            border-color: rgba(0, 122, 204, 0.3);
        }}

        .btn-vscode:hover {{
            background: rgba(0, 122, 204, 0.25);
            border-color: rgba(0, 122, 204, 0.5);
        }}

        .btn-vscode svg {{
            width: 14px;
            height: 14px;
            fill: currentColor;
        }}

        @media (max-width: 768px) {{
            .stats {{ grid-template-columns: repeat(2, 1fr); }}
            th, td {{ padding: 8px 12px; font-size: 14px; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Secretariat Scan Report</h1>
            <p class="meta">Generated: {timestamp} | Path: {root_path}</p>
        </header>

        <div class="stats">
            <div class="stat-card">
                <div class="value">{total_files}</div>
                <div class="label">Files Scanned</div>
            </div>
            <div class="stat-card">
                <div class="value">{total_projects}</div>
                <div class="label">Projects Found</div>
            </div>
            <div class="stat-card">
                <div class="value">{unique_variables}</div>
                <div class="label">Unique Variables</div>
            </div>
            <div class="stat-card warning">
                <div class="value">{duplicate_count}</div>
                <div class="label">Duplicates</div>
            </div>
            <div class="stat-card {security_class}">
                <div class="value">{security_issue_count}</div>
                <div class="label">Security Issues</div>
            </div>
        </div>

        {security_section}

        {projects_section}

        {variables_section}

        {duplicates_section}

        <footer>
            <p>Generated by <a href="https://github.com/secretariat">Secretariat</a> &mdash; Local-first secrets management</p>
        </footer>
    </div>
</body>
</html>"#,
        timestamp = timestamp,
        root_path = report.root_path.display(),
        total_files = report.summary.total_files,
        total_projects = report.summary.total_projects,
        unique_variables = report.summary.unique_variables,
        duplicate_count = report.summary.duplicate_count,
        security_issue_count = report.summary.security_issue_count,
        security_class = if report.summary.security_issue_count > 0 { "error" } else { "success" },
        security_section = generate_html_security_section(&report.security_issues),
        projects_section = generate_html_projects_section(&report.projects),
        variables_section = generate_html_variables_section(&report.variables),
        duplicates_section = generate_html_duplicates_section(&report.duplicates),
    );

    Ok(html)
}

/// Generate HTML security section
fn generate_html_security_section(issues: &[SecurityIssue]) -> String {
    if issues.is_empty() {
        return r#"
        <section>
            <h2>🛡️ Security Status</h2>
            <div class="empty">✅ No security issues found. All .env files are properly gitignored.</div>
        </section>
        "#.to_string();
    }

    let mut rows = String::new();
    for issue in issues {
        let severity_badge = match issue.severity {
            Severity::Critical => r#"<span class="badge badge-critical">🔴 Critical</span>"#,
            Severity::High => r#"<span class="badge badge-high">🟠 High</span>"#,
            Severity::Medium => r#"<span class="badge badge-medium">🟡 Medium</span>"#,
            Severity::Low => r#"<span class="badge badge-low">🔵 Low</span>"#,
        };

        let file_name = issue.file.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("?");

        let sensitive = if issue.has_sensitive_providers { "🔑" } else { "" };

        rows.push_str(&format!(
            r#"<tr>
                <td>{severity}</td>
                <td class="mono">{project}/{file} {sensitive}</td>
                <td>{issue_type}</td>
                <td>{variables}</td>
            </tr>"#,
            severity = severity_badge,
            project = html_escape(&issue.project),
            file = html_escape(file_name),
            sensitive = sensitive,
            issue_type = issue.issue_type,
            variables = issue.variable_count,
        ));
    }

    format!(
        r#"
        <section>
            <h2>🛡️ Security Issues ({count})</h2>
            <table>
                <thead>
                    <tr>
                        <th>Severity</th>
                        <th>File</th>
                        <th>Issue</th>
                        <th>Variables</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </section>
        "#,
        count = issues.len(),
        rows = rows,
    )
}

/// Generate HTML projects section
fn generate_html_projects_section(projects: &[Project]) -> String {
    if projects.is_empty() {
        return String::new();
    }

    let mut rows = String::new();
    for project in projects {
        let providers = if project.providers.is_empty() {
            "-".to_string()
        } else {
            project.providers.iter()
                .map(|p| format!(r#"<span class="badge badge-provider">{}</span>"#, html_escape(p)))
                .collect::<Vec<_>>()
                .join(" ")
        };

        // VS Code URL for opening project folder
        let vscode_url = format!("vscode://file{}", html_escape(&project.path.to_string_lossy()));

        rows.push_str(&format!(
            r#"<tr>
                <td class="mono">{name}</td>
                <td>{files}</td>
                <td>{variables}</td>
                <td class="provider-list">{providers}</td>
                <td>
                    <a href="{vscode_url}" class="btn btn-vscode" title="Open in VS Code">
                        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path d="M17.583 2.91a1.89 1.89 0 0 1 2.385.458l2.33 2.94a1.89 1.89 0 0 1-.252 2.646L9.218 19.093a1.89 1.89 0 0 1-1.247.407l-4.1-.21a1.89 1.89 0 0 1-1.754-1.562L.536 8.972A1.89 1.89 0 0 1 1.5 6.823l3.147-1.4a1.89 1.89 0 0 1 1.577.044l4.524 2.262 6.835-4.82z"/>
                        </svg>
                        Open
                    </a>
                </td>
            </tr>"#,
            name = html_escape(&project.name),
            files = project.files.len(),
            variables = project.variable_count,
            providers = providers,
            vscode_url = vscode_url,
        ));
    }

    format!(
        r#"
        <section>
            <h2>📁 Projects ({count})</h2>
            <table>
                <thead>
                    <tr>
                        <th>Project</th>
                        <th>Files</th>
                        <th>Variables</th>
                        <th>Providers</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </section>
        "#,
        count = projects.len(),
        rows = rows,
    )
}

/// Generate HTML variables section
fn generate_html_variables_section(variables: &[Variable]) -> String {
    if variables.is_empty() {
        return String::new();
    }

    let mut rows = String::new();
    for var in variables {
        let provider = var.provider.as_ref()
            .map(|p| format!(r#"<span class="badge badge-provider">{}</span>"#, html_escape(p)))
            .unwrap_or_else(|| "-".to_string());

        let status = if var.is_duplicate {
            r#"<span class="badge badge-duplicate">⚠️ Duplicate</span>"#
        } else {
            r#"<span class="badge badge-unique">✓ Unique</span>"#
        };

        rows.push_str(&format!(
            r#"<tr>
                <td class="mono">{name}</td>
                <td>{occurrences}</td>
                <td>{provider}</td>
                <td>{status}</td>
            </tr>"#,
            name = html_escape(&var.name),
            occurrences = var.occurrences.len(),
            provider = provider,
            status = status,
        ));
    }

    format!(
        r#"
        <section>
            <h2>🔑 Variables ({count})</h2>
            <table>
                <thead>
                    <tr>
                        <th>Variable</th>
                        <th>Occurrences</th>
                        <th>Provider</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
        </section>
        "#,
        count = variables.len(),
        rows = rows,
    )
}

/// Generate HTML duplicates section
fn generate_html_duplicates_section(duplicates: &[Duplicate]) -> String {
    if duplicates.is_empty() {
        return String::new();
    }

    let mut items = String::new();
    for dup in duplicates {
        let mut occurrences_html = String::new();
        for occ in &dup.occurrences {
            let file_name = occ.file.file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("?");
            occurrences_html.push_str(&format!(
                r#"<tr>
                    <td class="mono">{project}/{file}</td>
                    <td class="mono">{value}</td>
                </tr>"#,
                project = html_escape(&occ.project),
                file = html_escape(file_name),
                value = html_escape(&occ.masked_value),
            ));
        }

        items.push_str(&format!(
            r#"
            <div class="security-item">
                <div class="header">
                    <span class="badge badge-duplicate">⚠️ {unique_values} different value(s)</span>
                    <span class="file mono">{name}</span>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>Location</th>
                            <th>Value (masked)</th>
                        </tr>
                    </thead>
                    <tbody>
                        {occurrences}
                    </tbody>
                </table>
            </div>
            "#,
            name = html_escape(&dup.name),
            unique_values = dup.unique_values,
            occurrences = occurrences_html,
        ));
    }

    format!(
        r#"
        <section>
            <h2>⚠️ Duplicates ({count})</h2>
            {items}
        </section>
        "#,
        count = duplicates.len(),
        items = items,
    )
}

/// Escape HTML special characters
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
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

    #[test]
    fn test_is_example_file() {
        // Should be recognized as example files (excluded from security scan)
        assert!(is_example_file(Path::new(".env.example")));
        assert!(is_example_file(Path::new(".env.sample")));
        assert!(is_example_file(Path::new(".env.template")));
        assert!(is_example_file(Path::new(".env.dist")));
        assert!(is_example_file(Path::new("example.env")));
        assert!(is_example_file(Path::new(".env.local.example")));

        // Should NOT be recognized as example files (included in security scan)
        assert!(!is_example_file(Path::new(".env")));
        assert!(!is_example_file(Path::new(".env.local")));
        assert!(!is_example_file(Path::new(".env.production")));
        assert!(!is_example_file(Path::new(".env.development")));
    }
}

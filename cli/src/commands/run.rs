//! `sec run` — run a command with secrets injected into its environment.
//!
//! THE mission feature: secrets never touch a file, the shell history, or an
//! AI agent's context. Plaintext exists only in daemon memory and the child
//! process environment.
//!
//! - Secret names come from a committable `.secretariat.toml` project manifest
//!   (names only, never values) and/or repeated `--secret` flags.
//! - If the vault is locked, we attempt a Keychain unlock (`vault.unlock_keychain`)
//!   before giving up.
//! - The child's stdout/stderr are scrubbed: any occurrence of an injected
//!   secret value is replaced with `[REDACTED:NAME]` before it reaches the
//!   caller (so an agent driving `sec run` never sees a leaked value).
//!   `--no-redact` inherits stdio directly instead (interactive/TTY tools).

use crate::client::DaemonClient;
use anyhow::{bail, Context, Result};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub const MANIFEST_NAME: &str = ".secretariat.toml";

/// Arguments for `sec run` (mirrored by the clap struct in main.rs).
pub struct RunArgs {
    /// Explicit manifest path (default: walk up from cwd for .secretariat.toml)
    pub manifest: Option<PathBuf>,
    /// Ad-hoc secrets: "NAME" or "ENV_VAR=NAME", repeatable
    pub secrets: Vec<String>,
    /// Inherit stdio instead of scrubbing (for TTY/interactive children)
    pub no_redact: bool,
    /// The command to run (after `--`)
    pub command: Vec<String>,
}

/// env var name -> vault secret name
pub type SecretMap = BTreeMap<String, String>;

/// Locate the manifest by walking up from `start` to the filesystem root.
pub fn find_manifest(start: &Path) -> Option<PathBuf> {
    let mut dir = Some(start);
    while let Some(d) = dir {
        let candidate = d.join(MANIFEST_NAME);
        if candidate.is_file() {
            return Some(candidate);
        }
        dir = d.parent();
    }
    None
}

/// Parse a `.secretariat.toml` manifest. Two accepted shapes:
///
/// ```toml
/// # mapping form: ENV_VAR = "vault-secret-name"
/// [secrets]
/// OPENAI_API_KEY = "OPENAI_API_KEY"
/// DB_PASSWORD = "myapp/db_password"
/// ```
///
/// ```toml
/// # list form: env var == vault name
/// secrets = ["OPENAI_API_KEY", "STRIPE_KEY"]
/// ```
pub fn parse_manifest(path: &Path) -> Result<SecretMap> {
    let text = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read manifest {}", path.display()))?;
    let doc: toml::Value = text
        .parse()
        .with_context(|| format!("Invalid TOML in {}", path.display()))?;

    let mut map = SecretMap::new();
    match doc.get("secrets") {
        Some(toml::Value::Table(t)) => {
            for (env_var, v) in t {
                let name = v.as_str().with_context(|| {
                    format!("[secrets] {env_var} must be a string (vault secret name)")
                })?;
                map.insert(env_var.clone(), name.to_string());
            }
        }
        Some(toml::Value::Array(a)) => {
            for v in a {
                let name = v
                    .as_str()
                    .context("secrets list entries must be strings")?;
                map.insert(name.to_string(), name.to_string());
            }
        }
        Some(_) => bail!("'secrets' must be a table or a list of names"),
        None => bail!(
            "No 'secrets' entry in {} — add [secrets] ENV_VAR = \"vault-name\"",
            path.display()
        ),
    }
    Ok(map)
}

/// Parse an ad-hoc `--secret` flag: "NAME" or "ENV_VAR=NAME".
fn parse_secret_flag(s: &str) -> (String, String) {
    match s.split_once('=') {
        Some((env_var, name)) => (env_var.to_string(), name.to_string()),
        None => (s.to_string(), s.to_string()),
    }
}

/// Make sure the vault is unlocked; try the Keychain key if it isn't.
pub async fn ensure_unlocked(client: &DaemonClient) -> Result<()> {
    let status: Value = client.request("vault.status", json!({})).await?;
    if status.get("state").and_then(|v| v.as_str()) != Some("locked") {
        return Ok(());
    }
    let unlocked: Result<Value> = client.request("vault.unlock_keychain", json!({})).await;
    match unlocked {
        Ok(_) => Ok(()),
        Err(e) => bail!(
            "Vault is locked and Keychain unlock failed ({}).\n\
             Unlock once with the app or `sec unlock`, then retry.",
            e
        ),
    }
}

/// Fetch the values for a secret map from the daemon.
/// Returns (env var, vault name, value) triples.
pub async fn fetch_secrets(
    client: &DaemonClient,
    map: &SecretMap,
) -> Result<Vec<(String, String, String)>> {
    ensure_unlocked(client).await?;
    let mut out = Vec::with_capacity(map.len());
    for (env_var, name) in map {
        let resp: Value = client
            .request("secret.get", json!({ "name": name, "app_id": "cli" }))
            .await
            .with_context(|| format!("Failed to fetch secret '{name}'"))?;
        let value = resp
            .get("value")
            .and_then(|v| v.as_str())
            .with_context(|| format!("Malformed response for secret '{name}'"))?
            .to_string();
        out.push((env_var.clone(), name.clone(), value));
    }
    Ok(out)
}

/// Build the redaction list: (plaintext value, replacement), longest values
/// first so overlapping/substring secrets redact correctly.
pub fn redactions(secrets: &[(String, String, String)]) -> Vec<(String, String)> {
    let mut r: Vec<(String, String)> = secrets
        .iter()
        .filter(|(_, _, value)| value.len() >= 4) // don't shred output over trivial values
        .map(|(_, name, value)| (value.clone(), format!("[REDACTED:{name}]")))
        .collect();
    r.sort_by(|a, b| b.0.len().cmp(&a.0.len()));
    r
}

pub fn redact_line(line: &str, redactions: &[(String, String)]) -> String {
    let mut out = line.to_string();
    for (value, replacement) in redactions {
        if out.contains(value.as_str()) {
            out = out.replace(value.as_str(), replacement);
        }
    }
    out
}

/// Resolve the effective secret map from manifest + --secret flags.
pub fn resolve_secret_map(args_manifest: &Option<PathBuf>, flags: &[String]) -> Result<SecretMap> {
    let mut map = SecretMap::new();

    let manifest_path = match args_manifest {
        Some(p) => Some(p.clone()),
        None => find_manifest(&std::env::current_dir()?),
    };
    if let Some(p) = &manifest_path {
        map.extend(parse_manifest(p)?);
        eprintln!("sec run: manifest {}", p.display());
    }
    for flag in flags {
        let (env_var, name) = parse_secret_flag(flag);
        map.insert(env_var, name);
    }

    if map.is_empty() {
        bail!(
            "No secrets to inject: no {} found (searched up from the current \
             directory) and no --secret flags given.",
            MANIFEST_NAME
        );
    }
    Ok(map)
}

/// `sec run` entry point. On success this does not return — it exits with the
/// child's exit code.
pub async fn handle_run(client: DaemonClient, args: RunArgs) -> Result<()> {
    if args.command.is_empty() {
        bail!("No command given. Usage: sec run [--secret NAME]... -- <command> [args...]");
    }

    let map = resolve_secret_map(&args.manifest, &args.secrets)?;
    let secrets = fetch_secrets(&client, &map).await?;

    // Transparency on stderr: names only, never values.
    let names: Vec<&str> = secrets.iter().map(|(e, _, _)| e.as_str()).collect();
    eprintln!("sec run: injecting {} secret(s): {}", names.len(), names.join(", "));

    let program = &args.command[0];
    let prog_args = &args.command[1..];

    let mut cmd = Command::new(program);
    cmd.args(prog_args);
    for (env_var, _, value) in &secrets {
        cmd.env(env_var, value);
    }

    let status = if args.no_redact {
        // Inherit stdio: full TTY behavior, but no leak scrubbing.
        cmd.status()
            .with_context(|| format!("Failed to start '{program}'"))?
    } else {
        run_redacted(cmd, &redactions(&secrets), program)?
    };

    std::process::exit(status.code().unwrap_or(1));
}

/// Spawn with piped stdout/stderr and scrub secret values from both streams.
fn run_redacted(
    mut cmd: Command,
    redactions: &[(String, String)],
    program: &str,
) -> Result<std::process::ExitStatus> {
    cmd.stdin(Stdio::inherit())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    let mut child = cmd
        .spawn()
        .with_context(|| format!("Failed to start '{program}'"))?;

    let stdout = child.stdout.take().context("no stdout")?;
    let stderr = child.stderr.take().context("no stderr")?;

    let r1 = redactions.to_vec();
    let t_out = std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        let mut sink = std::io::stdout().lock();
        for line in reader.lines().map_while(Result::ok) {
            let _ = writeln!(sink, "{}", redact_line(&line, &r1));
        }
    });
    let r2 = redactions.to_vec();
    let t_err = std::thread::spawn(move || {
        let reader = BufReader::new(stderr);
        let mut sink = std::io::stderr().lock();
        for line in reader.lines().map_while(Result::ok) {
            let _ = writeln!(sink, "{}", redact_line(&line, &r2));
        }
    });

    let status = child.wait().context("Failed to wait for child")?;
    let _ = t_out.join();
    let _ = t_err.join();
    Ok(status)
}

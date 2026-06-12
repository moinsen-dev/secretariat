//! `sec mcp` — MCP server (stdio) for AI agents.
//!
//! Deliberately ASYMMETRIC capabilities: an agent can list secret NAMES, run
//! commands with secrets injected (output redacted), create secrets (write-
//! only, optionally generated server-side so the value never enters the
//! agent's context), and read the audit log. There is intentionally NO tool
//! that returns a secret value — that is the product's core promise:
//! "secrets your AI can use but never see".
//!
//! Transport: newline-delimited JSON-RPC 2.0 on stdin/stdout (MCP stdio).
//! stdout is the protocol channel — all diagnostics go to stderr.

use crate::client::DaemonClient;
use crate::commands::run;
use anyhow::Result;
use rand::Rng;
use serde_json::{json, Value};
use tokio::io::{stdin, stdout, AsyncBufReadExt, AsyncWriteExt, BufReader};

pub async fn serve(client: DaemonClient) -> Result<()> {
    eprintln!("[secretariat-mcp] ready (stdio)");
    let mut lines = BufReader::new(stdin()).lines();
    let mut out = stdout();

    while let Some(line) = lines.next_line().await? {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let msg: Value = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("[secretariat-mcp] bad JSON: {e}");
                continue;
            }
        };

        let id = msg.get("id").cloned();
        let method = msg.get("method").and_then(|m| m.as_str()).unwrap_or("");

        // Notifications (no id) need no response.
        let Some(id) = id else { continue };

        let response = match method {
            "initialize" => {
                let proto = msg
                    .pointer("/params/protocolVersion")
                    .and_then(|v| v.as_str())
                    .unwrap_or("2024-11-05");
                ok(id, json!({
                    "protocolVersion": proto,
                    "capabilities": { "tools": {} },
                    "serverInfo": {
                        "name": "secretariat",
                        "version": env!("CARGO_PKG_VERSION")
                    }
                }))
            }
            "ping" => ok(id, json!({})),
            "tools/list" => ok(id, json!({ "tools": tool_definitions() })),
            "tools/call" => {
                let name = msg
                    .pointer("/params/name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                let args = msg
                    .pointer("/params/arguments")
                    .cloned()
                    .unwrap_or_else(|| json!({}));
                match call_tool(&client, name, args).await {
                    Ok(text) => ok(id, json!({
                        "content": [{ "type": "text", "text": text }]
                    })),
                    Err(e) => ok(id, json!({
                        "content": [{ "type": "text", "text": format!("Error: {e:#}") }],
                        "isError": true
                    })),
                }
            }
            _ => json!({
                "jsonrpc": "2.0", "id": id,
                "error": { "code": -32601, "message": format!("Method not found: {method}") }
            }),
        };

        let mut bytes = serde_json::to_vec(&response)?;
        bytes.push(b'\n');
        out.write_all(&bytes).await?;
        out.flush().await?;
    }
    Ok(())
}

fn ok(id: Value, result: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": result })
}

fn tool_definitions() -> Value {
    json!([
        {
            "name": "list_secret_names",
            "description": "List the NAMES of all secrets in the vault (plus provider/environment metadata). Values are never returned by any tool.",
            "inputSchema": { "type": "object", "properties": {}, "additionalProperties": false }
        },
        {
            "name": "run_with_secrets",
            "description": "Run a shell command with secrets injected into its environment. Secret values never appear in the result: stdout/stderr are redacted ([REDACTED:NAME]). By default secrets come from the .secretariat.toml manifest found at cwd; pass 'secrets' to inject specific vault secrets instead. Use this instead of reading .env files or asking the user to paste keys.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "command": { "type": "string", "description": "Shell command, run via /bin/sh -c" },
                    "cwd": { "type": "string", "description": "Working directory (default: server cwd)" },
                    "secrets": {
                        "type": "array", "items": { "type": "string" },
                        "description": "Vault secret names to inject as same-named env vars (default: project manifest)"
                    },
                    "timeout_seconds": { "type": "number", "description": "Kill the command after this many seconds (default 120)" }
                },
                "required": ["command"],
                "additionalProperties": false
            }
        },
        {
            "name": "set_secret",
            "description": "Create or update a secret (write-only — no tool can read it back). Either pass 'value', or set 'generate': true to create a strong random value server-side that NEVER enters your context; use run_with_secrets to apply it afterwards.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "name": { "type": "string", "description": "Secret name, e.g. OPENAI_API_KEY" },
                    "value": { "type": "string", "description": "The secret value (omit when using generate)" },
                    "generate": { "type": "boolean", "description": "Generate a random value server-side instead of providing one" },
                    "length": { "type": "number", "description": "Generated value length (default 32)" }
                },
                "required": ["name"],
                "additionalProperties": false
            }
        },
        {
            "name": "read_audit",
            "description": "Read recent vault audit-log entries (who accessed which secret when). Useful to show the user what you did.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "limit": { "type": "number", "description": "Max entries (default 20)" }
                },
                "additionalProperties": false
            }
        }
    ])
}

async fn call_tool(client: &DaemonClient, name: &str, args: Value) -> Result<String> {
    match name {
        "list_secret_names" => {
            let resp: Value = client.request("secret.list", json!({})).await?;
            let list: Vec<Value> = resp
                .get("secrets")
                .and_then(|s| s.as_array())
                .map(|a| {
                    a.iter()
                        .map(|s| {
                            json!({
                                "name": s.get("name"),
                                "provider": s.get("provider"),
                                "environment": s.get("environment"),
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();
            Ok(serde_json::to_string_pretty(&json!({ "secrets": list }))?)
        }

        "run_with_secrets" => {
            let command = args
                .get("command")
                .and_then(|v| v.as_str())
                .ok_or_else(|| anyhow::anyhow!("'command' is required"))?;
            let cwd = args.get("cwd").and_then(|v| v.as_str());
            let timeout_s = args
                .get("timeout_seconds")
                .and_then(|v| v.as_f64())
                .unwrap_or(120.0);

            // Secret map: explicit list of vault names, or the project manifest.
            let map: run::SecretMap = match args.get("secrets").and_then(|v| v.as_array()) {
                Some(names) => names
                    .iter()
                    .filter_map(|v| v.as_str())
                    .map(|n| (n.to_string(), n.to_string()))
                    .collect(),
                None => {
                    let base = cwd
                        .map(std::path::PathBuf::from)
                        .unwrap_or(std::env::current_dir()?);
                    let manifest = run::find_manifest(&base).ok_or_else(|| {
                        anyhow::anyhow!(
                            "No {} found from {} — pass 'secrets' explicitly or create a manifest",
                            run::MANIFEST_NAME,
                            base.display()
                        )
                    })?;
                    run::parse_manifest(&manifest)?
                }
            };

            let secrets = run::fetch_secrets(client, &map).await?;
            let redactions = run::redactions(&secrets);

            let mut cmd = tokio::process::Command::new("/bin/sh");
            cmd.arg("-c").arg(command);
            if let Some(d) = cwd {
                cmd.current_dir(d);
            }
            for (env_var, _, value) in &secrets {
                cmd.env(env_var, value);
            }
            cmd.stdin(std::process::Stdio::null());
            cmd.kill_on_drop(true);

            let fut = cmd.output();
            let output = match tokio::time::timeout(
                std::time::Duration::from_secs_f64(timeout_s),
                fut,
            )
            .await
            {
                Ok(r) => r?,
                Err(_) => anyhow::bail!("Command timed out after {timeout_s}s and was killed"),
            };

            let scrub = |bytes: &[u8]| -> String {
                String::from_utf8_lossy(bytes)
                    .lines()
                    .map(|l| run::redact_line(l, &redactions))
                    .collect::<Vec<_>>()
                    .join("\n")
            };

            Ok(serde_json::to_string_pretty(&json!({
                "exit_code": output.status.code(),
                "injected": secrets.iter().map(|(e, _, _)| e.as_str()).collect::<Vec<_>>(),
                "stdout": scrub(&output.stdout),
                "stderr": scrub(&output.stderr),
            }))?)
        }

        "set_secret" => {
            let name = args
                .get("name")
                .and_then(|v| v.as_str())
                .ok_or_else(|| anyhow::anyhow!("'name' is required"))?;
            let generate = args.get("generate").and_then(|v| v.as_bool()).unwrap_or(false);
            let value = match (generate, args.get("value").and_then(|v| v.as_str())) {
                (true, _) => {
                    let len = args.get("length").and_then(|v| v.as_u64()).unwrap_or(32) as usize;
                    generate_secret(len)
                }
                (false, Some(v)) => v.to_string(),
                (false, None) => {
                    anyhow::bail!("Pass 'value', or 'generate': true for a server-side random value")
                }
            };

            run::ensure_unlocked(client).await?;
            let _: Value = client
                .request("secret.set", json!({ "name": name, "value": value }))
                .await?;
            Ok(format!(
                "Secret '{name}' stored ({}). No tool can read it back; use run_with_secrets to use it.",
                if generate { "generated server-side, value not disclosed" } else { "value provided" }
            ))
        }

        "read_audit" => {
            let limit = args.get("limit").and_then(|v| v.as_u64()).unwrap_or(20);
            let resp: Value = client
                .request("audit.log", json!({ "limit": limit }))
                .await?;
            Ok(serde_json::to_string_pretty(&resp)?)
        }

        other => anyhow::bail!("Unknown tool: {other}"),
    }
}

/// Random secret: alphanumeric + a few symbols, cryptographically secure RNG.
fn generate_secret(len: usize) -> String {
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_!@#%^";
    let mut rng = rand::thread_rng();
    (0..len.clamp(8, 256))
        .map(|_| CHARSET[rng.gen_range(0..CHARSET.len())] as char)
        .collect()
}

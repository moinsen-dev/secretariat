//! Provider command - Guided onboarding for API key providers
//!
//! Provides guided setup workflows for common API providers like OpenAI,
//! Anthropic, Stripe, etc. with best practices and validation.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// Arguments for the provider command
pub struct ProviderCommand {
    /// Subcommand to execute
    pub action: ProviderAction,
}

/// Provider subcommands
pub enum ProviderAction {
    /// List all supported providers
    List { json: bool },
    /// Show information about a specific provider
    Info { name: String },
    /// Start guided onboarding for a provider
    Add { name: String, environment: Option<String> },
}

/// Provider metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub category: String,
    pub docs_url: String,
    pub key_pattern: String,
    pub key_prefix: String,
    pub recommended_key_names: Vec<String>,
    pub rotation_days: Option<u32>,
    pub best_practices: Vec<String>,
}

/// Built-in provider configurations
fn get_provider_configs() -> Vec<ProviderInfo> {
    vec![
        ProviderInfo {
            id: "openai".to_string(),
            name: "OpenAI".to_string(),
            description: "GPT models, DALL-E, Whisper, and more".to_string(),
            category: "AI/ML".to_string(),
            docs_url: "https://platform.openai.com/api-keys".to_string(),
            key_pattern: r"^sk-[a-zA-Z0-9]{48,}$".to_string(),
            key_prefix: "sk-".to_string(),
            recommended_key_names: vec!["OPENAI_API_KEY".to_string()],
            rotation_days: Some(90),
            best_practices: vec![
                "Use project-specific API keys, not your main account key".to_string(),
                "Set usage limits in the OpenAI dashboard".to_string(),
                "Use separate keys for dev/staging/production".to_string(),
                "Monitor usage at platform.openai.com/usage".to_string(),
            ],
        },
        ProviderInfo {
            id: "anthropic".to_string(),
            name: "Anthropic".to_string(),
            description: "Claude AI models".to_string(),
            category: "AI/ML".to_string(),
            docs_url: "https://console.anthropic.com/settings/keys".to_string(),
            key_pattern: r"^sk-ant-[a-zA-Z0-9-]{90,}$".to_string(),
            key_prefix: "sk-ant-".to_string(),
            recommended_key_names: vec!["ANTHROPIC_API_KEY".to_string(), "CLAUDE_API_KEY".to_string()],
            rotation_days: Some(90),
            best_practices: vec![
                "Use workspace keys for team projects".to_string(),
                "Set spend limits in the console".to_string(),
                "Use separate keys for each environment".to_string(),
                "Enable usage alerts for cost monitoring".to_string(),
            ],
        },
        ProviderInfo {
            id: "stripe".to_string(),
            name: "Stripe".to_string(),
            description: "Payment processing".to_string(),
            category: "Payments".to_string(),
            docs_url: "https://dashboard.stripe.com/apikeys".to_string(),
            key_pattern: r"^(sk_live_|sk_test_|rk_live_|rk_test_)[a-zA-Z0-9]{24,}$".to_string(),
            key_prefix: "sk_".to_string(),
            recommended_key_names: vec!["STRIPE_SECRET_KEY".to_string(), "STRIPE_PUBLISHABLE_KEY".to_string()],
            rotation_days: Some(365),
            best_practices: vec![
                "NEVER use live keys in development - always use sk_test_".to_string(),
                "Use restricted keys with minimal permissions".to_string(),
                "Enable webhook signing for security".to_string(),
                "Set up Radar rules for fraud protection".to_string(),
            ],
        },
        ProviderInfo {
            id: "github".to_string(),
            name: "GitHub".to_string(),
            description: "Code hosting and CI/CD".to_string(),
            category: "DevOps".to_string(),
            docs_url: "https://github.com/settings/tokens".to_string(),
            key_pattern: r"^(ghp_|github_pat_)[a-zA-Z0-9]{36,}$".to_string(),
            key_prefix: "ghp_".to_string(),
            recommended_key_names: vec!["GITHUB_TOKEN".to_string(), "GH_TOKEN".to_string()],
            rotation_days: Some(90),
            best_practices: vec![
                "Use fine-grained PATs instead of classic tokens".to_string(),
                "Set expiration dates on all tokens".to_string(),
                "Grant minimal required permissions".to_string(),
                "Use GitHub Apps for production integrations".to_string(),
            ],
        },
        ProviderInfo {
            id: "aws".to_string(),
            name: "AWS".to_string(),
            description: "Amazon Web Services".to_string(),
            category: "Cloud".to_string(),
            docs_url: "https://console.aws.amazon.com/iam/home#/security_credentials".to_string(),
            key_pattern: r"^AKIA[0-9A-Z]{16}$".to_string(),
            key_prefix: "AKIA".to_string(),
            recommended_key_names: vec!["AWS_ACCESS_KEY_ID".to_string(), "AWS_SECRET_ACCESS_KEY".to_string()],
            rotation_days: Some(90),
            best_practices: vec![
                "NEVER use root account credentials".to_string(),
                "Use IAM roles instead of access keys when possible".to_string(),
                "Apply least-privilege principle to IAM policies".to_string(),
                "Enable MFA for all IAM users".to_string(),
                "Use AWS Secrets Manager for production workloads".to_string(),
            ],
        },
        ProviderInfo {
            id: "google".to_string(),
            name: "Google Cloud".to_string(),
            description: "GCP, Maps, Gemini, and other Google APIs".to_string(),
            category: "Cloud".to_string(),
            docs_url: "https://console.cloud.google.com/apis/credentials".to_string(),
            key_pattern: r"^AIza[0-9A-Za-z_-]{35}$".to_string(),
            key_prefix: "AIza".to_string(),
            recommended_key_names: vec!["GOOGLE_API_KEY".to_string(), "GOOGLE_MAPS_API_KEY".to_string(), "GEMINI_API_KEY".to_string()],
            rotation_days: Some(90),
            best_practices: vec![
                "Restrict API keys by IP, referrer, or API".to_string(),
                "Use service accounts for server-side access".to_string(),
                "Enable Cloud Billing alerts".to_string(),
                "Use separate projects for dev/staging/prod".to_string(),
            ],
        },
        ProviderInfo {
            id: "azure".to_string(),
            name: "Microsoft Azure".to_string(),
            description: "Azure cloud services".to_string(),
            category: "Cloud".to_string(),
            docs_url: "https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps".to_string(),
            key_pattern: r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$".to_string(),
            key_prefix: "".to_string(),
            recommended_key_names: vec!["AZURE_CLIENT_ID".to_string(), "AZURE_CLIENT_SECRET".to_string(), "AZURE_TENANT_ID".to_string()],
            rotation_days: Some(365),
            best_practices: vec![
                "Use managed identities when running on Azure".to_string(),
                "Apply least-privilege RBAC roles".to_string(),
                "Enable Azure Key Vault for production secrets".to_string(),
                "Set up cost alerts and budgets".to_string(),
            ],
        },
        ProviderInfo {
            id: "twilio".to_string(),
            name: "Twilio".to_string(),
            description: "SMS, voice, and communication APIs".to_string(),
            category: "Communication".to_string(),
            docs_url: "https://console.twilio.com/project/api-keys".to_string(),
            key_pattern: r"^SK[a-f0-9]{32}$".to_string(),
            key_prefix: "SK".to_string(),
            recommended_key_names: vec!["TWILIO_ACCOUNT_SID".to_string(), "TWILIO_AUTH_TOKEN".to_string()],
            rotation_days: Some(180),
            best_practices: vec![
                "Use API keys instead of Auth Token for production".to_string(),
                "Set up usage triggers for cost control".to_string(),
                "Enable Verify for phone number validation".to_string(),
                "Use subaccounts for different applications".to_string(),
            ],
        },
        ProviderInfo {
            id: "sendgrid".to_string(),
            name: "SendGrid".to_string(),
            description: "Email delivery service".to_string(),
            category: "Communication".to_string(),
            docs_url: "https://app.sendgrid.com/settings/api_keys".to_string(),
            key_pattern: r"^SG\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+$".to_string(),
            key_prefix: "SG.".to_string(),
            recommended_key_names: vec!["SENDGRID_API_KEY".to_string()],
            rotation_days: Some(180),
            best_practices: vec![
                "Use restricted access API keys".to_string(),
                "Set up domain authentication (SPF, DKIM)".to_string(),
                "Enable link branding for better deliverability".to_string(),
                "Monitor bounce rates and spam reports".to_string(),
            ],
        },
        ProviderInfo {
            id: "slack".to_string(),
            name: "Slack".to_string(),
            description: "Workspace messaging and bots".to_string(),
            category: "Communication".to_string(),
            docs_url: "https://api.slack.com/apps".to_string(),
            key_pattern: r"^xox[baprs]-[0-9]+-[0-9A-Za-z]+$".to_string(),
            key_prefix: "xox".to_string(),
            recommended_key_names: vec!["SLACK_BOT_TOKEN".to_string(), "SLACK_SIGNING_SECRET".to_string()],
            rotation_days: None,
            best_practices: vec![
                "Use Bot tokens (xoxb-) instead of User tokens".to_string(),
                "Request only necessary OAuth scopes".to_string(),
                "Verify request signatures for security".to_string(),
                "Use socket mode for real-time events".to_string(),
            ],
        },
    ]
}

/// Get a provider by ID
fn get_provider(id: &str) -> Option<ProviderInfo> {
    get_provider_configs()
        .into_iter()
        .find(|p| p.id == id.to_lowercase())
}

/// Handle the provider command
pub async fn handle_provider(client: DaemonClient, cmd: ProviderCommand) -> Result<()> {
    match cmd.action {
        ProviderAction::List { json: json_output } => {
            let providers = get_provider_configs();

            if json_output {
                println!("{}", serde_json::to_string_pretty(&providers)?);
            } else {
                println!("Supported API Providers:");
                println!();

                // Group by category
                let mut by_category: std::collections::HashMap<String, Vec<&ProviderInfo>> =
                    std::collections::HashMap::new();
                for provider in &providers {
                    by_category
                        .entry(provider.category.clone())
                        .or_default()
                        .push(provider);
                }

                let categories = ["AI/ML", "Payments", "Cloud", "DevOps", "Communication"];
                for category in categories {
                    if let Some(providers) = by_category.get(category) {
                        println!("  {}", category);
                        for p in providers {
                            println!("    {:12} - {}", p.id, p.description);
                        }
                        println!();
                    }
                }

                println!("Use 'sec provider info <name>' for details.");
                println!("Use 'sec provider add <name>' to start guided setup.");
            }
            Ok(())
        }

        ProviderAction::Info { name } => {
            let provider = get_provider(&name).context(format!(
                "Unknown provider: '{}'. Use 'sec provider list' to see available providers.",
                name
            ))?;

            println!("{} - {}", provider.name, provider.description);
            println!();
            println!("Category:      {}", provider.category);
            println!("Documentation: {}", provider.docs_url);
            println!();

            println!("Recommended Key Names:");
            for key_name in &provider.recommended_key_names {
                println!("  - {}", key_name);
            }
            println!();

            println!("Key Format:");
            println!("  Prefix: {}", if provider.key_prefix.is_empty() { "(varies)" } else { &provider.key_prefix });
            println!();

            if let Some(days) = provider.rotation_days {
                println!("Recommended Rotation: Every {} days", days);
                println!();
            }

            println!("Best Practices:");
            for practice in &provider.best_practices {
                println!("  • {}", practice);
            }

            Ok(())
        }

        ProviderAction::Add { name, environment } => {
            let provider = get_provider(&name).context(format!(
                "Unknown provider: '{}'. Use 'sec provider list' to see available providers.",
                name
            ))?;

            println!();
            println!("╔══════════════════════════════════════════════════════════════╗");
            println!("║  {} Setup Wizard", provider.name);
            println!("╚══════════════════════════════════════════════════════════════╝");
            println!();

            // Step 1: Instructions
            println!("Step 1: Get Your API Key");
            println!("─────────────────────────");
            println!();
            println!("  1. Open: {}", provider.docs_url);
            println!("  2. Create a new API key (or use an existing one)");
            if !provider.key_prefix.is_empty() {
                println!("  3. Your key should start with: {}", provider.key_prefix);
            }
            println!();

            println!("Best Practices:");
            for practice in &provider.best_practices {
                println!("  • {}", practice);
            }
            println!();

            // Step 2: Enter Key
            println!("Step 2: Enter Your API Key");
            println!("──────────────────────────");
            println!();

            // Determine key name
            let default_key_name = provider
                .recommended_key_names
                .first()
                .cloned()
                .unwrap_or_else(|| format!("{}_API_KEY", provider.id.to_uppercase()));

            print!("Secret name [{}]: ", default_key_name);
            io::stdout().flush()?;
            let mut key_name = String::new();
            io::stdin().read_line(&mut key_name)?;
            let key_name = key_name.trim();
            let key_name = if key_name.is_empty() {
                default_key_name
            } else {
                key_name.to_string()
            };

            // Enter the key value (hidden input would be ideal, but using simple input for now)
            print!("API key value: ");
            io::stdout().flush()?;
            let mut key_value = String::new();
            io::stdin().read_line(&mut key_value)?;
            let key_value = key_value.trim().to_string();

            if key_value.is_empty() {
                println!();
                println!("Aborted. No key entered.");
                return Ok(());
            }

            // Validate key format
            if !provider.key_prefix.is_empty() && !key_value.starts_with(&provider.key_prefix) {
                println!();
                println!("⚠ Warning: Key doesn't start with expected prefix '{}'", provider.key_prefix);
                print!("Continue anyway? [y/N]: ");
                io::stdout().flush()?;
                let mut confirm = String::new();
                io::stdin().read_line(&mut confirm)?;
                if !confirm.trim().eq_ignore_ascii_case("y") {
                    println!("Aborted.");
                    return Ok(());
                }
            }

            // Step 3: Save
            println!();
            println!("Step 3: Saving to Vault");
            println!("───────────────────────");

            let env = environment.unwrap_or_else(|| "default".to_string());

            // Use the daemon client to save
            let _response: serde_json::Value = client
                .request(
                    "secret.set",
                    json!({
                        "name": key_name,
                        "value": key_value,
                        "environment": env,
                        "provider": provider.id,
                    }),
                )
                .await
                .context("Failed to save secret")?;

            println!();
            println!("✓ Secret '{}' saved successfully!", key_name);
            println!();
            println!("  Provider:    {}", provider.name);
            println!("  Environment: {}", env);
            if let Some(days) = provider.rotation_days {
                println!("  Rotate in:   {} days", days);
            }
            println!();
            println!("Access with:");
            println!("  sec get {}", key_name);
            println!();

            // Grant access suggestion
            println!("To grant AI assistant access:");
            println!("  sec agent grant claude-code {}", key_name);

            Ok(())
        }
    }
}

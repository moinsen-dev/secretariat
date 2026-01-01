//! Panic command - Security Kill-Switch
//!
//! Emergency revocation of ALL secrets for ALL apps, followed by vault lock.
//! This is the "panic button" for when a compromise is suspected.

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;
use std::io::{self, Write};

use crate::client::DaemonClient;

/// Arguments for the panic command
pub struct PanicCommand {
    /// Skip confirmation prompt
    pub force: bool,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct PanicResponse {
    status: String,
    permissions_revoked: i64,
    apps_affected: i64,
    vault_locked: bool,
    biometric_disabled: bool,
}

/// Handle the panic command
///
/// This command:
/// 1. Confirms with the user (unless --force is used)
/// 2. Sends vault.panic to the daemon
/// 3. Reports results
///
/// The daemon will:
/// - Revoke ALL permissions
/// - Lock the vault
/// - Clear master key from memory
/// - Disable biometric unlock
pub async fn handle_panic(client: DaemonClient, cmd: PanicCommand) -> Result<()> {
    // Show big warning unless --force is used
    if !cmd.force {
        println!();
        println!("╔══════════════════════════════════════════════════════════════════╗");
        println!("║                    ⚠️  SECURITY KILL-SWITCH ⚠️                    ║");
        println!("╠══════════════════════════════════════════════════════════════════╣");
        println!("║ This will IMMEDIATELY:                                           ║");
        println!("║   • Revoke ALL app permissions to ALL secrets                    ║");
        println!("║   • Lock the vault (clear master key from memory)                ║");
        println!("║   • Disable biometric/Touch ID unlock                            ║");
        println!("║                                                                  ║");
        println!("║ Use this when:                                                   ║");
        println!("║   • You suspect a key has been compromised                       ║");
        println!("║   • You detect suspicious activity                               ║");
        println!("║   • You need emergency lockdown                                  ║");
        println!("║                                                                  ║");
        println!("║ After panic, you will need to:                                   ║");
        println!("║   • Unlock the vault with your password                          ║");
        println!("║   • Re-grant permissions to apps that need them                  ║");
        println!("╚══════════════════════════════════════════════════════════════════╝");
        println!();

        // Require explicit confirmation
        print!("Type 'PANIC' to confirm emergency lockdown: ");
        io::stdout().flush()?;

        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        let input = input.trim();

        if input != "PANIC" {
            println!("Aborted. No changes were made.");
            return Ok(());
        }
    }

    println!();
    println!("🚨 Executing emergency lockdown...");
    println!();

    // Send panic command to daemon
    let response: PanicResponse = client
        .request("vault.panic", json!({}))
        .await
        .context("Failed to execute panic command")?;

    // Print results
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║                    🔒 EMERGENCY LOCKDOWN COMPLETE                 ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!(
        "║ Permissions revoked: {:>43} ║",
        response.permissions_revoked
    );
    println!(
        "║ Applications affected: {:>41} ║",
        response.apps_affected
    );
    println!(
        "║ Vault locked: {:>50} ║",
        if response.vault_locked { "Yes" } else { "No" }
    );
    println!(
        "║ Biometric disabled: {:>44} ║",
        if response.biometric_disabled { "Yes" } else { "No" }
    );
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║ Next steps:                                                      ║");
    println!("║   1. Investigate the suspected compromise                        ║");
    println!("║   2. Rotate any potentially leaked secrets                       ║");
    println!("║   3. Run 'sec unlock' to unlock the vault                        ║");
    println!("║   4. Re-grant permissions with 'sec grant <app> <secret>'        ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    Ok(())
}

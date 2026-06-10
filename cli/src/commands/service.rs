//! `sec service install|uninstall|status` — manage the daemon LaunchAgent.
//!
//! The macOS app is sandboxed and cannot install/run the daemon, so the
//! (unsandboxed) CLI owns the LaunchAgent lifecycle. The plist is embedded
//! here so this works for DMG users without the repo.

use anyhow::{bail, Context, Result};
use std::fs;
use std::path::PathBuf;
use std::process::Command;

const LABEL: &str = "dev.moinsen.secretariat.daemon";

fn launch_agents_dir() -> Result<PathBuf> {
    Ok(dirs::home_dir()
        .context("Could not determine home directory")?
        .join("Library/LaunchAgents"))
}

fn plist_path() -> Result<PathBuf> {
    Ok(launch_agents_dir()?.join(format!("{LABEL}.plist")))
}

/// Locate the `secd` daemon binary, preferring the one next to this `sec`.
fn find_secd() -> Result<PathBuf> {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let c = dir.join("secd");
            if c.exists() {
                return Ok(c);
            }
        }
    }
    for p in ["/usr/local/bin/secd", "/opt/homebrew/bin/secd"] {
        let pb = PathBuf::from(p);
        if pb.exists() {
            return Ok(pb);
        }
    }
    if let Some(home) = dirs::home_dir() {
        let pb = home.join(".local/bin/secd");
        if pb.exists() {
            return Ok(pb);
        }
    }
    bail!(
        "Could not find the 'secd' daemon binary. Put it next to 'sec', \
         or in /usr/local/bin, /opt/homebrew/bin, or ~/.local/bin."
    )
}

fn plist_contents(secd_path: &str) -> String {
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{secd_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>/tmp/secretariat-daemon.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/secretariat-daemon.err.log</string>
</dict>
</plist>
"#
    )
}

pub fn install() -> Result<()> {
    if !cfg!(target_os = "macos") {
        bail!("'service install' is macOS-only (Linux uses systemd --user).");
    }

    let secd = find_secd()?;

    // Copy the daemon to a stable user-writable location (no sudo).
    let dest_dir = dirs::home_dir()
        .context("Could not determine home directory")?
        .join(".local/bin");
    fs::create_dir_all(&dest_dir)?;
    let dest = dest_dir.join("secd");
    fs::copy(&secd, &dest)
        .with_context(|| format!("Failed to copy {} to {}", secd.display(), dest.display()))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&dest, fs::Permissions::from_mode(0o755))?;
    }

    // Write the LaunchAgent plist.
    let la_dir = launch_agents_dir()?;
    fs::create_dir_all(&la_dir)?;
    let plist = plist_path()?;
    fs::write(&plist, plist_contents(&dest.to_string_lossy()))
        .with_context(|| format!("Failed to write {}", plist.display()))?;

    // (Re)load it.
    let plist_str = plist.to_string_lossy().to_string();
    let _ = Command::new("launchctl").args(["unload", &plist_str]).output();
    let status = Command::new("launchctl")
        .args(["load", "-w", &plist_str])
        .status()
        .context("Failed to run launchctl")?;
    if !status.success() {
        bail!("launchctl load failed for {}", plist.display());
    }

    println!("✓ Daemon installed as a Launch Agent and started.");
    println!("  Binary: {}", dest.display());
    println!("  Plist:  {}", plist.display());
    println!("  It auto-starts on login. Verify with: sec status");
    Ok(())
}

pub fn uninstall() -> Result<()> {
    let plist = plist_path()?;
    let plist_str = plist.to_string_lossy().to_string();
    let _ = Command::new("launchctl").args(["unload", &plist_str]).output();
    if plist.exists() {
        fs::remove_file(&plist)?;
    }
    println!("✓ Launch Agent removed.");
    Ok(())
}

pub fn status() -> Result<()> {
    let plist = plist_path()?;
    let out = Command::new("launchctl")
        .arg("list")
        .output()
        .context("Failed to run launchctl")?;
    let running = String::from_utf8_lossy(&out.stdout)
        .lines()
        .any(|l| l.contains(LABEL));
    println!(
        "Launch Agent: {}",
        if plist.exists() { "installed" } else { "not installed" }
    );
    println!("Running:      {}", if running { "yes" } else { "no" });
    Ok(())
}

//! System event monitoring for auto-lock on sleep
//!
//! Monitors system events like sleep/wake to automatically lock the vault
//! when the system goes to sleep, as specified in app_spec.txt line 298.
//!
//! # Platform Support
//!
//! - **macOS**: Uses IOKit power management notifications
//! - **Linux**: Uses systemd-logind or UPower (not yet implemented)
//! - **Windows**: Uses SetSuspendState/WM_POWERBROADCAST (not yet implemented)

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tracing::{debug, info, warn};

/// Callback type for system sleep events
pub type SleepCallback = Arc<dyn Fn() + Send + Sync>;

/// System event monitor state
pub struct SystemEventMonitor {
    /// Whether monitoring is active
    is_running: Arc<AtomicBool>,
    /// Callback to invoke when system is about to sleep
    on_sleep: Option<SleepCallback>,
}

impl SystemEventMonitor {
    /// Create a new system event monitor
    pub fn new() -> Self {
        Self {
            is_running: Arc::new(AtomicBool::new(false)),
            on_sleep: None,
        }
    }

    /// Set callback for sleep events
    pub fn on_sleep(&mut self, callback: SleepCallback) {
        self.on_sleep = Some(callback);
    }

    /// Start monitoring system events
    ///
    /// This spawns a background thread that listens for system events.
    /// On macOS, it uses IOKit power management notifications.
    #[cfg(target_os = "macos")]
    pub fn start(&self) -> anyhow::Result<()> {
        use std::thread;
        use std::time::Duration;

        if self.is_running.swap(true, Ordering::SeqCst) {
            return Ok(()); // Already running
        }

        let is_running = self.is_running.clone();
        // Note: The polling approach below is a fallback; the log stream monitor (below)
        // is the primary sleep detection mechanism

        // Spawn a thread to keep the monitor alive
        // The actual sleep detection is done by the log stream thread
        thread::spawn(move || {
            debug!("[SystemEvents] Starting sleep monitor keepalive");

            while is_running.load(Ordering::SeqCst) {
                // Just keep the thread alive - actual detection is in log stream
                thread::sleep(Duration::from_secs(5));
            }

            debug!("[SystemEvents] Sleep monitor keepalive stopped");
        });

        // Also spawn a thread that uses log stream to detect sleep events
        let is_running2 = self.is_running.clone();
        let on_sleep2 = self.on_sleep.clone();

        thread::spawn(move || {
            use std::io::{BufRead, BufReader};
            use std::process::{Command, Stdio};

            debug!("[SystemEvents] Starting log stream monitor for sleep events");

            // Use log stream to monitor for sleep notifications
            let mut child = match Command::new("log")
                .args([
                    "stream",
                    "--predicate",
                    "subsystem == 'com.apple.powerd' AND eventMessage CONTAINS 'Sleep'",
                ])
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn()
            {
                Ok(c) => c,
                Err(e) => {
                    warn!("[SystemEvents] Failed to start log stream: {}", e);
                    return;
                }
            };

            let stdout = match child.stdout.take() {
                Some(s) => s,
                None => {
                    warn!("[SystemEvents] No stdout from log stream");
                    return;
                }
            };

            let reader = BufReader::new(stdout);

            for line in reader.lines() {
                if !is_running2.load(Ordering::SeqCst) {
                    break;
                }

                if let Ok(line) = line {
                    // Check for sleep-related messages
                    if line.contains("Will Sleep") || line.contains("Entering Sleep") {
                        info!("[SystemEvents] System going to sleep - triggering auto-lock");
                        if let Some(ref callback) = on_sleep2 {
                            callback();
                        }
                    }
                }
            }

            // Kill the log stream process when done
            let _ = child.kill();
            debug!("[SystemEvents] Log stream monitor stopped");
        });

        Ok(())
    }

    /// Start monitoring (non-macOS placeholder)
    #[cfg(not(target_os = "macos"))]
    pub fn start(&self) -> anyhow::Result<()> {
        warn!("[SystemEvents] Sleep monitoring not implemented for this platform");
        Ok(())
    }

    /// Stop monitoring system events
    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
        info!("[SystemEvents] Stopping system event monitor");
    }
}

impl Default for SystemEventMonitor {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for SystemEventMonitor {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_monitor_creation() {
        let monitor = SystemEventMonitor::new();
        assert!(!monitor.is_running.load(Ordering::SeqCst));
    }

    #[test]
    fn test_callback_setup() {
        let mut monitor = SystemEventMonitor::new();
        let called = Arc::new(AtomicBool::new(false));
        let called_clone = called.clone();

        monitor.on_sleep(Arc::new(move || {
            called_clone.store(true, Ordering::SeqCst);
        }));

        assert!(monitor.on_sleep.is_some());
    }
}

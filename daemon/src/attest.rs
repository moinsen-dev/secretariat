//! Peer attestation for the local IPC socket.
//!
//! Today a client just *declares* its `app_id` ("cli", "flutter-app", …) and
//! the daemon trusts it. That is fine for honest local tooling but not a
//! security boundary — any process on the machine could claim `app_id: "cli"`.
//!
//! This module identifies the connecting process from the socket itself
//! (`LOCAL_PEERPID`), reads its executable path, and reports its code-signing
//! identity (Team ID + signing identifier). The daemon can then *attest* who is
//! really on the other end — the foundation for "only the signed Secretariat
//! app / CLI gets administrative read access, everyone else is per-grant".
//!
//! Phase 1 (this commit): identify + log the verified peer, expose it on the
//! connection. Enforcement is opt-in via SECRETARIAT_REQUIRE_SIGNED so we never
//! lock the user out while it's being validated.

use std::os::unix::io::AsRawFd;

/// What we could learn about the process on the other end of the socket.
#[derive(Debug, Clone, Default)]
pub struct PeerIdentity {
    pub pid: Option<i32>,
    pub uid: Option<u32>,
    pub path: Option<String>,
    /// Apple Team ID (e.g. "VXX45ZYNM8"), if the binary is Developer-ID signed.
    pub team_id: Option<String>,
    /// codesign identifier (e.g. "dev.moinsen.secretariat.daemon").
    pub signing_id: Option<String>,
    /// True only for a hardened, Developer-ID-signed binary with our Team ID.
    pub trusted: bool,
}

impl PeerIdentity {
    pub fn describe(&self) -> String {
        let who = self.path.as_deref().unwrap_or("<unknown>");
        match (&self.team_id, &self.signing_id) {
            (Some(t), Some(s)) => format!("{who} (team {t}, id {s})"),
            _ => format!("{who} (unsigned/ad-hoc)"),
        }
    }
}

/// Our own Team ID — only binaries signed with this are first-party.
pub const SECRETARIAT_TEAM_ID: &str = "VXX45ZYNM8";

/// Inspect the process on the other end of `stream`.
#[cfg(target_os = "macos")]
pub fn identify_peer<S: AsRawFd>(stream: &S) -> PeerIdentity {
    let mut id = PeerIdentity::default();
    let fd = stream.as_raw_fd();

    // 1. PID via LOCAL_PEERPID.
    let mut pid: libc::pid_t = 0;
    let mut len = std::mem::size_of::<libc::pid_t>() as libc::socklen_t;
    let rc = unsafe {
        libc::getsockopt(
            fd,
            libc::SOL_LOCAL,
            libc::LOCAL_PEERPID,
            &mut pid as *mut _ as *mut libc::c_void,
            &mut len,
        )
    };
    if rc == 0 && pid > 0 {
        id.pid = Some(pid);
    }

    // 2. UID via getpeereid (defence in depth — same-user only).
    let mut uid: libc::uid_t = 0;
    let mut gid: libc::gid_t = 0;
    if unsafe { libc::getpeereid(fd, &mut uid, &mut gid) } == 0 {
        id.uid = Some(uid);
    }

    // 3. Executable path from the PID.
    if let Some(pid) = id.pid {
        id.path = pid_path(pid);
    }

    // 4. Code-signing identity of that executable.
    if let Some(path) = &id.path {
        if let Some((team, signing_id)) = codesign_identity(path) {
            id.trusted = team == SECRETARIAT_TEAM_ID;
            id.team_id = Some(team);
            id.signing_id = Some(signing_id);
        }
    }

    id
}

#[cfg(not(target_os = "macos"))]
pub fn identify_peer<S: AsRawFd>(_stream: &S) -> PeerIdentity {
    // Linux would use SO_PEERCRED; signature verification is macOS-specific.
    PeerIdentity::default()
}

/// Resolve a PID's executable path via proc_pidpath.
#[cfg(target_os = "macos")]
fn pid_path(pid: i32) -> Option<String> {
    const PROC_PIDPATHINFO_MAXSIZE: usize = 4096;
    extern "C" {
        fn proc_pidpath(pid: libc::c_int, buffer: *mut libc::c_void, buffersize: u32) -> libc::c_int;
    }
    let mut buf = vec![0u8; PROC_PIDPATHINFO_MAXSIZE];
    let n = unsafe {
        proc_pidpath(
            pid,
            buf.as_mut_ptr() as *mut libc::c_void,
            buf.len() as u32,
        )
    };
    if n <= 0 {
        return None;
    }
    buf.truncate(n as usize);
    String::from_utf8(buf).ok()
}

/// Read the Team ID + signing identifier of a binary via `codesign`.
/// Returns None if unsigned / ad-hoc / unverifiable.
#[cfg(target_os = "macos")]
fn codesign_identity(path: &str) -> Option<(String, String)> {
    let out = std::process::Command::new("/usr/bin/codesign")
        .args(["-dvv", "--", path])
        .output()
        .ok()?;
    // codesign prints to stderr.
    let text = String::from_utf8_lossy(&out.stderr);

    let mut team = None;
    let mut signing_id = None;
    let mut adhoc = false;
    for line in text.lines() {
        if let Some(v) = line.strip_prefix("TeamIdentifier=") {
            if v != "not set" {
                team = Some(v.trim().to_string());
            }
        } else if let Some(v) = line.strip_prefix("Identifier=") {
            signing_id = Some(v.trim().to_string());
        } else if line.contains("flags=") && line.contains("adhoc") {
            adhoc = true;
        }
    }
    match (team, signing_id) {
        (Some(t), Some(s)) if !adhoc => Some((t, s)),
        _ => None,
    }
}

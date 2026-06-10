//! Cross-device sync handlers (E2E-encrypted).
//!
//! Sync moves only ciphertext: `value_encrypted` blobs (nonce + AES-256-GCM
//! ciphertext) plus metadata and deletion tombstones. The daemon never
//! decrypts during sync, so these handlers do NOT require the vault to be
//! unlocked. Conflict resolution is last-write-wins by `updated_at`.
//!
//! - `sync.export` — dump all encrypted secrets + tombstones + salt so another
//!   device (or the CloudKit relay) can merge them. The salt is public; the
//!   password verification value is itself ciphertext, both safe to share.
//! - `sync.import` — merge incoming encrypted secrets + tombstones into the
//!   local store, skipping anything the local store already has newer.

use crate::storage::{Storage, SyncSecret, SyncTombstone};
use anyhow::Result;
use serde_json::json;

/// Export the full encrypted sync payload for this device.
pub fn handle_sync_export(storage: &Storage) -> Result<serde_json::Value> {
    let secrets = storage.export_sync_secrets()?;
    let tombstones = storage.export_tombstones()?;
    let salt = storage.get_vault_metadata("salt")?;
    let password_verification = storage.get_vault_metadata("password_verification")?;

    Ok(json!({
        "secrets": secrets,
        "tombstones": tombstones,
        "salt": salt,
        "password_verification": password_verification,
    }))
}

/// Merge an incoming encrypted sync payload into the local store.
pub fn handle_sync_import(
    storage: &Storage,
    secrets: Vec<SyncSecret>,
    tombstones: Vec<SyncTombstone>,
) -> Result<serde_json::Value> {
    let received_secrets = secrets.len();
    let received_tombstones = tombstones.len();

    let mut applied_secrets = 0u32;
    for s in &secrets {
        if storage.import_sync_secret(s)? {
            applied_secrets += 1;
        }
    }

    let mut applied_tombstones = 0u32;
    for t in &tombstones {
        if storage.import_sync_tombstone(&t.name, &t.deleted_at)? {
            applied_tombstones += 1;
        }
    }

    Ok(json!({
        "applied_secrets": applied_secrets,
        "applied_tombstones": applied_tombstones,
        "received_secrets": received_secrets,
        "received_tombstones": received_tombstones,
    }))
}

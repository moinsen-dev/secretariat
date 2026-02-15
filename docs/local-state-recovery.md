# Local State Recovery

This runbook covers local state migration or startup failures for Secretariat.

## Symptoms

- Daemon fails at startup with `file is not a database`.
- CLI cannot reach daemon because of stale socket.
- Vault appears initialized but commands fail after migration.

## Paths And Overrides

Default data paths:

- Database: `~/Library/Application Support/Secretariat/vault.db`
- Socket: `~/Library/Application Support/Secretariat/secretariat.sock`

Supported overrides:

- `SECRETARIAT_DB_PATH`
- `SECRETARIAT_SOCKET_PATH`
- `SECRETARIAT_SOCKET` (legacy alias)
- `SECRETARIAT_DATA_DIR`

## Recovery Procedure (Non-Destructive First)

1. Stop any running daemon process.
2. Restart daemon once and inspect logs.
3. If startup reports incompatible DB format, let auto-recovery run:
   - daemon moves broken DB to timestamped backup
   - daemon creates a fresh `vault.db`
4. Re-run `sec status` and `sec list` to verify health.

## Manual Rollback To Backup DB

Use this only if you need to restore an older local DB snapshot.

1. Stop daemon.
2. Locate backup file in the same directory as `vault.db` (timestamp suffix).
3. Move current DB aside and restore backup:

```bash
mv "$HOME/Library/Application Support/Secretariat/vault.db" \
   "$HOME/Library/Application Support/Secretariat/vault.db.failed.$(date +%s)"
mv "$HOME/Library/Application Support/Secretariat/vault.db.backup-<timestamp>" \
   "$HOME/Library/Application Support/Secretariat/vault.db"
```

4. Start daemon and verify:

```bash
sec status
sec list
```

## Stale Socket Recovery

If socket exists but daemon is not alive:

1. Stop daemon process.
2. Remove stale socket file.
3. Start daemon again (`sec status` also bootstraps).

## Last-Resort Reset

If vault/keychain state is irrecoverable:

1. Backup current data directory.
2. Remove `vault.db`.
3. Re-initialize with `sec init`.
4. Re-import secrets from trusted source.

## Post-Recovery Validation

Run:

```bash
./scripts/release-gate.sh
```

Only continue to release when full gate is green.

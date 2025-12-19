# Secretariat CLI Reference

The `sec` command-line interface provides complete control over your secrets vault.

## Global Flags

| Flag | Description |
|------|-------------|
| `--json` | Output in JSON format |
| `--quiet` | Suppress non-essential output |
| `--help` | Show help for any command |
| `--version` | Show version information |

## Commands

### 1. `sec init`

Initialize a new vault (first run only).

```bash
sec init
```

**Options:**
- `--stdin` - Read password from stdin

**Example:**
```bash
# Interactive setup
sec init

# Non-interactive (scripted)
echo "my-secure-password" | sec init --stdin
```

---

### 2. `sec list`

List all secrets in the vault.

```bash
sec list [OPTIONS]
```

**Options:**
- `--json` - Output as JSON array
- `--provider <PROVIDER>` - Filter by provider (openai, stripe, etc.)
- `--environment <ENV>` - Filter by environment

**Examples:**
```bash
# Human-readable list
sec list

# JSON output
sec list --json

# Filter by provider
sec list --provider openai
```

**Output:**
```
OPENAI_API_KEY        (openai)     2024-01-15
STRIPE_SECRET_KEY     (stripe)     2024-01-10
DATABASE_URL          (postgres)   2024-01-08
```

---

### 3. `sec get <KEY>`

Retrieve a secret value.

```bash
sec get <KEY>
```

**Examples:**
```bash
# Get a secret
sec get OPENAI_API_KEY

# Use in scripts
export OPENAI_API_KEY=$(sec get OPENAI_API_KEY)
```

**Note:** Only the value is printed (no newline), making it suitable for piping.

---

### 4. `sec set <KEY> <VALUE>`

Create or update a secret.

```bash
sec set <KEY> <VALUE> [OPTIONS]
```

**Options:**
- `--stdin` - Read value from stdin (recommended for sensitive values)
- `--provider <PROVIDER>` - Set provider hint
- `--environment <ENV>` - Set environment tag

**Examples:**
```bash
# Set directly (value in shell history!)
sec set OPENAI_API_KEY sk-proj-xxxxx

# Set from stdin (no shell history)
echo "sk-proj-xxxxx" | sec set OPENAI_API_KEY --stdin

# Set with provider hint
sec set STRIPE_SECRET_KEY sk_live_xxx --provider stripe

# Set with environment
sec set DATABASE_URL postgres://... --environment production
```

---

### 5. `sec delete <KEY>`

Delete a secret from the vault.

```bash
sec delete <KEY> [OPTIONS]
```

**Options:**
- `--force` - Skip confirmation prompt

**Examples:**
```bash
# Interactive deletion
sec delete OLD_API_KEY

# Force delete (scripted)
sec delete OLD_API_KEY --force
```

---

### 6. `sec rotate <KEY>`

Rotate a secret value (update with new value, log rotation).

```bash
sec rotate <KEY>
```

**Example:**
```bash
# Rotate an API key
sec rotate OPENAI_API_KEY
# Enter new value when prompted
```

---

### 7. `sec grant <APP> <KEY>`

Grant an application access to a secret.

```bash
sec grant <APP> <KEY>
```

**Examples:**
```bash
# Grant access
sec grant my-python-app OPENAI_API_KEY

# Grant multiple secrets
sec grant my-app DATABASE_URL
sec grant my-app REDIS_URL
```

---

### 8. `sec revoke <APP> <KEY>`

Revoke an application's access to a secret.

```bash
sec revoke <APP> <KEY>
```

**Example:**
```bash
sec revoke old-app OPENAI_API_KEY
```

---

### 9. `sec apps`

List registered applications and their permissions.

```bash
sec apps [OPTIONS]
```

**Options:**
- `--json` - Output as JSON

**Example:**
```bash
sec apps
```

**Output:**
```
my-python-app
  ├── OPENAI_API_KEY
  └── DATABASE_URL

my-node-app
  └── STRIPE_SECRET_KEY
```

---

### 10. `sec audit`

View the access audit log.

```bash
sec audit [OPTIONS]
```

**Options:**
- `--app <APP>` - Filter by application
- `--secret <KEY>` - Filter by secret
- `--since <DATE>` - Show entries since date
- `--limit <N>` - Limit number of entries (default: 50)
- `--json` - Output as JSON

**Examples:**
```bash
# Recent audit entries
sec audit

# Filter by app
sec audit --app my-python-app

# Filter by secret
sec audit --secret OPENAI_API_KEY

# Last 7 days
sec audit --since "7 days ago"
```

**Output:**
```
2024-01-15 14:32:05  my-app          read   OPENAI_API_KEY    ✓
2024-01-15 14:30:12  sec-cli         write  DATABASE_URL      ✓
2024-01-15 14:28:00  unknown-app     read   STRIPE_KEY        ✗ (denied)
```

---

### 11. `sec explain <APP>`

Show what secrets an application would receive.

```bash
sec explain <APP>
```

**Example:**
```bash
sec explain my-python-app
```

**Output:**
```
Application: my-python-app
Path: /usr/local/bin/python
Bundle ID: com.python.python3

Accessible secrets:
  ✓ OPENAI_API_KEY
  ✓ DATABASE_URL

Denied secrets:
  ✗ STRIPE_SECRET_KEY (not granted)
  ✗ ADMIN_PASSWORD (not granted)
```

---

### 12. `sec import <FILE>`

Import secrets from a .env file.

```bash
sec import <FILE> [OPTIONS]
```

**Options:**
- `--scan <DIR>` - Scan directory recursively for .env files
- `--dry-run` - Show what would be imported
- `--merge` - Merge with existing secrets (don't overwrite)

**Examples:**
```bash
# Import single file
sec import ~/project/.env

# Scan all projects
sec import --scan ~/projects

# Preview without importing
sec import --scan ~/projects --dry-run
```

---

### 13. `sec cleanup`

Clean up .env files after importing.

```bash
sec cleanup [OPTIONS]
```

**Options:**
- `--dry-run` - Show what would be deleted
- `--execute` - Actually delete the files

**Examples:**
```bash
# Show what would be cleaned up
sec cleanup --dry-run

# Execute cleanup
sec cleanup --execute
```

**Warning:** This permanently deletes .env files!

---

### 14. `sec status`

Show daemon status and vault health.

```bash
sec status
```

**Output:**
```
Secretariat Status
──────────────────
Daemon:     Running (PID 1234)
Vault:      Unlocked
Secrets:    42
Apps:       5
Last access: 2 minutes ago
Memory:     28 MB
Uptime:     3 days, 2 hours
```

---

### 15. `sec unlock`

Unlock the vault (requires Touch ID or password).

```bash
sec unlock
```

---

### 16. `sec lock`

Lock the vault immediately.

```bash
sec lock
```

---

### 17. `sec version`

Show version information.

```bash
sec version
```

**Output:**
```
Secretariat CLI v0.1.0
Daemon: v0.1.0 (running)
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRETARIAT_SOCKET_PATH` | Custom socket path | `/tmp/secretariat.sock` |
| `SECRETARIAT_DB_PATH` | Custom database path | `~/Library/Application Support/Secretariat/vault.db` |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Secret not found |
| 3 | Permission denied |
| 4 | Daemon not running |
| 5 | Vault locked |

## Examples

### Complete Workflow

```bash
# Initialize vault
sec init

# Import existing secrets
sec import --scan ~/projects

# Add new secret
sec set OPENAI_API_KEY sk-proj-xxxxx

# Use in your app
export OPENAI_API_KEY=$(sec get OPENAI_API_KEY)
python my_app.py

# Check what accessed your secrets
sec audit --since "today"

# Lock when done
sec lock
```

### Scripting

```bash
#!/bin/bash
# Deploy script using Secretariat

# Ensure vault is unlocked
sec unlock || exit 1

# Get deployment secrets
DEPLOY_KEY=$(sec get DEPLOY_SSH_KEY)
AWS_ACCESS_KEY=$(sec get AWS_ACCESS_KEY_ID)

# Deploy...
ssh -i <(echo "$DEPLOY_KEY") deploy@server
```

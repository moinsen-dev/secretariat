# Secretariat MCP Server

Model Context Protocol (MCP) server for Secretariat, enabling AI assistants like Claude, Cursor, and GitHub Copilot to securely access secrets from your vault.

## Overview

This MCP server acts as a bridge between AI coding assistants and the Secretariat secrets vault. It provides:

- **Secure secret access** - AI agents can only access secrets they've been granted permission to
- **Environment awareness** - Respects environment contexts (dev, staging, prod)
- **Audit trail** - All access is logged for security review
- **Permission checks** - Agents can verify access before attempting retrieval

## Prerequisites

- Node.js 18 or later
- Secretariat daemon running (`sec daemon start`)
- Agent registered and granted permissions (`sec agent register claude-code`)

## Installation

```bash
cd mcp-server
npm install
npm run build
```

## Configuration

### Claude Desktop / Claude Code

Add to your MCP configuration (`~/.claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "secretariat": {
      "command": "node",
      "args": ["/path/to/secretariat/mcp-server/dist/index.js"],
      "env": {
        "SECRETARIAT_AGENT_NAME": "claude-code"
      }
    }
  }
}
```

### Cursor

Add to Cursor's MCP settings:

```json
{
  "mcpServers": {
    "secretariat": {
      "command": "node",
      "args": ["/path/to/secretariat/mcp-server/dist/index.js"],
      "env": {
        "SECRETARIAT_AGENT_NAME": "cursor"
      }
    }
  }
}
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRETARIAT_SOCKET` | Path to daemon Unix socket | `~/Library/Application Support/Secretariat/secretariat.sock` |
| `SECRETARIAT_AGENT_NAME` | Agent identifier for permission checks | `claude-code` |

## Available Tools

### `secretariat.get`

Retrieve a secret from the vault.

**Input:**
- `name` (required): Secret name (e.g., `OPENAI_API_KEY`)
- `environment` (optional): Environment context (default, dev, staging, prod)

**Example:**
```
Get my OpenAI API key
```

### `secretariat.list`

List available secrets (names only, not values).

**Input:**
- `environment` (optional): Filter by environment
- `filter` (optional): Filter by name pattern

**Example:**
```
List all AWS-related secrets in production
```

### `secretariat.check`

Check if the agent has permission to access a secret.

**Input:**
- `secret_name` (required): Name of the secret
- `environment` (optional): Environment to check

**Example:**
```
Do I have access to DATABASE_URL?
```

### `secretariat.status`

Get vault status (locked/unlocked, secret count, environments).

## Setting Up Permissions

Before an AI agent can access secrets, you need to:

1. **Register the agent:**
   ```bash
   sec agent register claude-code
   ```

2. **Grant access to specific secrets:**
   ```bash
   sec agent grant claude-code OPENAI_API_KEY
   sec agent grant claude-code DATABASE_URL --environment production
   ```

3. **View agent permissions:**
   ```bash
   sec agent explain claude-code
   ```

## Security Model

- **Principle of least privilege** - Agents only see secrets they've been explicitly granted access to
- **Per-secret permissions** - Each secret requires individual grant
- **Environment isolation** - Permissions can be scoped to specific environments
- **Audit logging** - All access attempts are logged
- **Emergency revoke** - Use `sec agent revoke-all <agent>` to immediately revoke all access

## Development

```bash
# Watch mode
npm run dev

# Build
npm run build

# Run locally
node dist/index.js
```

## Troubleshooting

### "Daemon not running"

Start the Secretariat daemon:
```bash
sec daemon start
```

### "Agent not found"

Register the agent first:
```bash
sec agent register claude-code
```

### "Access denied"

Grant the agent permission:
```bash
sec agent grant claude-code SECRET_NAME
```

### "Vault is locked"

Unlock the vault:
```bash
sec unlock
```

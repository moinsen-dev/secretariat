# Secretariat JSON-RPC Contract (Phase 1 Freeze)

Last updated: 2026-02-15
Scope: daemon IPC surface consumed by CLI, MCP, and SDK adapters.

## Transport

- Protocol: newline-delimited JSON-RPC-like messages over Unix domain socket.
- Request shape:

```json
{"jsonrpc":"2.0","id":1,"method":"secret.list","params":{}}
```

- Response shape (success):

```json
{"id":1,"result":{...}}
```

- Response shape (error):

```json
{"id":1,"error":{"code":-32602,"message":"Missing required parameter: app_id"}}
```

## Error Codes (stable)

- `-32601`: method not found
- `-32602`: invalid params (missing/invalid required params)
- `-32603`: internal error (handler/runtime/storage failure)
- `-32001`: permission denied for `secret.get` app authorization failures
- `-32002`: vault locked for methods that require unlocked state

## Lock-State Behavior

- Methods requiring unlocked vault:
  - `secret.get`
  - `secret.set`
  - `secret.delete`
  - `secret.rotate`
- If vault is locked, these return `error.code = -32002`.
- `secret.list`, `vault.status`, and `agent.explain` are callable while locked.

## Method Contracts

### `vault.status`

Request params: `{}`

Result:

```json
{
  "state": "locked|unlocked|uninitialized",
  "secret_count": 3,
  "app_count": 2
}
```

### `secret.list`

Request params: `{}`

Result:

```json
{
  "secrets": [
    {
      "id": "uuid",
      "name": "OPENAI_API_KEY",
      "provider": "openai",
      "environment": "default",
      "created_at": "2026-02-15 18:00:00"
    }
  ]
}
```

Notes:
- The daemon contract currently returns full metadata for all secrets.
- Adapter-level filtering (environment/provider/pattern/agent visibility) is client-side.

### `secret.get`

Required params:

```json
{"name":"OPENAI_API_KEY","app_id":"cli"}
```

Result:

```json
{"name":"OPENAI_API_KEY","value":"sk-..."}
```

Notes:
- `app_id` is required. Legacy `agent` parameter is not accepted.
- Missing `app_id` returns `-32602`.
- App permission failure returns `-32001`.

### `agent.explain`

Required params:

```json
{"agent_id":"claude-code"}
```

Result:

```json
{
  "agent_id": "claude-code",
  "permissions": [
    {"secret":"OPENAI_API_KEY","environment":"default"}
  ]
}
```

## Adapter Rules (must hold)

- Never call `secret.get` without `app_id`.
- Treat `secret.list` entries as metadata objects; do not assume `string[]`.
- For MCP agent visibility, enforce allow-listing using `agent.explain` before returning or fetching values.

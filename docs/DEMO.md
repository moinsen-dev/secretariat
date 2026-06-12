# Secretariat — Demo-Runbook ("Secrets your AI can use but never see")

A ~2-minute screen recording that proves the mission: an AI builds/runs a real
project using real secrets, **never sees a value**, and afterwards there is no
plaintext anywhere — not in a file, not in the AI's transcript, not in the take.

Every command below was dry-run end-to-end and produces the output shown.

---

## Setup (off-camera — run once before recording)

Spins up an **isolated** demo (its own daemon, vault, fake secrets) so nothing
real is on screen and it's fully reproducible.

```bash
REPO=/Users/udi/work/moinsen/ideas/secretariat
cargo build --release -p sec -p secd --manifest-path $REPO/Cargo.toml

export DHOME=/tmp/secretariat-demo-home
rm -rf $DHOME && mkdir -p $DHOME
HOME=$DHOME SECRETARIAT_SOCKET=$DHOME/sec.sock SECRETARIAT_NO_KEYCHAIN=1 \
  $REPO/target/release/secd >$DHOME/d.log 2>&1 &
sleep 2

sec() { HOME=$DHOME SECRETARIAT_SOCKET=$DHOME/sec.sock SECRETARIAT_NO_KEYCHAIN=1 \
        $REPO/target/release/sec "$@"; }
sec init --password demo-master-pass-2026 >/dev/null
SECRETARIAT_INIT_PASSWORD=demo-master-pass-2026 sec unlock >/dev/null

DEMO=/tmp/weather-api
rm -rf $DEMO && mkdir -p $DEMO && cd $DEMO && git init -q .
echo "node_modules/" > .gitignore
cat > .env <<'EOF'
OPENAI_API_KEY=sk-proj-aB3xK9mP2qR7wT5nL8vY4zE1cF6hJ0sD
DATABASE_URL=postgres://admin:Tr0ub4dor99@db.prod.internal:5432/weather
EOF
cat > app.js <<'EOF'
const key = process.env.OPENAI_API_KEY;
const db  = process.env.DATABASE_URL;
if (!key || !db) { console.error("✗ missing config"); process.exit(1); }
console.log("✓ weather-api started");
console.log("  OpenAI:   authenticated");
console.log("  Database: connected (" + db.split("@")[1] + ")");
EOF
cat > .mcp.json <<EOF
{ "mcpServers": { "secretariat": {
  "command": "$REPO/target/release/sec", "args": ["mcp"],
  "env": { "SECRETARIAT_SOCKET": "$DHOME/sec.sock", "SECRETARIAT_NO_KEYCHAIN": "1" }
} } }
EOF
```

Put a `sec()` alias in the recording shell too, so on-camera you just type `sec …`:

```bash
sec() { HOME=/tmp/secretariat-demo-home \
        SECRETARIAT_SOCKET=/tmp/secretariat-demo-home/sec.sock \
        SECRETARIAT_NO_KEYCHAIN=1 \
        /Users/udi/work/moinsen/ideas/secretariat/target/release/sec "$@"; }
cd /tmp/weather-api
```

---

## Beat 1 — The problem (15s)

> "Every project has secrets in plaintext. And the moment your AI needs one,
> it ends up in the chat."

```bash
cat .env
```
```
OPENAI_API_KEY=sk-proj-aB3xK9mP2qR7wT5nL8vY4zE1cF6hJ0sD
DATABASE_URL=postgres://admin:Tr0ub4dor99@db.prod.internal:5432/weather
```

---

## Beat 2 — Eradicate (20s)

> "One command moves them into the vault and erases the file."

```bash
sec import . --scan --eradicate --yes
```
Highlights on screen: `✓ OPENAI_API_KEY`, `✓ DATABASE_URL`, `✓ eradicated …/.env`,
`✓ no plaintext leaks found`.

```bash
ls -la              # no .env
cat .secretariat.toml
```
> "What stays is a manifest with **only the names** — safe to commit."
```toml
[secrets]
DATABASE_URL = "DATABASE_URL"
OPENAI_API_KEY = "OPENAI_API_KEY"
```

---

## Beat 3 — A human uses it (15s)

```bash
sec run -- node app.js
```
```
sec run: injecting 2 secret(s): DATABASE_URL, OPENAI_API_KEY
✓ weather-api started
  OpenAI:   authenticated
  Database: connected (db.prod.internal:5432/weather)
```
> "It runs with the real keys. But you can't even print them:"
```bash
sec run -- printenv OPENAI_API_KEY
```
```
[REDACTED:OPENAI_API_KEY]
```

---

## Beat 4 — The AI uses it (the magic, 40s)

Open Claude Code **in `/tmp/weather-api`** (the `.mcp.json` wires up the
`secretariat` MCP server). Prompt:

> **"Run this project and tell me if it connects to its services. Don't ask me
> for any API keys — use the secretariat tools."**

Claude calls `run_with_secrets`, the app starts, and Claude reports:
> "✓ weather-api started — OpenAI authenticated, database connected."

Then ask the kicker:

> **"What's the OpenAI API key?"**

Claude answers that it cannot read secret values — there's no tool for it; it
can only *use* them. Scroll the transcript: **no key anywhere.**

---

## Beat 5 — The proof (20s)

```bash
grep -rIn "sk-proj"   /tmp/weather-api ; echo "exit $?"   # nothing → exit 1
grep -rIn "Tr0ub4dor" /tmp/weather-api ; echo "exit $?"   # nothing → exit 1
```
> "The key your AI just used to run a real service? It is in no file, not in
> the AI's memory, and not in this recording. **Secrets your AI can use but
> never see.** Secretariat — one-time €5."

---

## Teardown

```bash
pkill -f secretariat-demo-home ; rm -rf /tmp/secretariat-demo-home /tmp/weather-api
```

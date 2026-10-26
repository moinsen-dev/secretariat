#!/usr/bin/env python3
"""Move secrets from many .env files into Secretariat in one reviewed step. Names only, never values.

  bulk_import.py plan [ROOT]     writes .artifacts/bulk-import-plan.{json,md}: which variables become which
                                 item fields, which profiles get created, what stays in the .env and why
  bulk_import.py apply           executes the reviewed plan with the installed CLI (`import`, `profile`)

Values are read only to group identical ones (in memory) and by `secretariat import` itself. Nothing is
deleted: the .env files stay until the user removes them.
"""
import collections
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / ".artifacts"
S = str(Path.home() / "bin" / "secretariat")
SKIP_DIRS = {"node_modules", ".git", "Pods", ".dart_tool", "build", "dist", ".next", ".venv", "DerivedData", ".build",
             "archive", ".worktrees", ".expo", "vendor", ".turbo", ".cache"}
SECRET_NAME = re.compile(r"KEY|TOKEN|SECRET|PASSWORD|PASSWD|PRIVATE|CREDENTIAL|DSN|AUTH(?!OR)|COOKIE|SIGNING|SALT|WEBHOOK", re.I)
PUBLIC_NAME = re.compile(r"^(NEXT_PUBLIC_|EXPO_PUBLIC_|VITE_|PUBLIC_|REACT_APP_)|ANON_KEY|PUBLISHABLE|_PUBLIC_KEY$|SITE_KEY", re.I)
PLACEHOLDER = re.compile(r"your[-_ ]|xxx|<.*>|example|placeholder|changeme|change[-_]me|todo|replace|dummy|fake|^\*+$|\.\.\.", re.I)
# Values that are secrets whatever the variable is called (misnamed variables happen).
SECRET_VALUE = re.compile(r"^(sk-|sk_|rk_|ghp_|gho_|ghs_|github_pat_|xox[abp]-|glpat-|AIza|ya29\.|eyJ|-----BEGIN)|^[A-Za-z0-9_\-]{48,}$")
LOCAL_DEFAULTS = {"postgres", "password", "secret", "admin", "root", "dev", "test", "local", "localhost", "true", "false", "supersecret"}
PROVIDERS = [  # var prefix → account
    (r"OPENAI", "openai"), (r"ANTHROPIC|CLAUDE", "anthropic"), (r"GEMINI|GOOGLE_GENERATIVE_AI|GOOGLE_AI", "google-gemini"),
    (r"GOOGLE", "google"), (r"STRIPE", "stripe"), (r"RESEND", "resend"), (r"SUPABASE", "supabase"),
    (r"CLOUDFLARE|CF", "cloudflare"), (r"GITHUB|GH", "github"), (r"ELEVENLABS|ELEVEN_LABS", "elevenlabs"),
    (r"REPLICATE", "replicate"), (r"GROQ", "groq"), (r"MISTRAL", "mistral"), (r"DEEPSEEK", "deepseek"),
    (r"OPENROUTER", "openrouter"), (r"SENTRY", "sentry"), (r"POSTHOG", "posthog"), (r"TWILIO", "twilio"),
    (r"AWS", "aws"), (r"FIREBASE", "firebase"), (r"EXPO", "expo"), (r"REVENUECAT|RC", "revenuecat"),
    (r"LEMON_?SQUEEZY|LS", "lemonsqueezy"), (r"ASC|APP_STORE_CONNECT", "app-store-connect"), (r"APPLE", "apple-developer"),
    (r"PERPLEXITY|PPLX", "perplexity"), (r"TAVILY", "tavily"), (r"EXA", "exa"), (r"FIRECRAWL", "firecrawl"),
    (r"PARALLEL", "parallel"), (r"BRAVE", "brave"), (r"SERP_?API", "serpapi"), (r"HUGGING_?FACE|HF", "huggingface"),
    (r"COHERE", "cohere"), (r"TOGETHER", "together"), (r"FAL", "fal"), (r"HIGGSFIELD", "higgsfield"),
    (r"JEV|TYPESAFE", "typesafe"), (r"MAPBOX", "mapbox"), (r"MAPTILER", "maptiler"), (r"POSTMARK", "postmark"),
    (r"SENDGRID", "sendgrid"), (r"MAILGUN", "mailgun"), (r"SLACK", "slack"), (r"TELEGRAM", "telegram"),
    (r"DISCORD", "discord"), (r"NOTION", "notion"), (r"LINEAR", "linear"), (r"AIRTABLE", "airtable"),
    (r"XAI|GROK", "xai"), (r"VOYAGE", "voyage"), (r"PINECONE", "pinecone"), (r"QDRANT", "qdrant"), (r"UPSTASH", "upstash"),
    (r"NEON", "neon"), (r"TURSO", "turso"), (r"CLERK", "clerk"), (r"AUTH0", "auth0"), (r"HONCHO", "honcho"),
]


# Identifiers of these accounts belong to items that already exist.
ID_ITEMS = {"app-store-connect": "moinsen/app-store-connect/api-key", "cloudflare": "moinsen/cloudflare/account",
            "apple-developer": "moinsen/apple-developer"}


def parse(text):
    out = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip()
        if v and v[0] in "\"'" and v[0] in v[1:]:
            v = v[1:v.index(v[0], 1)]
        elif " #" in v:
            v = v[:v.index(" #")].strip()
        out[k] = v
    return out


def env_files(root):
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".") or d in (".config",)]
        if dirpath.count(os.sep) - str(root).count(os.sep) > 6:
            dirs[:] = []
        for f in files:
            if f == ".env" or (f.startswith(".env.") and not re.search(r"example|sample|template|dist|bak|backup|old", f)):
                yield Path(dirpath) / f


def git_root(path):
    r = subprocess.run(["git", "-C", str(path), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 else path


def slug(text):
    return re.sub(r"[^a-z0-9._-]+", "-", text.lower()).strip("-.") or "project"


def classify(name, value):
    has_credentials = re.search(r"://[^/\s:@]+:[^@\s]+@", value)
    if re.search(r"(_ID|ISSUER)$", name, re.I) and not has_credentials and not SECRET_VALUE.search(value):
        if not value or PLACEHOLDER.search(value) or value.lower() in LOCAL_DEFAULTS or re.search(r"demo|minio", value, re.I):
            return "placeholder"
        return "identifier"
    if re.search(r"_URL$", name, re.I) and not has_credentials and "WEBHOOK" not in name.upper():
        return "config"
    if not SECRET_NAME.search(name) and not has_credentials and not SECRET_VALUE.search(value):
        return "config"
    if PUBLIC_NAME.search(name):
        return "public"
    if not value or PLACEHOLDER.search(value):
        return "placeholder"
    if value.lower() in LOCAL_DEFAULTS or len(value) < 8:
        return "local"
    if re.search(r"://[^@]*@(localhost|127\.0\.0\.1|db|postgres|redis)[:/]", value):
        return "local"
    return "secret"


def account_and_field(name):
    for pattern, account in PROVIDERS:
        m = re.match(rf"^(?:{pattern})(?:_|$)", name, re.I)
        if m:
            field = name[m.end():].lower() or "value"
            return account, (field if field[0].isalpha() else "v_" + field)
    return None, name.lower()


def plan(root):
    occurrences = collections.defaultdict(list)   # (name, value digest) → [(file, profile)]
    identifiers = collections.defaultdict(list)   # (account, field, value) → [file]; identifiers are not secret
    skipped = collections.Counter()
    profiles = {}
    for f in sorted(env_files(root)):
        try:
            values = parse(f.read_text(errors="ignore"))
        except OSError:
            continue
        repo = git_root(f.parent)
        sub = f.parent.relative_to(repo) if f.parent != repo and repo in f.parent.parents else None
        name = slug(repo.name + ("-" + "-".join(sub.parts) if sub else ""))
        variant = f.name[5:] if f.name.startswith(".env.") else ""
        if variant and variant not in ("local", "development", "dev"):
            name = f"{name}-{slug(variant)}"
        name = name[:64]
        profiles.setdefault(name, {"directory": str(f.parent), "bindings": {}})
        for var, value in values.items():
            kind = classify(var, value)
            if kind == "identifier":
                account, field = account_and_field(var)
                if account:
                    identifiers[(account, field, value)].append(str(f)); continue
                kind = "config"
            if kind != "secret":
                skipped[kind] += 1
                continue
            digest = hashlib.sha256(value.encode()).hexdigest()   # grouping only; never written out
            occurrences[(var, digest)].append((str(f), name))
    # One item field per distinct value; the most-used value of a provider field gets the plain account path.
    by_target = collections.defaultdict(list)
    for (var, digest), uses in occurrences.items():
        account, field = account_and_field(var)
        by_target[(account, field)].append((len(uses), var, digest, uses))
    groups = []
    for (account, field), entries in by_target.items():
        entries.sort(key=lambda e: -e[0])
        for rank, (count, var, digest, uses) in enumerate(entries):
            first_profile = uses[0][1]
            if account and rank == 0:
                path = f"moinsen/{account}"
            elif account:
                path = f"moinsen/{account}/{first_profile}"
            elif count > 1 and len({p for _, p in uses}) > 1:
                path = f"moinsen/shared/{slug(var)}"
            else:
                path = f"projects/{first_profile}"
            groups.append({"reference": f"{path}/{field}", "variable": var, "files": [u[0] for u in uses],
                           "profiles": sorted({u[1] for u in uses}), "_digest": digest})
            for _, profile in uses:
                profiles[profile]["bindings"][var] = f"{path}/{field}"
    profiles = {k: v for k, v in profiles.items() if v["bindings"]}
    # Two groups landing on the same reference (different variables): keep them apart.
    seen = collections.Counter(g["reference"] for g in groups)
    for g in groups:
        if seen[g["reference"]] > 1:
            path, field = g["reference"].rsplit("/", 1)
            g["reference"] = f"{path}/{g['variable'].lower()}"
            for p in g["profiles"]:
                profiles[p]["bindings"][g["variable"]] = g["reference"]
    groups.sort(key=lambda g: g["reference"])
    OUT.mkdir(exist_ok=True)
    public = [{k: v for k, v in g.items() if k != "_digest"} for g in groups]
    # Identifier values are not secret: the plan may carry them, and the review list shows them.
    id_rows = []
    for (account, field, value), files in sorted(identifiers.items()):
        item = ID_ITEMS.get(account, f"moinsen/{account}")
        id_rows.append({"reference": f"{item}/{field}", "value": value, "files": files})
    counts = collections.Counter(r["reference"] for r in id_rows)
    for r in id_rows:
        if counts[r["reference"]] > 1:
            r["conflict"] = True
    (OUT / "bulk-import-plan.json").write_text(json.dumps({"root": str(root), "groups": public, "identifiers": id_rows, "profiles": profiles,
                                                            "skipped": dict(skipped)}, indent=2, ensure_ascii=False))
    home = str(Path.home())
    lines = [f"# Bulk import review list ({len(groups)} values → items, {len(profiles)} profiles)", "",
             f"Source: {root}. No values in this list. Identical values in several files are merged into one field.", "",
             f"Stays in the .env files: {skipped.get('config', 0)} config values, {skipped.get('public', 0)} public "
             f"client keys, {skipped.get('placeholder', 0)} placeholders, {skipped.get('local', 0)} local defaults.", "",
             "## Items", "", "| Field | Variable | Files | Profiles |", "|---|---|---|---|"]
    for g in groups:
        files = "<br>".join(f.replace(home, "~") for f in g["files"][:4]) + (f"<br>… +{len(g['files']) - 4}" if len(g["files"]) > 4 else "")
        lines.append(f"| `{g['reference']}` | {g['variable']} | {files} | {', '.join(g['profiles'][:4])}{' …' if len(g['profiles']) > 4 else ''} |")
    lines += ["", "## Identifiers (not secret, set as identifier fields)", "", "| Field | Value | Files |", "|---|---|---|"]
    for r in id_rows:
        lines.append(f"| `{r['reference']}` | {r['value']}{' ⚠ several values – skipped' if r.get('conflict') else ''} | {len(r['files'])} |")
    lines += ["", "## Profiles", "", "| Profile | Folder | Variables |", "|---|---|---|"]
    for name, p in sorted(profiles.items()):
        lines.append(f"| {name} | {p['directory'].replace(home, '~')} | {', '.join(sorted(p['bindings']))} |")
    (OUT / "bulk-import-plan.md").write_text("\n".join(lines) + "\n")
    accounts = collections.Counter(g["reference"].split("/")[1] if g["reference"].startswith("moinsen/") else g["reference"].split("/")[0] for g in groups)
    print(json.dumps({"groups": len(groups), "identifiers": len(id_rows), "profiles": len(profiles), "skipped": dict(skipped),
                      "by_account": dict(accounts.most_common(25))}, ensure_ascii=False))


def run(*args):
    r = subprocess.run([S, *args, "--json"], capture_output=True, text=True)
    try:
        return r.returncode, json.loads(r.stdout)
    except ValueError:
        return r.returncode, {"error": {"code": "no_json", "message": r.stderr[:200]}}


def apply():
    data = json.loads((OUT / "bulk-import-plan.json").read_text())
    report = collections.Counter()
    problems = []
    for g in data["groups"]:
        code, out = run("import", g["files"][0], f"{g['variable']}={g['reference']}")
        if code == 0:
            report["imported"] += 1
        elif out.get("error", {}).get("code") == "field_exists":
            report["already"] += 1
        else:
            problems.append(f"{g['reference']}: {out.get('error', {}).get('code')}")
    for r in data.get("identifiers", []):
        if r.get("conflict"):
            continue
        path, field = r["reference"].rsplit("/", 1)
        if run("item", "show", path)[0] != 0:
            run("item", "create", path, "--kind", "account", "--source", "bulk import from .env")
        code, out = run("item", "set", path, "--set", f"{field}={r['value']}")
        report["identifiers" if code == 0 else "identifier_failed"] += 1
        if code:
            problems.append(f"{r['reference']}: {out.get('error', {}).get('code')}")
    existing = {p["name"] for p in run("profiles")[1].get("profiles", [])}
    for name, p in data["profiles"].items():
        if name not in existing:
            code, out = run("profile", "create", name, "--dir", p["directory"])
            if code:
                problems.append(f"profile {name}: {out.get('error', {}).get('code')}"); continue
            report["profiles"] += 1
        for var, ref in p["bindings"].items():
            code, out = run("profile", "bind", name, var, ref)
            report["bindings" if code == 0 else "binding_failed"] += 1
            if code:
                problems.append(f"{name} {var}: {out.get('error', {}).get('code')}")
    print(json.dumps({"result": dict(report), "problems": problems[:40]}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    if sys.argv[1:2] == ["plan"]:
        plan(Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else Path.home() / "work")
    elif sys.argv[1:2] == ["apply"]:
        apply()
    else:
        print(__doc__)

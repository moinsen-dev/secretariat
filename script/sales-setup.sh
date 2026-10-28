#!/bin/bash
# sales-setup.sh — wires Secretariat's license sale end to end, once (and again for test → live).
#
# Prereq (the only click): a product "Secretariat" in the Lemon Squeezy dashboard — the API can't
# create products. Keys come from Secretariat itself:
#   secretariat run secretariat-sales -- script/sales-setup.sh            (live)
#   TEST_MODE=1 secretariat run secretariat-sales -- script/sales-setup.sh (test orders)
# The profile maps LEMONSQUEEZY_API_KEY, RESEND_API_KEY, CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID.
#
# What it does — no secret is printed or left in a file:
#   - new Ed25519 keypair: private half → Worker secret + Secretariat (moinsen/secretariat-license),
#     public half → Sources/SecretariatCore/License.swift
#   - product id → worker config; live only: buy link → site/_redirects (/buy)
#   - deploys the license-issuer Worker, sets its secrets, creates/updates the order_created webhook
# Re-running makes a NEW keypair: earlier licenses stop verifying (fine for test → live, never after
# the first real sale).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
WORKER="$ROOT/worker/license-issuer"
API="https://api.lemonsqueezy.com/v1"
WRANGLER="npx --yes wrangler@4"
: "${LEMONSQUEEZY_API_KEY:?run through: secretariat run secretariat-sales -- script/sales-setup.sh}"
: "${RESEND_API_KEY:?RESEND_API_KEY missing in the profile}"
SECRETARIAT="${SECRETARIAT:-$HOME/bin/secretariat}"
PRIVATE="$(mktemp -d)"; chmod 700 "$PRIVATE"
trap 'rm -rf "$PRIVATE"' EXIT

ls_get() { curl -sf "$API/$1" -H "Accept: application/vnd.api+json" -H "Authorization: Bearer $LEMONSQUEEZY_API_KEY"; }

echo "Looking up store and product…"
STORE_ID="$(ls_get stores | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; print(d[0]["id"] if len(d)==1 else next(s["id"] for s in d if "moinsen" in s["attributes"]["slug"]))')"
read -r PRODUCT_ID BUY_URL PRODUCT_TEST < <(ls_get "products?filter%5Bstore_id%5D=$STORE_ID" | python3 -c '
import json,sys
p=[x for x in json.load(sys.stdin)["data"] if x["attributes"]["name"].strip().lower()=="secretariat"]
if not p: sys.exit("No product \"Secretariat\" in the store: create it in the dashboard first")
a=p[0]["attributes"]
print(p[0]["id"], a["buy_now_url"], "true" if a.get("test_mode") else "false")')
echo "  store $STORE_ID · product $PRODUCT_ID · test mode: $PRODUCT_TEST"
if [ "$PRODUCT_TEST" = "true" ] && [ "${TEST_MODE:-}" != "1" ]; then
    echo "The API key belongs to test mode. For live: switch test mode off, \"Copy to live mode\", put the"
    echo "live key into moinsen/lemonsqueezy. For a test run: TEST_MODE=1 in front."
    exit 1
fi

echo "Generating the keypair…"
cd "$WORKER"
[ -d node_modules ] || npm install --silent
KEYS="$(npm run --silent keygen)"
PUB="$(printf '%s\n' "$KEYS" | sed -n 's/^PUBLIC_KEY_BASE64: *//p')"
printf 'LICENSE_PRIVATE_KEY_BASE64=%s\n' "$(printf '%s\n' "$KEYS" | sed -n 's/^PRIVATE_KEY_BASE64: *//p')" > "$PRIVATE/key.env"
unset KEYS
[ ${#PUB} -eq 44 ] || { echo "Unexpected public key"; exit 1; }
"$SECRETARIAT" import "$PRIVATE/key.env" LICENSE_PRIVATE_KEY_BASE64=moinsen/secretariat-license/private_key --replace >/dev/null

echo "Writing configuration…"
sed -i '' "s|^PRODUCT_ID = \".*\"|PRODUCT_ID = \"$PRODUCT_ID\"|" "$WORKER/wrangler.toml"
ALLOW_TEST="false"; [ "${TEST_MODE:-}" = "1" ] && ALLOW_TEST="true"
sed -i '' "s|^ALLOW_TEST_MODE = \".*\"|ALLOW_TEST_MODE = \"$ALLOW_TEST\"|" "$WORKER/wrangler.toml"
sed -i '' "s|public static let productionPublicKeyBase64 = \".*\"|public static let productionPublicKeyBase64 = \"$PUB\"|" \
    "$ROOT/Sources/SecretariatCore/License.swift"
# /buy only ever points at a LIVE checkout; in test mode the site keeps /buy → #buy.
[ "$PRODUCT_TEST" = "false" ] && sed -i '' "s|^/buy .* 302$|/buy $BUY_URL 302|" "$ROOT/site/_redirects"

echo "Deploying the Worker…"
DEPLOY="$($WRANGLER deploy 2>&1)" || { echo "$DEPLOY"; exit 1; }
WORKER_URL="$(printf '%s\n' "$DEPLOY" | grep -oE 'https://[a-z0-9.-]+\.workers\.dev' | head -1)"
[ -n "$WORKER_URL" ] || { echo "Worker URL not found"; echo "$DEPLOY"; exit 1; }
echo "  $WORKER_URL"

echo "Setting secrets…"
sed -n 's/^LICENSE_PRIVATE_KEY_BASE64=//p' "$PRIVATE/key.env" | tr -d '\n' | $WRANGLER secret put LICENSE_PRIVATE_KEY_BASE64 >/dev/null
rm -f "$PRIVATE/key.env"
HOOK_SECRET="$(openssl rand -hex 20)"   # Lemon Squeezy allows at most 40 characters
printf '%s' "$HOOK_SECRET" | $WRANGLER secret put LEMONSQUEEZY_WEBHOOK_SECRET >/dev/null
printf '%s' "$RESEND_API_KEY" | $WRANGLER secret put RESEND_API_KEY >/dev/null

echo "Creating the webhook…"
python3 - "$STORE_ID" "$WORKER_URL/webhook" "$HOOK_SECRET" "$ALLOW_TEST" > "$PRIVATE/webhook.json" <<'PY'
import json, sys
store, url, secret, test = sys.argv[1:5]
print(json.dumps({"data": {"type": "webhooks",
    "attributes": {"url": url, "events": ["order_created"], "secret": secret, "test_mode": test == "true"},
    "relationships": {"store": {"data": {"type": "stores", "id": store}}}}}))
PY
unset HOOK_SECRET
# One webhook per worker URL: update an existing one (a re-run must not stack duplicates whose old
# secrets then fail with 401), remove extra copies.
EXISTING="$(ls_get "webhooks?filter%5Bstore_id%5D=$STORE_ID" | python3 -c '
import json,sys
url=sys.argv[1]
print(" ".join(w["id"] for w in json.load(sys.stdin)["data"] if w["attributes"]["url"]==url))' "$WORKER_URL/webhook")"
HOOK_ID="${EXISTING%% *}"
for extra in ${EXISTING#"$HOOK_ID"}; do
    curl -s -o /dev/null -X DELETE "$API/webhooks/$extra" -H "Accept: application/vnd.api+json" -H "Authorization: Bearer $LEMONSQUEEZY_API_KEY"
done
if [ -n "$HOOK_ID" ]; then
    python3 - "$HOOK_ID" < "$PRIVATE/webhook.json" > "$PRIVATE/patch.json" <<'PY'
import json, sys
d = json.load(sys.stdin)
d["data"]["id"] = sys.argv[1]
d["data"].pop("relationships", None)
d["data"]["attributes"].pop("test_mode", None)
print(json.dumps(d))
PY
    mv "$PRIVATE/patch.json" "$PRIVATE/webhook.json"
    METHOD=PATCH; HOOK_URL="$API/webhooks/$HOOK_ID"; WANT=200
else
    METHOD=POST; HOOK_URL="$API/webhooks"; WANT=201
fi
HOOK_STATUS="$(curl -s -o "$PRIVATE/answer.json" -w '%{http_code}' -X "$METHOD" "$HOOK_URL" \
    -H "Accept: application/vnd.api+json" -H "Content-Type: application/vnd.api+json" \
    -H "Authorization: Bearer $LEMONSQUEEZY_API_KEY" --data @"$PRIVATE/webhook.json")"
if [ "$HOOK_STATUS" != "$WANT" ]; then
    # The answer holds no secret (Lemon Squeezy never echoes it).
    echo "Webhook not created (HTTP $HOOK_STATUS):"; cat "$PRIVATE/answer.json"; echo; exit 1
fi
$WRANGLER deploy >/dev/null   # PRODUCT_ID is a [vars] entry: redeploy so it is live

echo "Done: product $PRODUCT_ID · Worker $WORKER_URL · test orders: $ALLOW_TEST"
echo "Public key is in License.swift: rebuild and release the app next."

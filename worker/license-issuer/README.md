# Secretariat license issuer

Cloudflare Worker. Receives Lemon Squeezy `order_created` webhooks, signs an Ed25519 license and
mails the JSON block `{email, issuedAt, signature}` to the buyer via Resend.

Signed bytes (byte-identical to `License.signedPayload` in `Sources/SecretariatCore/License.swift`):

```
email.lowercased() + "\n" + ISO8601(issuedAt)   // internet date-time, e.g. 2026-10-28T08:30:15Z
```

App and CLI verify offline against the public half. Secretariat has its **own** keypair; the private
half lives in the Worker secret and in Secretariat (`moinsen/secretariat-license/private_key`).

Only a paid order of `PRODUCT_ID` gets a license (`orderRefusal`, unit-tested): the store also sells
Klabauter and DebugDeck, and webhooks are per store.

Setup, test → live and redeploys: `script/sales-setup.sh` (one run, no secret is printed).
Tests: `npm test`.

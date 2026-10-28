/**
 * Secretariat license issuer.
 *
 * Flow:
 *   1. Lemonsqueezy posts an `order_created` webhook to /webhook.
 *   2. We verify the HMAC signature against LEMONSQUEEZY_WEBHOOK_SECRET.
 *   3. We extract the buyer email + order created_at timestamp.
 *   4. We sign an Ed25519 license over
 *      `email.lowercased() + "\n" + ISO8601(issuedAt, internet date-time)`
 *      — byte-identical to `License.signedPayload` in
 *      Sources/SecretariatCore/License.swift.
 *   5. We email the JSON license blob to the buyer via Resend.
 *
 * Health-check endpoint: GET / → 200 OK ("alive").
 */

export interface Env {
	LEMONSQUEEZY_WEBHOOK_SECRET: string;
	LICENSE_PRIVATE_KEY_BASE64: string;
	RESEND_API_KEY: string;
	FROM_EMAIL: string;
	PRODUCT_NAME: string;
	DOWNLOAD_URL: string;
	/** Lemon Squeezy product id of Secretariat — the store also sells other products. */
	PRODUCT_ID: string;
	/** "true" only while testing the flow with Lemon Squeezy test orders. */
	ALLOW_TEST_MODE?: string;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === "GET" && url.pathname === "/") {
			return new Response("alive", { status: 200 });
		}

		if (request.method === "POST" && url.pathname === "/webhook") {
			return handleWebhook(request, env);
		}

		return new Response("not found", { status: 404 });
	},
};

async function handleWebhook(request: Request, env: Env): Promise<Response> {
	const rawBody = await request.text();
	const signature = request.headers.get("X-Signature") ?? "";

	if (!(await verifyHmac(rawBody, signature, env.LEMONSQUEEZY_WEBHOOK_SECRET))) {
		return new Response("invalid signature", { status: 401 });
	}

	let payload: LemonsqueezyWebhook;
	try {
		payload = JSON.parse(rawBody);
	} catch {
		return new Response("invalid json", { status: 400 });
	}

	const eventName = payload?.meta?.event_name;
	if (eventName !== "order_created") {
		return new Response(`ignored event: ${eventName}`, { status: 200 });
	}

	// The webhook fires for every order in the store: only a paid Secretariat order
	// gets a Secretariat license.
	const refusal = orderRefusal(payload, env);
	if (refusal) {
		return new Response(`ignored: ${refusal}`, { status: refusal === "PRODUCT_ID not configured" ? 503 : 200 });
	}

	const email = payload?.data?.attributes?.user_email?.toLowerCase();
	const createdAt = payload?.data?.attributes?.created_at;
	if (!email || !createdAt) {
		return new Response("missing fields", { status: 422 });
	}

	const license = await signLicense(email, new Date(createdAt), env.LICENSE_PRIVATE_KEY_BASE64);
	const licenseBlock = JSON.stringify(license, null, 2);

	const emailResult = await sendLicenseEmail({
		to: email,
		from: env.FROM_EMAIL,
		productName: env.PRODUCT_NAME,
		downloadUrl: env.DOWNLOAD_URL,
		licenseBlock,
		apiKey: env.RESEND_API_KEY,
	});

	if (!emailResult.ok) {
		return new Response(`email failed: ${emailResult.error}`, { status: 502 });
	}

	return new Response("ok", { status: 200 });
}

// ---------------------------------------------------------------------------
// HMAC verification
// ---------------------------------------------------------------------------

async function verifyHmac(body: string, signatureHex: string, secret: string): Promise<boolean> {
	if (!signatureHex || !secret) return false;
	const key = await crypto.subtle.importKey(
		"raw",
		new TextEncoder().encode(secret),
		{ name: "HMAC", hash: "SHA-256" },
		false,
		["sign"],
	);
	const computed = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
	const computedHex = bufferToHex(computed);
	return constantTimeEquals(computedHex, signatureHex.toLowerCase());
}

function constantTimeEquals(a: string, b: string): boolean {
	if (a.length !== b.length) return false;
	let result = 0;
	for (let i = 0; i < a.length; i++) {
		result |= a.charCodeAt(i) ^ b.charCodeAt(i);
	}
	return result === 0;
}

// ---------------------------------------------------------------------------
// Ed25519 signing — matches the Swift verify path in LicenseService
// ---------------------------------------------------------------------------

export interface License {
	email: string;
	issuedAt: string;
	signature: string;
}

export async function signLicense(rawEmail: string, issuedAt: Date, privateKeyBase64: string): Promise<License> {
	// The app verifies over `email.lowercased()` — normalise here too, so the
	// signed bytes match no matter who calls this.
	const email = rawEmail.toLowerCase();
	const issuedAtIso = issuedAtToIso(issuedAt);
	const payload = `${email}\n${issuedAtIso}`;
	const privateKeyBytes = base64ToBytes(privateKeyBase64);
	if (privateKeyBytes.length !== 32) {
		throw new Error(`expected 32-byte Ed25519 private key, got ${privateKeyBytes.length}`);
	}

	// Convert raw 32-byte Ed25519 seed into a CryptoKey for signing.
	const pkcs8 = ed25519SeedToPkcs8(privateKeyBytes);
	const key = await crypto.subtle.importKey(
		"pkcs8",
		pkcs8,
		{ name: "Ed25519" },
		false,
		["sign"],
	);
	const sigBuffer = await crypto.subtle.sign("Ed25519", key, new TextEncoder().encode(payload));
	const signature = bytesToBase64(new Uint8Array(sigBuffer));

	return { email, issuedAt: issuedAtIso, signature };
}

/// Wraps a raw 32-byte Ed25519 seed in the PKCS#8 envelope that WebCrypto wants.
function ed25519SeedToPkcs8(seed: Uint8Array): ArrayBuffer {
	// Header for PKCS#8-encoded Ed25519 private key: see RFC 8410.
	const prefix = Uint8Array.from([
		0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
		0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
	]);
	const out = new Uint8Array(prefix.length + seed.length);
	out.set(prefix, 0);
	out.set(seed, prefix.length);
	return out.buffer;
}

function issuedAtToIso(date: Date): string {
	// Match Foundation's ISO8601DateFormatter with .withInternetDateTime:
	// "yyyy-MM-dd'T'HH:mm:ssZ" (no fractional seconds).
	const pad = (n: number) => n.toString().padStart(2, "0");
	return (
		`${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}` +
		`T${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(date.getUTCSeconds())}Z`
	);
}

// ---------------------------------------------------------------------------
// Email delivery (Resend)
// ---------------------------------------------------------------------------

interface SendArgs {
	to: string;
	from: string;
	productName: string;
	downloadUrl: string;
	licenseBlock: string;
	apiKey: string;
}

async function sendLicenseEmail(args: SendArgs): Promise<{ ok: boolean; error?: string }> {
	const pre = `<pre style="background:#f4f4f4;padding:12px;border-radius:6px;font-family:Menlo,Consolas,monospace;font-size:12px">${escapeHtml(args.licenseBlock)}</pre>`;
	const html = `
		<p>Thank you for buying ${args.productName}!</p>
		<p>Your license:</p>
		${pre}
		<p>Activate it once, on any of your Macs; it syncs through your iCloud Keychain to the others:</p>
		<ul>
			<li>App: ${args.productName} → License … → paste the block → Activate</li>
			<li>Terminal: copy the block, then <code>pbpaste | secretariat license activate</code></li>
		</ul>
		<p>Download (if you don't have it yet): <a href="${args.downloadUrl}">${args.downloadUrl}</a></p>
		<p>Keep this email. ${args.productName} verifies the license offline; there is no account and no server.</p>
	`;
	const text =
		`Thank you for buying ${args.productName}!\n\n` +
		`Your license:\n\n${args.licenseBlock}\n\n` +
		`Activate it once, on any of your Macs; it syncs through your iCloud Keychain to the others:\n` +
		`  App: ${args.productName} → License … → paste the block → Activate\n` +
		`  Terminal: copy the block, then: pbpaste | secretariat license activate\n\n` +
		`Download: ${args.downloadUrl}\n\n` +
		`Keep this email. ${args.productName} verifies the license offline; there is no account and no server.`;

	const res = await fetch("https://api.resend.com/emails", {
		method: "POST",
		headers: {
			"Authorization": `Bearer ${args.apiKey}`,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({
			from: args.from,
			to: [args.to],
			subject: `Your ${args.productName} license`,
			html,
			text,
		}),
	});

	if (!res.ok) {
		return { ok: false, error: `${res.status} ${await res.text()}` };
	}
	return { ok: true };
}

function escapeHtml(s: string): string {
	return s
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&#039;");
}

// ---------------------------------------------------------------------------
// Encoding helpers
// ---------------------------------------------------------------------------

export function base64ToBytes(b64: string): Uint8Array {
	const bin = atob(b64);
	const bytes = new Uint8Array(bin.length);
	for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
	return bytes;
}

export function bytesToBase64(bytes: Uint8Array): string {
	let bin = "";
	for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
	return btoa(bin);
}

function bufferToHex(buf: ArrayBuffer): string {
	const bytes = new Uint8Array(buf);
	let hex = "";
	for (let i = 0; i < bytes.length; i++) hex += bytes[i].toString(16).padStart(2, "0");
	return hex;
}

// ---------------------------------------------------------------------------
// Webhook payload type (subset we touch)
// ---------------------------------------------------------------------------

export interface LemonsqueezyWebhook {
	meta?: {
		event_name?: string;
		test_mode?: boolean;
	};
	data?: {
		attributes?: {
			user_email?: string;
			created_at?: string;
			status?: string;
			first_order_item?: { product_id?: number | string };
		};
	};
}

/** Why this order gets NO license — or null when it qualifies. Pure, unit-tested. */
export function orderRefusal(
	payload: LemonsqueezyWebhook,
	env: Pick<Env, "PRODUCT_ID" | "ALLOW_TEST_MODE">,
): string | null {
	if (!env.PRODUCT_ID) return "PRODUCT_ID not configured";
	const attrs = payload?.data?.attributes;
	if (String(attrs?.first_order_item?.product_id ?? "") !== String(env.PRODUCT_ID)) return "other product";
	if (attrs?.status !== "paid") return `status ${attrs?.status ?? "missing"}`;
	if (payload?.meta?.test_mode && env.ALLOW_TEST_MODE !== "true") return "test order";
	return null;
}

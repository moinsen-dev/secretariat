/**
 * Generate an Ed25519 keypair compatible with the Swift LicenseService.
 *
 * Run with: `npm run keygen`
 *
 * Output:
 *   - PRIVATE_KEY_BASE64: store as a Worker secret (`wrangler secret put LICENSE_PRIVATE_KEY_BASE64`)
 *   - PUBLIC_KEY_BASE64: paste into Sources/SecretariatCore/License.swift -> productionPublicKeyBase64
 */

import { generateKeyPair, KeyObject } from "node:crypto";
import { promisify } from "node:util";

const generate = promisify(generateKeyPair);

async function main() {
	const { publicKey, privateKey } = await generate("ed25519");

	const privateRaw = extractRawSeed(privateKey);
	const publicRaw = extractRawPublic(publicKey);

	console.log("PRIVATE_KEY_BASE64:", Buffer.from(privateRaw).toString("base64"));
	console.log("PUBLIC_KEY_BASE64: ", Buffer.from(publicRaw).toString("base64"));
}

/// Node exports Ed25519 private keys as PKCS#8 DER. The 32-byte seed sits in
/// the last 32 bytes of the DER blob; the first 16 bytes are the standard
/// PKCS#8 + algorithm-id header for Ed25519.
function extractRawSeed(key: KeyObject): Uint8Array {
	const der = key.export({ type: "pkcs8", format: "der" });
	const bytes = new Uint8Array(der);
	if (bytes.length < 32) throw new Error("unexpected pkcs8 length");
	return bytes.slice(bytes.length - 32);
}

/// Node exports Ed25519 public keys as SPKI DER; the 32-byte public key sits
/// in the last 32 bytes after a fixed 12-byte header.
function extractRawPublic(key: KeyObject): Uint8Array {
	const der = key.export({ type: "spki", format: "der" });
	const bytes = new Uint8Array(der);
	if (bytes.length < 32) throw new Error("unexpected spki length");
	return bytes.slice(bytes.length - 32);
}

main().catch((error) => {
	console.error(error);
	process.exit(1);
});

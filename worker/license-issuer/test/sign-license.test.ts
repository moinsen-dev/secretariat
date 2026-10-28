import { describe, it, expect } from "vitest";
import { generateKeyPair, KeyObject, createPublicKey, verify } from "node:crypto";
import { promisify } from "node:util";
import { signLicense, base64ToBytes, bytesToBase64 } from "../src/index";

const generate = promisify(generateKeyPair);

function rawSeed(key: KeyObject): Uint8Array {
	const der = key.export({ type: "pkcs8", format: "der" });
	const bytes = new Uint8Array(der);
	return bytes.slice(bytes.length - 32);
}

function rawPublic(key: KeyObject): Uint8Array {
	const der = key.export({ type: "spki", format: "der" });
	const bytes = new Uint8Array(der);
	return bytes.slice(bytes.length - 32);
}

describe("signLicense", () => {
	it("produces a signature that verifies against the matching public key", async () => {
		const { publicKey, privateKey } = await generate("ed25519");
		const seed = rawSeed(privateKey);
		const pub = rawPublic(publicKey);

		const issuedAt = new Date(Date.UTC(2026, 3, 30, 12, 0, 0));
		const license = await signLicense("buyer@example.com", issuedAt, bytesToBase64(seed));

		expect(license.email).toBe("buyer@example.com");
		expect(license.issuedAt).toBe("2026-04-30T12:00:00Z");
		expect(license.signature.length).toBeGreaterThan(0);

		// Reconstruct the public key from raw bytes and verify with Node.
		const spkiPrefix = Buffer.from([
			0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65,
			0x70, 0x03, 0x21, 0x00,
		]);
		const spki = Buffer.concat([spkiPrefix, Buffer.from(pub)]);
		const verifyKey = createPublicKey({ key: spki, format: "der", type: "spki" });
		const payload = Buffer.from(`${license.email}\n${license.issuedAt}`);
		const ok = verify(null, payload, verifyKey, Buffer.from(base64ToBytes(license.signature)));
		expect(ok).toBe(true);
	});

	it("signs over the lowercased email, like the app verifies", async () => {
		const { privateKey } = await generate("ed25519");
		const seed = bytesToBase64(rawSeed(privateKey));
		const issuedAt = new Date(Date.UTC(2026, 9, 26, 8, 30, 15, 123));
		const mixed = await signLicense("Buyer@Example.COM", issuedAt, seed);
		const lower = await signLicense("buyer@example.com", issuedAt, seed);
		expect(mixed.email).toBe("buyer@example.com");
		// Internet date-time: whole seconds, no fraction, trailing Z.
		expect(mixed.issuedAt).toBe("2026-10-26T08:30:15Z");
		// Ed25519 is deterministic: same bytes in, same signature out.
		expect(mixed.signature).toBe(lower.signature);
	});

	it("rejects keys of the wrong length", async () => {
		await expect(signLicense("x@y.z", new Date(), bytesToBase64(new Uint8Array(16)))).rejects.toThrow();
	});
});

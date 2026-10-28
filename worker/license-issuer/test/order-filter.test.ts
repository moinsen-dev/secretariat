import { describe, it, expect } from "vitest";
import { orderRefusal, type LemonsqueezyWebhook } from "../src/index";

const order = (o: { product?: number | string; status?: string; test?: boolean } = {}): LemonsqueezyWebhook => ({
	meta: { event_name: "order_created", test_mode: o.test ?? false },
	data: { attributes: { user_email: "a@b.de", created_at: "2026-10-26T10:00:00Z",
		status: o.status ?? "paid", first_order_item: { product_id: o.product ?? 4242 } } },
});
const env = { PRODUCT_ID: "4242", ALLOW_TEST_MODE: "false" };

describe("orderRefusal", () => {
	it("issues only for a paid Secretariat order", () => {
		expect(orderRefusal(order(), env)).toBeNull();
		expect(orderRefusal(order({ product: "4242" }), env)).toBeNull();
	});
	it("refuses other products of the store (e.g. Klabauter)", () => {
		expect(orderRefusal(order({ product: 1111 }), env)).toBe("other product");
	});
	it("refuses unpaid, refunded or pending orders", () => {
		expect(orderRefusal(order({ status: "pending" }), env)).toBe("status pending");
		expect(orderRefusal(order({ status: "refunded" }), env)).toBe("status refunded");
	});
	it("refuses test orders unless explicitly allowed", () => {
		expect(orderRefusal(order({ test: true }), env)).toBe("test order");
		expect(orderRefusal(order({ test: true }), { ...env, ALLOW_TEST_MODE: "true" })).toBeNull();
	});
	it("issues nothing before the product id is configured", () => {
		expect(orderRefusal(order(), { PRODUCT_ID: "" })).toBe("PRODUCT_ID not configured");
	});
});

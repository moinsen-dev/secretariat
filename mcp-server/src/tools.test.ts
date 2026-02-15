import { describe, expect, it } from "vitest";

import { getSecret, getVaultStatus, listSecrets } from "./tools.js";
import type { DaemonClient } from "./daemon-client.js";

type MockResponse =
  | unknown
  | ((params: Record<string, unknown>) => unknown)
  | Error;

class MockDaemonClient {
  public calls: Array<{ method: string; params: Record<string, unknown> }> = [];

  constructor(private readonly responses: Record<string, MockResponse>) {}

  async request<T>(
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<T> {
    this.calls.push({ method, params });

    const response = this.responses[method];
    if (response === undefined) {
      throw new Error(`Unexpected method call: ${method}`);
    }

    if (response instanceof Error) {
      throw response;
    }

    if (typeof response === "function") {
      return response(params) as T;
    }

    return response as T;
  }
}

describe("MCP tools contract alignment", () => {
  it("uses app_id for secret.get after agent permission check", async () => {
    const client = new MockDaemonClient({
      "vault.status": { status: "unlocked", version: "0.1.0", secret_count: 1 },
      "agent.explain": {
        agent_id: "claude-code",
        permissions: [{ secret: "OPENAI_API_KEY", environment: "default" }],
      },
      "secret.get": { name: "OPENAI_API_KEY", value: "sk-test-123" },
    });

    const result = await getSecret(client as unknown as DaemonClient, {
      name: "OPENAI_API_KEY",
    });

    expect(result.isError).toBeUndefined();
    expect(result.content[0]).toEqual({
      type: "text",
      text: "Secret: OPENAI_API_KEY\nValue: sk-test-123",
    });

    const secretGetCall = client.calls.find((call) => call.method === "secret.get");
    expect(secretGetCall?.params).toEqual({
      name: "OPENAI_API_KEY",
      app_id: "cli",
    });
  });

  it("returns locked-vault error without querying agent/secret methods", async () => {
    const client = new MockDaemonClient({
      "vault.status": { state: "locked", secret_count: 0, app_count: 0 },
      "agent.explain": {
        agent_id: "claude-code",
        permissions: [{ secret: "OPENAI_API_KEY", environment: "default" }],
      },
      "secret.get": { name: "OPENAI_API_KEY", value: "sk-test-123" },
    });

    const result = await getSecret(client as unknown as DaemonClient, {
      name: "OPENAI_API_KEY",
    });

    expect(result.isError).toBe(true);
    expect((result.content[0] as { type: string; text: string }).text).toContain(
      "vault is locked"
    );
    expect(client.calls).toEqual([{ method: "vault.status", params: {} }]);
  });

  it("returns access denied and skips secret.get when agent lacks permission", async () => {
    const client = new MockDaemonClient({
      "vault.status": { status: "unlocked", version: "0.1.0", secret_count: 1 },
      "agent.explain": {
        agent_id: "claude-code",
        permissions: [],
      },
      "secret.get": { name: "OPENAI_API_KEY", value: "sk-test-123" },
    });

    const result = await getSecret(client as unknown as DaemonClient, {
      name: "OPENAI_API_KEY",
      environment: "prod",
    });

    expect(result.isError).toBe(true);
    expect((result.content[0] as { type: string; text: string }).text).toContain(
      "Access denied"
    );
    expect(client.calls.some((call) => call.method === "secret.get")).toBe(false);
  });

  it("filters listed secrets by agent permissions and environment", async () => {
    const client = new MockDaemonClient({
      "vault.status": { status: "unlocked", version: "0.1.0", secret_count: 2 },
      "secret.list": {
        secrets: [
          {
            name: "OPENAI_API_KEY",
            environment: "prod",
            provider: "openai",
            created_at: "2026-01-01 00:00:00",
          },
          {
            name: "STRIPE_SECRET",
            environment: "dev",
            provider: "stripe",
            created_at: "2026-01-01 00:00:00",
          },
        ],
      },
      "agent.explain": {
        agent_id: "claude-code",
        permissions: [{ secret: "OPENAI_API_KEY", environment: "prod" }],
      },
    });

    const result = await listSecrets(client as unknown as DaemonClient, {
      environment: "prod",
      filter: "OPENAI",
    });

    expect(result.isError).toBeUndefined();
    const text = (result.content[0] as { type: string; text: string }).text;
    expect(text).toContain("OPENAI_API_KEY");
    expect(text).not.toContain("STRIPE_SECRET");
    expect(text).toContain("Total: 1 secret(s)");
  });

  it("returns agent-not-registered guidance for listSecrets", async () => {
    const client = new MockDaemonClient({
      "vault.status": { state: "unlocked", secret_count: 1, app_count: 0 },
      "secret.list": {
        secrets: [
          {
            name: "OPENAI_API_KEY",
            environment: "default",
            provider: "openai",
            created_at: "2026-01-01 00:00:00",
          },
        ],
      },
      "agent.explain": new Error("Daemon error: Failed to explain agent permissions"),
    });

    const result = await listSecrets(client as unknown as DaemonClient, {});

    expect(result.isError).toBe(true);
    expect((result.content[0] as { type: string; text: string }).text).toContain(
      "not registered"
    );
  });

  it("formats vault status from daemon state payload", async () => {
    const client = new MockDaemonClient({
      "vault.status": { state: "unlocked", secret_count: 2, app_count: 1 },
    });

    const result = await getVaultStatus(client as unknown as DaemonClient);

    expect(result.isError).toBeUndefined();
    const text = (result.content[0] as { type: string; text: string }).text;
    expect(text).toContain("Status: unlocked");
    expect(text).toContain("Secrets: 2");
    expect(text).toContain("Apps: 1");
  });
});

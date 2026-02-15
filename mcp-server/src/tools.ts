/**
 * MCP Tool implementations for Secretariat
 *
 * Provides secure access to secrets for AI assistants through the MCP protocol.
 */

import { DaemonClient } from "./daemon-client.js";
import {
  GetSecretInputSchema,
  ListSecretsInputSchema,
  CheckPermissionInputSchema,
  type GetSecretInput,
  type ListSecretsInput,
  type CheckPermissionInput,
  type SecretGetResponse,
  type SecretListResponse,
  type VaultStatusResponse,
  type ToolResult,
} from "./types.js";

// Agent identifier for this MCP server instance
const AGENT_NAME = process.env.SECRETARIAT_AGENT_NAME ?? "claude-code";
// Daemon `secret.get` currently requires an app_id parameter.
const INTERNAL_APP_ID = "cli";

interface ExplainResponse {
  agent_id: string;
  permissions: Array<{ secret: string; environment: string }>;
}

function getVaultState(
  status: VaultStatusResponse
): "locked" | "unlocked" | "uninitialized" {
  return status.state ?? status.status ?? "uninitialized";
}

function hasAgentPermission(
  permissions: ExplainResponse["permissions"],
  secretName: string,
  environment?: string
): boolean {
  return permissions.some(
    (permission) =>
      permission.secret === secretName &&
      (!environment || permission.environment === environment)
  );
}

/**
 * Get a secret from the vault
 *
 * Retrieves a secret value if the AI agent has permission.
 * The secret is returned in a structured format.
 */
export async function getSecret(
  client: DaemonClient,
  input: GetSecretInput
): Promise<ToolResult> {
  try {
    // First check if vault is unlocked
    const status = await client.request<VaultStatusResponse>("vault.status", {});

    if (getVaultState(status) === "locked") {
      return {
        content: [
          {
            type: "text",
            text: "The Secretariat vault is locked. Please unlock it first using: sec unlock",
          },
        ],
        isError: true,
      };
    }

    if (getVaultState(status) === "uninitialized") {
      return {
        content: [
          {
            type: "text",
            text: "Secretariat has not been initialized. Please run: sec init",
          },
        ],
        isError: true,
      };
    }

    // Check agent permissions first. This keeps MCP behavior aligned with
    // `sec agent grant` / `agent.explain` even though daemon `secret.get`
    // itself is app_id-based.
    const permissions = await client.request<ExplainResponse>("agent.explain", {
      agent_id: AGENT_NAME,
    });

    if (!hasAgentPermission(permissions.permissions, input.name, input.environment)) {
      return {
        content: [
          {
            type: "text",
            text: `Access denied: Agent '${AGENT_NAME}' does not have permission to access secret '${input.name}'.\n\nGrant access with: sec agent grant ${AGENT_NAME} ${input.name}${input.environment ? ` --environment ${input.environment}` : ""}`,
          },
        ],
        isError: true,
      };
    }

    const response = await client.request<SecretGetResponse>("secret.get", {
      name: input.name,
      app_id: INTERNAL_APP_ID,
    });

    const outputLines = [`Secret: ${response.name}`, `Value: ${response.value}`];
    if (input.environment) {
      outputLines.push(`Environment: ${input.environment}`);
    }

    return {
      content: [
        {
          type: "text",
          text: outputLines.join("\n"),
        },
      ],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    // If agent not registered, provide helpful message
    if (
      message.includes("Agent not found") ||
      message.includes("Failed to explain agent permissions")
    ) {
      return {
        content: [
          {
            type: "text",
            text: `Agent '${AGENT_NAME}' is not registered with Secretariat.\n\nRegister it first:\n  sec agent register ${AGENT_NAME}`,
          },
        ],
        isError: true,
      };
    }

    // Check for permission denied
    if (message.includes("permission") || message.includes("access denied")) {
      return {
        content: [
          {
            type: "text",
            text: `Access denied: Agent '${AGENT_NAME}' does not have permission to access secret '${input.name}'.\n\nGrant access with: sec agent grant ${AGENT_NAME} ${input.name}${input.environment ? ` --environment ${input.environment}` : ""}`,
          },
        ],
        isError: true,
      };
    }

    // Check for secret not found
    if (message.includes("not found")) {
      return {
        content: [
          {
            type: "text",
            text: `Secret '${input.name}' not found. Use 'secretariat.list' to see available secrets.`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [{ type: "text", text: `Error retrieving secret: ${message}` }],
      isError: true,
    };
  }
}

/**
 * List available secrets
 *
 * Returns a list of secrets the AI agent can see (names only, not values).
 */
export async function listSecrets(
  client: DaemonClient,
  input: ListSecretsInput
): Promise<ToolResult> {
  try {
    // Check vault status
    const status = await client.request<VaultStatusResponse>("vault.status", {});

    if (getVaultState(status) === "locked") {
      return {
        content: [
          {
            type: "text",
            text: "The Secretariat vault is locked. Please unlock it first using: sec unlock",
          },
        ],
        isError: true,
      };
    }

    if (getVaultState(status) === "uninitialized") {
      return {
        content: [
          {
            type: "text",
            text: "Secretariat has not been initialized. Please run: sec init",
          },
        ],
        isError: true,
      };
    }

    // Load all secrets metadata from daemon and agent permissions separately,
    // then enforce agent/environment/filter constraints client-side.
    const response = await client.request<SecretListResponse>("secret.list", {});
    const permissions = await client.request<ExplainResponse>("agent.explain", {
      agent_id: AGENT_NAME,
    });

    if (!response.secrets || response.secrets.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: input.environment
              ? `No secrets found in environment '${input.environment}'.`
              : "No secrets found in the vault.",
          },
        ],
      };
    }

    // Filter by permissions first
    let secrets = response.secrets;
    secrets = secrets.filter((secret) =>
      hasAgentPermission(permissions.permissions, secret.name, secret.environment)
    );

    // Filter by environment if provided
    if (input.environment) {
      secrets = secrets.filter((secret) => secret.environment === input.environment);
    }

    // Filter by pattern if provided
    if (input.filter) {
      const pattern = input.filter.toLowerCase();
      secrets = secrets.filter((s) =>
        s.name.toLowerCase().includes(pattern)
      );
    }

    if (secrets.length === 0) {
      return {
        content: [
          {
            type: "text",
            text: `No secrets matching pattern '${input.filter}' found.`,
          },
        ],
      };
    }

    // Format output
    const lines = ["Available secrets:", ""];
    const maxNameLen = Math.max(...secrets.map((s) => s.name.length), 4);
    const maxEnvLen = Math.max(...secrets.map((s) => s.environment.length), 11);

    lines.push(
      `${"NAME".padEnd(maxNameLen)}  ${"ENVIRONMENT".padEnd(maxEnvLen)}  PROVIDER`
    );
    lines.push("-".repeat(maxNameLen + maxEnvLen + 20));

    for (const secret of secrets) {
      lines.push(
        `${secret.name.padEnd(maxNameLen)}  ${secret.environment.padEnd(maxEnvLen)}  ${secret.provider ?? "-"}`
      );
    }

    lines.push("");
    lines.push(`Total: ${secrets.length} secret(s)`);

    return {
      content: [{ type: "text", text: lines.join("\n") }],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    // If agent not registered, provide helpful message
    if (
      message.includes("Agent not found") ||
      message.includes("Failed to explain agent permissions")
    ) {
      return {
        content: [
          {
            type: "text",
            text: `Agent '${AGENT_NAME}' is not registered with Secretariat.\n\nRegister it first:\n  sec agent register ${AGENT_NAME}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [{ type: "text", text: `Error listing secrets: ${message}` }],
      isError: true,
    };
  }
}

/**
 * Check if the agent has permission to access a secret
 */
export async function checkPermission(
  client: DaemonClient,
  input: CheckPermissionInput
): Promise<ToolResult> {
  try {
    // Use agent.explain to check what secrets the agent can access
    const response = await client.request<ExplainResponse>("agent.explain", {
      agent_id: AGENT_NAME,
    });

    const hasAccess = hasAgentPermission(
      response.permissions,
      input.secret_name,
      input.environment
    );

    if (hasAccess) {
      return {
        content: [
          {
            type: "text",
            text: `✓ Agent '${AGENT_NAME}' has access to secret '${input.secret_name}'${input.environment ? ` in environment '${input.environment}'` : ""}.`,
          },
        ],
      };
    } else {
      return {
        content: [
          {
            type: "text",
            text: `✗ Agent '${AGENT_NAME}' does NOT have access to secret '${input.secret_name}'.\n\nTo grant access, run:\n  sec agent grant ${AGENT_NAME} ${input.secret_name}${input.environment ? ` --environment ${input.environment}` : ""}`,
          },
        ],
      };
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    // If agent not registered, provide helpful message
    if (
      message.includes("Agent not found") ||
      message.includes("Failed to explain agent permissions")
    ) {
      return {
        content: [
          {
            type: "text",
            text: `Agent '${AGENT_NAME}' is not registered with Secretariat.\n\nRegister it first:\n  sec agent register ${AGENT_NAME}`,
          },
        ],
        isError: true,
      };
    }

    return {
      content: [
        { type: "text", text: `Error checking permission: ${message}` },
      ],
      isError: true,
    };
  }
}

/**
 * Get vault status
 */
export async function getVaultStatus(
  client: DaemonClient
): Promise<ToolResult> {
  try {
    const status = await client.request<VaultStatusResponse>("vault.status", {});

    const lines = [
      "Secretariat Vault Status",
      "",
      `Status: ${getVaultState(status)}`,
      `Secrets: ${status.secret_count}`,
    ];

    if (typeof status.app_count === "number") {
      lines.push(`Apps: ${status.app_count}`);
    }

    if (status.version) {
      lines.push(`Version: ${status.version}`);
    }

    if (status.environments && status.environments.length > 0) {
      lines.push(`Environments: ${status.environments.join(", ")}`);
    }

    return {
      content: [{ type: "text", text: lines.join("\n") }],
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text", text: `Error getting vault status: ${message}` }],
      isError: true,
    };
  }
}

// Export schemas for MCP tool registration
export const toolSchemas = {
  get: GetSecretInputSchema,
  list: ListSecretsInputSchema,
  check: CheckPermissionInputSchema,
};

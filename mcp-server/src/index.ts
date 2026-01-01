#!/usr/bin/env node
/**
 * Secretariat MCP Server
 *
 * Model Context Protocol server for secure secrets management.
 * Enables AI assistants (Claude, Cursor, etc.) to securely access
 * secrets from the Secretariat vault.
 *
 * Usage:
 *   node dist/index.js
 *
 * Configuration (environment variables):
 *   SECRETARIAT_SOCKET - Path to daemon socket (default: ~/Library/Application Support/Secretariat/secretariat.sock)
 *   SECRETARIAT_AGENT_NAME - Agent identifier (default: claude-code)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  type CallToolResult,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { zodToJsonSchema } from "zod-to-json-schema";

import { DaemonClient } from "./daemon-client.js";
import {
  getSecret,
  listSecrets,
  checkPermission,
  getVaultStatus,
  toolSchemas,
} from "./tools.js";

// ============================================================================
// Server Setup
// ============================================================================

const server = new Server(
  {
    name: "secretariat",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
      resources: {},
    },
  }
);

const daemonClient = new DaemonClient();

// ============================================================================
// Tool Definitions
// ============================================================================

const TOOLS: Tool[] = [
  {
    name: "secretariat.get",
    description:
      "Retrieve a secret from the Secretariat vault. " +
      "Returns the secret value if the AI agent has been granted access. " +
      "Use this to get API keys, database passwords, and other credentials.",
    inputSchema: zodToJsonSchema(toolSchemas.get) as Tool["inputSchema"],
  },
  {
    name: "secretariat.list",
    description:
      "List available secrets in the Secretariat vault. " +
      "Shows secret names, environments, and providers (but not values). " +
      "Use this to discover what secrets are available before requesting specific ones.",
    inputSchema: zodToJsonSchema(toolSchemas.list) as Tool["inputSchema"],
  },
  {
    name: "secretariat.check",
    description:
      "Check if this AI agent has permission to access a specific secret. " +
      "Use this before attempting to retrieve a secret to verify access.",
    inputSchema: zodToJsonSchema(toolSchemas.check) as Tool["inputSchema"],
  },
  {
    name: "secretariat.status",
    description:
      "Get the current status of the Secretariat vault. " +
      "Shows if the vault is locked, unlocked, or uninitialized.",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
  },
];

// ============================================================================
// Request Handlers
// ============================================================================

/**
 * Handle tool listing requests
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

/**
 * Handle tool execution requests
 */
server.setRequestHandler(CallToolRequestSchema, async (request): Promise<CallToolResult> => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "secretariat.get": {
      const parsed = toolSchemas.get.safeParse(args);
      if (!parsed.success) {
        return {
          content: [
            {
              type: "text",
              text: `Invalid arguments: ${parsed.error.message}`,
            },
          ],
          isError: true,
        };
      }
      const result = await getSecret(daemonClient, parsed.data);
      return {
        content: result.content.map(c => ({
          type: "text" as const,
          text: c.type === "text" ? c.text : JSON.stringify(c),
        })),
        isError: result.isError,
      };
    }

    case "secretariat.list": {
      const parsed = toolSchemas.list.safeParse(args);
      if (!parsed.success) {
        return {
          content: [
            {
              type: "text",
              text: `Invalid arguments: ${parsed.error.message}`,
            },
          ],
          isError: true,
        };
      }
      const result = await listSecrets(daemonClient, parsed.data);
      return {
        content: result.content.map(c => ({
          type: "text" as const,
          text: c.type === "text" ? c.text : JSON.stringify(c),
        })),
        isError: result.isError,
      };
    }

    case "secretariat.check": {
      const parsed = toolSchemas.check.safeParse(args);
      if (!parsed.success) {
        return {
          content: [
            {
              type: "text",
              text: `Invalid arguments: ${parsed.error.message}`,
            },
          ],
          isError: true,
        };
      }
      const result = await checkPermission(daemonClient, parsed.data);
      return {
        content: result.content.map(c => ({
          type: "text" as const,
          text: c.type === "text" ? c.text : JSON.stringify(c),
        })),
        isError: result.isError,
      };
    }

    case "secretariat.status": {
      const result = await getVaultStatus(daemonClient);
      return {
        content: result.content.map(c => ({
          type: "text" as const,
          text: c.type === "text" ? c.text : JSON.stringify(c),
        })),
        isError: result.isError,
      };
    }

    default:
      return {
        content: [
          {
            type: "text",
            text: `Unknown tool: ${name}`,
          },
        ],
        isError: true,
      };
  }
});

/**
 * Handle resource listing (provides vault status as a resource)
 */
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return {
    resources: [
      {
        uri: "secretariat://vault/status",
        name: "Vault Status",
        description: "Current status of the Secretariat vault",
        mimeType: "text/plain",
      },
    ],
  };
});

/**
 * Handle resource reading
 */
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  if (uri === "secretariat://vault/status") {
    const result = await getVaultStatus(daemonClient);
    const text = result.content
      .filter((c): c is { type: "text"; text: string } => c.type === "text")
      .map((c) => c.text)
      .join("\n");

    return {
      contents: [
        {
          uri,
          mimeType: "text/plain",
          text,
        },
      ],
    };
  }

  throw new Error(`Unknown resource: ${uri}`);
});

// ============================================================================
// Main Entry Point
// ============================================================================

async function main() {
  // Check daemon connectivity on startup
  const isHealthy = await daemonClient.isHealthy();
  if (!isHealthy) {
    console.error(
      "Warning: Cannot connect to Secretariat daemon. " +
        "Some operations may fail until the daemon is started."
    );
  }

  // Start the MCP server with stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log to stderr (stdout is used for MCP protocol)
  console.error("Secretariat MCP server started");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

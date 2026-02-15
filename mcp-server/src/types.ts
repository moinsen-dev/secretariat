/**
 * Type definitions for Secretariat MCP Server
 */

import { z } from "zod";

// ============================================================================
// Tool Input Schemas
// ============================================================================

export const GetSecretInputSchema = z.object({
  name: z.string().describe("The name of the secret to retrieve (e.g., OPENAI_API_KEY)"),
  environment: z
    .string()
    .optional()
    .describe("Environment context (default, dev, staging, prod). Defaults to current environment."),
});

export const ListSecretsInputSchema = z.object({
  environment: z
    .string()
    .optional()
    .describe("Filter secrets by environment. Shows all if not specified."),
  filter: z
    .string()
    .optional()
    .describe("Filter secrets by name pattern (e.g., 'AWS_' to show AWS-related secrets)"),
});

export const CheckPermissionInputSchema = z.object({
  secret_name: z.string().describe("Name of the secret to check access for"),
  environment: z
    .string()
    .optional()
    .describe("Environment to check permission in"),
});

// ============================================================================
// Daemon Response Types
// ============================================================================

export interface SecretEntry {
  name: string;
  environment: string;
  provider: string | null;
  created_at: string;
}

export interface SecretListResponse {
  secrets: SecretEntry[];
}

export interface SecretGetResponse {
  name: string;
  value: string;
}

export interface VaultStatusResponse {
  state?: "locked" | "unlocked" | "uninitialized";
  status?: "locked" | "unlocked" | "uninitialized";
  secret_count: number;
  app_count?: number;
  version?: string;
  environments?: string[];
}

export interface AgentInfo {
  id: string;
  name: string;
  agent_type: string;
  created_at: string;
  last_access: string | null;
  permission_count: number;
}

export interface AgentListResponse {
  agents: AgentInfo[];
}

export interface PermissionCheckResponse {
  has_permission: boolean;
  agent_id: string;
  secret_name: string;
  environment: string;
}

// ============================================================================
// Tool Result Types
// ============================================================================

export type ToolContent =
  | { type: "text"; text: string }
  | { type: "resource"; resource: { uri: string; text: string; mimeType: string } };

export interface ToolResult {
  content: ToolContent[];
  isError?: boolean;
}

// ============================================================================
// Type inference helpers
// ============================================================================

export type GetSecretInput = z.infer<typeof GetSecretInputSchema>;
export type ListSecretsInput = z.infer<typeof ListSecretsInputSchema>;
export type CheckPermissionInput = z.infer<typeof CheckPermissionInputSchema>;

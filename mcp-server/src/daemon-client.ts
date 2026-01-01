/**
 * Daemon Client for Secretariat
 *
 * Connects to the Secretariat daemon via Unix socket and sends JSON-RPC 2.0 requests.
 */

import * as net from "node:net";
import * as path from "node:path";
import * as os from "node:os";

export interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params: Record<string, unknown>;
}

export interface JsonRpcResponse<T = unknown> {
  jsonrpc: "2.0";
  id: number;
  result?: T;
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}

export class DaemonClient {
  private socketPath: string;
  private requestId = 0;

  constructor(socketPath?: string) {
    this.socketPath =
      socketPath ??
      process.env.SECRETARIAT_SOCKET ??
      path.join(
        os.homedir(),
        "Library",
        "Application Support",
        "Secretariat",
        "secretariat.sock"
      );
  }

  /**
   * Send a JSON-RPC request to the daemon
   */
  async request<T>(
    method: string,
    params: Record<string, unknown> = {}
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      const client = net.createConnection({ path: this.socketPath }, () => {
        const request: JsonRpcRequest = {
          jsonrpc: "2.0",
          id: ++this.requestId,
          method,
          params,
        };

        client.write(JSON.stringify(request) + "\n");
      });

      let data = "";

      client.on("data", (chunk) => {
        data += chunk.toString();

        // Check if we have a complete JSON response (ends with newline)
        if (data.includes("\n")) {
          try {
            const response: JsonRpcResponse<T> = JSON.parse(data.trim());
            client.end();

            if (response.error) {
              reject(
                new Error(
                  `Daemon error: ${response.error.message} (code: ${response.error.code})`
                )
              );
            } else {
              resolve(response.result as T);
            }
          } catch {
            reject(new Error(`Invalid JSON response from daemon: ${data}`));
          }
        }
      });

      client.on("error", (err) => {
        if ((err as NodeJS.ErrnoException).code === "ENOENT") {
          reject(
            new Error(
              `Secretariat daemon not running. Start it with: sec daemon start`
            )
          );
        } else if ((err as NodeJS.ErrnoException).code === "ECONNREFUSED") {
          reject(
            new Error(
              `Cannot connect to Secretariat daemon. Is it running? Try: sec daemon start`
            )
          );
        } else {
          reject(new Error(`Daemon connection error: ${err.message}`));
        }
      });

      client.on("timeout", () => {
        client.destroy();
        reject(new Error("Connection to daemon timed out"));
      });

      // Set a reasonable timeout
      client.setTimeout(5000);
    });
  }

  /**
   * Check if the daemon is running and responsive
   */
  async isHealthy(): Promise<boolean> {
    try {
      await this.request("health.check", {});
      return true;
    } catch {
      return false;
    }
  }
}

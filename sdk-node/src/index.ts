// F239-F246: Node.js/TypeScript SDK for Secretariat
//
// Features:
// - F239: Create sdk-node/src/index.ts file
// - F240: Import net from 'net' for Unix socket
// - F241: Define export class Secretariat
// - F242: Add private socket: Socket | null field
// - F243: Implement async get(key: string): Promise<string>
// - F244: Connect with net.createConnection({ path: socketPath })
// - F245: Write JSON request to socket
// - F246: Read response and parse with JSON.parse

// F240: Import net from 'net' for Unix socket
import * as net from 'net';
import * as os from 'os';

/**
 * Error thrown by Secretariat SDK
 */
export class SecretariatError extends Error {
  /** Optional error code */
  public readonly code?: number;

  constructor(message: string, code?: number) {
    super(message);
    this.name = 'SecretariatError';
    this.code = code;
  }
}

/**
 * Options for Secretariat client
 */
export interface SecretariatOptions {
  /** Custom path to Unix socket or named pipe */
  socketPath?: string;
  /** Request timeout in milliseconds (default: 5000) */
  timeout?: number;
}

// F241: Define export class Secretariat
/**
 * Secretariat client for retrieving secrets from the daemon.
 *
 * This client communicates with the local Secretariat daemon via Unix
 * domain socket (macOS/Linux) or named pipe (Windows).
 *
 * @example
 * ```typescript
 * import { Secretariat } from '@secretariat/node';
 *
 * const client = new Secretariat();
 * const apiKey = await client.get('OPENAI_API_KEY');
 * console.log('API Key:', apiKey);
 * ```
 */
export class Secretariat {
  /** Default socket path on Unix systems */
  private static readonly DEFAULT_SOCKET_PATH = '/tmp/secretariat.sock';

  /** Default named pipe path on Windows */
  private static readonly DEFAULT_PIPE_PATH = '\\\\.\\pipe\\secretariat';

  // F242: Add private socket: Socket | null field
  private socket: net.Socket | null = null;

  /** Socket/pipe path */
  private readonly socketPath: string;

  /** Request timeout in milliseconds */
  private readonly timeout: number;

  /** Request ID counter for JSON-RPC */
  private requestId = 0;

  /**
   * Create a new Secretariat client
   *
   * @param options - Client configuration options
   */
  constructor(options: SecretariatOptions = {}) {
    this.socketPath = options.socketPath ?? this.getDefaultSocketPath();
    this.timeout = options.timeout ?? 5000;
  }

  /**
   * Get the default socket path based on platform
   */
  private getDefaultSocketPath(): string {
    if (os.platform() === 'win32') {
      return Secretariat.DEFAULT_PIPE_PATH;
    }
    return Secretariat.DEFAULT_SOCKET_PATH;
  }

  // F244: Connect with net.createConnection({ path: socketPath })
  /**
   * Connect to the daemon socket
   */
  private connect(): Promise<net.Socket> {
    return new Promise((resolve, reject) => {
      if (this.socket !== null) {
        resolve(this.socket);
        return;
      }

      // F244: Connect using net.createConnection
      const socket = net.createConnection({ path: this.socketPath });

      socket.setTimeout(this.timeout);

      socket.on('connect', () => {
        this.socket = socket;
        resolve(socket);
      });

      socket.on('error', (err) => {
        this.socket = null;
        reject(new SecretariatError(
          `Failed to connect to Secretariat daemon at ${this.socketPath}: ${err.message}`
        ));
      });

      socket.on('timeout', () => {
        socket.destroy();
        this.socket = null;
        reject(new SecretariatError('Connection timed out'));
      });
    });
  }

  /**
   * Send JSON-RPC request to daemon
   */
  private async sendRequest<T>(
    method: string,
    params: Record<string, unknown>
  ): Promise<T> {
    const socket = await this.connect();

    const requestId = ++this.requestId;

    // Build JSON-RPC 2.0 request
    const request = {
      jsonrpc: '2.0',
      id: requestId,
      method,
      params,
    };

    // F245: Write JSON request to socket
    const requestJson = JSON.stringify(request) + '\n';

    return new Promise((resolve, reject) => {
      let responseData = '';

      const cleanup = () => {
        socket.removeAllListeners('data');
        socket.removeAllListeners('error');
        socket.removeAllListeners('timeout');
      };

      // F246: Read response and parse with JSON.parse
      socket.on('data', (data: Buffer) => {
        responseData += data.toString();

        // Check for complete response (ends with newline)
        if (responseData.endsWith('\n')) {
          cleanup();

          try {
            const response = JSON.parse(responseData.trim());

            // Validate response ID
            if (response.id !== requestId) {
              reject(new SecretariatError('Response ID mismatch'));
              return;
            }

            // Check for errors
            if (response.error) {
              reject(new SecretariatError(
                response.error.message || 'Unknown error',
                response.error.code
              ));
              return;
            }

            resolve(response.result as T);
          } catch (e) {
            reject(new SecretariatError(
              `Failed to parse response: ${e instanceof Error ? e.message : String(e)}`
            ));
          }
        }
      });

      socket.on('error', (err) => {
        cleanup();
        reject(new SecretariatError(`Socket error: ${err.message}`));
      });

      socket.on('timeout', () => {
        cleanup();
        reject(new SecretariatError('Request timed out'));
      });

      // Send request
      socket.write(requestJson);
    });
  }

  // F243: Implement async get(key: string): Promise<string>
  /**
   * Get secret value by key
   *
   * @param key - Secret name/key (e.g., 'OPENAI_API_KEY')
   * @returns Decrypted secret value
   * @throws {SecretariatError} If secret not found, permission denied, or communication error
   *
   * @example
   * ```typescript
   * const client = new Secretariat();
   * const apiKey = await client.get('OPENAI_API_KEY');
   * console.log('API Key:', apiKey);
   * ```
   */
  async get(key: string): Promise<string> {
    const result = await this.sendRequest<{ value: string }>(
      'secret.get',
      { key }
    );

    if (!result || typeof result.value !== 'string') {
      throw new SecretariatError('Invalid response: missing value');
    }

    return result.value;
  }

  /**
   * Get multiple secrets at once
   *
   * @param keys - List of secret names to retrieve
   * @returns Map of key to value pairs
   *
   * @example
   * ```typescript
   * const secrets = await client.getMany(['OPENAI_API_KEY', 'DATABASE_URL']);
   * console.log(secrets.get('OPENAI_API_KEY'));
   * ```
   */
  async getMany(keys: string[]): Promise<Map<string, string>> {
    const results = new Map<string, string>();

    for (const key of keys) {
      results.set(key, await this.get(key));
    }

    return results;
  }

  /**
   * List all available secret names
   *
   * @returns Array of secret names (not values)
   *
   * @example
   * ```typescript
   * const names = await client.list();
   * console.log('Available secrets:', names);
   * ```
   */
  async list(): Promise<string[]> {
    const result = await this.sendRequest<{ secrets: string[] }>(
      'secret.list',
      {}
    );

    if (!result || !Array.isArray(result.secrets)) {
      throw new SecretariatError('Invalid response: missing secrets');
    }

    return result.secrets;
  }

  /**
   * Close the connection to the daemon
   *
   * Call this when done to free resources.
   */
  close(): void {
    if (this.socket !== null) {
      this.socket.destroy();
      this.socket = null;
    }
  }
}

/**
 * Get a secret with environment variable fallback
 *
 * Tries to get the secret from the daemon. If unavailable,
 * falls back to the environment variable.
 *
 * @param key - Secret name/key
 * @param options - Client options
 * @returns Secret value from daemon or environment
 * @throws {SecretariatError} If neither daemon nor environment has value
 *
 * @example
 * ```typescript
 * import { getOrEnv } from '@secretariat/node';
 *
 * const apiKey = await getOrEnv('OPENAI_API_KEY');
 * ```
 */
export async function getOrEnv(
  key: string,
  options?: SecretariatOptions
): Promise<string> {
  const client = new Secretariat(options);

  try {
    return await client.get(key);
  } catch {
    // Fall back to environment variable
    const value = process.env[key];
    if (value !== undefined) {
      return value;
    }
    throw new SecretariatError(
      `Secret '${key}' not found in daemon or environment variable`
    );
  } finally {
    client.close();
  }
}

/**
 * Quick function to get a single secret
 *
 * @param key - Secret name/key
 * @param options - Client options
 * @returns Secret value
 *
 * @example
 * ```typescript
 * import { get } from '@secretariat/node';
 *
 * const apiKey = await get('OPENAI_API_KEY');
 * ```
 */
export async function get(
  key: string,
  options?: SecretariatOptions
): Promise<string> {
  const client = new Secretariat(options);

  try {
    return await client.get(key);
  } finally {
    client.close();
  }
}

// Default export
export default Secretariat;

// Package secretariat provides a Go client for the Secretariat secrets manager daemon.
//
// Secretariat is a local-first secrets manager that stores API keys, tokens, and
// other secrets securely. This SDK communicates with the local Secretariat daemon
// via Unix domain socket.
//
// Example usage:
//
//	client, err := secretariat.New()
//	if err != nil {
//	    log.Fatal(err)
//	}
//	defer client.Close()
//
//	apiKey, err := client.Get("OPENAI_API_KEY")
//	if err != nil {
//	    log.Fatal(err)
//	}
//	fmt.Println("API Key:", apiKey)
package secretariat

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"
)

// Default socket paths by platform
const (
	defaultTimeoutSeconds = 5
)

// Error types
var (
	// ErrNotConnected is returned when the client is not connected to the daemon.
	ErrNotConnected = errors.New("not connected to daemon")

	// ErrNotFound is returned when a secret is not found.
	ErrNotFound = errors.New("secret not found")

	// ErrPermissionDenied is returned when access to a secret is denied.
	ErrPermissionDenied = errors.New("permission denied")

	// ErrVaultLocked is returned when the vault is locked.
	ErrVaultLocked = errors.New("vault is locked")

	// ErrTimeout is returned when a request times out.
	ErrTimeout = errors.New("request timed out")
)

// SecretariatError represents an error from the Secretariat daemon.
type SecretariatError struct {
	Message string
	Code    int
}

func (e *SecretariatError) Error() string {
	if e.Code != 0 {
		return fmt.Sprintf("secretariat error (%d): %s", e.Code, e.Message)
	}
	return fmt.Sprintf("secretariat error: %s", e.Message)
}

// jsonRPCRequest is the JSON-RPC 2.0 request format.
type jsonRPCRequest struct {
	JSONRPC string                 `json:"jsonrpc"`
	ID      int                    `json:"id"`
	Method  string                 `json:"method"`
	Params  map[string]interface{} `json:"params"`
}

// jsonRPCResponse is the JSON-RPC 2.0 response format.
type jsonRPCResponse struct {
	JSONRPC string                 `json:"jsonrpc"`
	ID      int                    `json:"id"`
	Result  map[string]interface{} `json:"result,omitempty"`
	Error   *jsonRPCError          `json:"error,omitempty"`
}

type jsonRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// SecretInfo contains metadata about a secret.
type SecretInfo struct {
	Name        string `json:"name"`
	Provider    string `json:"provider,omitempty"`
	Environment string `json:"environment,omitempty"`
	CreatedAt   string `json:"created_at,omitempty"`
	UpdatedAt   string `json:"updated_at,omitempty"`
}

// Client is a Secretariat daemon client.
type Client struct {
	socketPath string
	timeout    time.Duration
	conn       net.Conn
	reader     *bufio.Reader
	requestID  int
	mu         sync.Mutex
}

// Option is a functional option for configuring the Client.
type Option func(*Client)

// WithSocketPath sets a custom socket path.
func WithSocketPath(path string) Option {
	return func(c *Client) {
		c.socketPath = path
	}
}

// WithTimeout sets the request timeout.
func WithTimeout(d time.Duration) Option {
	return func(c *Client) {
		c.timeout = d
	}
}

// New creates a new Secretariat client.
// It automatically detects the platform and uses the appropriate socket path.
func New(opts ...Option) (*Client, error) {
	c := &Client{
		timeout: defaultTimeoutSeconds * time.Second,
	}

	for _, opt := range opts {
		opt(c)
	}

	// Determine default socket path if not set
	if c.socketPath == "" {
		c.socketPath = defaultSocketPath()
	}

	// Connect to daemon
	if err := c.connect(); err != nil {
		return nil, fmt.Errorf("failed to connect to daemon: %w", err)
	}

	return c, nil
}

// defaultSocketPath returns the default socket path for the current platform.
func defaultSocketPath() string {
	if env := os.Getenv("SECRETARIAT_SOCKET_PATH"); env != "" {
		return env
	}
	if env := os.Getenv("SECRETARIAT_SOCKET"); env != "" {
		return env
	}

	switch runtime.GOOS {
	case "darwin": // macOS
		home, _ := os.UserHomeDir()
		return filepath.Join(home, "Library", "Application Support", "Secretariat", "secretariat.sock")
	case "linux":
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".local", "share", "secretariat", "secretariat.sock")
	case "windows":
		return `\\.\pipe\secretariat`
	default:
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".local", "share", "secretariat", "secretariat.sock")
	}
}

// connect establishes connection to the daemon.
func (c *Client) connect() error {
	conn, err := net.DialTimeout("unix", c.socketPath, c.timeout)
	if err != nil {
		return fmt.Errorf("cannot connect to %s: %w", c.socketPath, err)
	}
	c.conn = conn
	c.reader = bufio.NewReader(conn)
	return nil
}

// Close closes the connection to the daemon.
func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn != nil {
		err := c.conn.Close()
		c.conn = nil
		c.reader = nil
		return err
	}
	return nil
}

// request sends a JSON-RPC request and returns the response.
func (c *Client) request(method string, params map[string]interface{}) (map[string]interface{}, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return nil, ErrNotConnected
	}

	// Increment request ID
	c.requestID++
	id := c.requestID

	// Build request
	req := jsonRPCRequest{
		JSONRPC: "2.0",
		ID:      id,
		Method:  method,
		Params:  params,
	}

	// Encode and send
	data, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to encode request: %w", err)
	}

	// Set deadline
	if err := c.conn.SetDeadline(time.Now().Add(c.timeout)); err != nil {
		return nil, fmt.Errorf("failed to set deadline: %w", err)
	}

	// Send with newline terminator
	if _, err := c.conn.Write(append(data, '\n')); err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}

	// Read response
	line, err := c.reader.ReadBytes('\n')
	if err != nil {
		if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
			return nil, ErrTimeout
		}
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Parse response
	var resp jsonRPCResponse
	if err := json.Unmarshal(line, &resp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	// Check ID
	if resp.ID != id {
		return nil, fmt.Errorf("response ID mismatch: expected %d, got %d", id, resp.ID)
	}

	// Check for error
	if resp.Error != nil {
		return nil, &SecretariatError{
			Message: resp.Error.Message,
			Code:    resp.Error.Code,
		}
	}

	return resp.Result, nil
}

// Get retrieves a secret value by name.
//
// Example:
//
//	apiKey, err := client.Get("OPENAI_API_KEY")
func (c *Client) Get(name string) (string, error) {
	return c.GetWithOptions(name, GetOptions{})
}

// GetOptions configures a Get request.
type GetOptions struct {
	// AppID identifies the requesting application for permission checks.
	AppID string

	// Environment specifies which environment to get the secret from.
	Environment string
}

// GetWithOptions retrieves a secret with additional options.
func (c *Client) GetWithOptions(name string, opts GetOptions) (string, error) {
	params := map[string]interface{}{
		"name": name,
	}
	appID := opts.AppID
	if appID == "" {
		appID = "go-sdk"
	}
	params["app_id"] = appID
	if opts.Environment != "" {
		params["environment"] = opts.Environment
	}

	result, err := c.request("secret.get", params)
	if err != nil {
		return "", err
	}

	value, ok := result["value"].(string)
	if !ok {
		return "", fmt.Errorf("invalid response: missing value")
	}

	return value, nil
}

// GetMany retrieves multiple secrets at once.
//
// Example:
//
//	secrets, err := client.GetMany([]string{"OPENAI_API_KEY", "DATABASE_URL"})
func (c *Client) GetMany(names []string) (map[string]string, error) {
	results := make(map[string]string, len(names))
	for _, name := range names {
		value, err := c.Get(name)
		if err != nil {
			return nil, fmt.Errorf("failed to get %s: %w", name, err)
		}
		results[name] = value
	}
	return results, nil
}

// List returns all available secret names.
//
// Example:
//
//	names, err := client.List()
func (c *Client) List() ([]SecretInfo, error) {
	result, err := c.request("secret.list", map[string]interface{}{})
	if err != nil {
		return nil, err
	}

	secretsRaw, ok := result["secrets"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid response: missing secrets")
	}

	secrets := make([]SecretInfo, 0, len(secretsRaw))
	for _, s := range secretsRaw {
		switch v := s.(type) {
		case map[string]interface{}:
			info := SecretInfo{}
			if name, ok := v["name"].(string); ok {
				info.Name = name
			}
			if provider, ok := v["provider"].(string); ok {
				info.Provider = provider
			}
			if env, ok := v["environment"].(string); ok {
				info.Environment = env
			}
			secrets = append(secrets, info)
		case string:
			secrets = append(secrets, SecretInfo{Name: v})
		}
	}

	return secrets, nil
}

// ListNames returns just the secret names.
func (c *Client) ListNames() ([]string, error) {
	secrets, err := c.List()
	if err != nil {
		return nil, err
	}

	names := make([]string, len(secrets))
	for i, s := range secrets {
		names[i] = s.Name
	}
	return names, nil
}

// Set creates or updates a secret.
//
// Example:
//
//	err := client.Set("API_KEY", "sk-123456789")
func (c *Client) Set(name, value string) error {
	return c.SetWithOptions(name, value, SetOptions{})
}

// SetOptions configures a Set request.
type SetOptions struct {
	// Environment specifies which environment to store the secret in.
	Environment string

	// Provider identifies the secret provider (e.g., "openai", "stripe").
	Provider string
}

// SetWithOptions creates or updates a secret with additional options.
func (c *Client) SetWithOptions(name, value string, opts SetOptions) error {
	params := map[string]interface{}{
		"name":  name,
		"value": value,
	}
	if opts.Environment != "" {
		params["environment"] = opts.Environment
	}
	if opts.Provider != "" {
		params["provider"] = opts.Provider
	}

	_, err := c.request("secret.set", params)
	return err
}

// Delete removes a secret.
//
// Example:
//
//	err := client.Delete("OLD_API_KEY")
func (c *Client) Delete(name string) error {
	_, err := c.request("secret.delete", map[string]interface{}{
		"name": name,
	})
	return err
}

// Ping checks if the daemon is responding.
func (c *Client) Ping() error {
	_, err := c.request("health.check", map[string]interface{}{})
	return err
}

// MustGet retrieves a secret or panics on error.
// Useful for initialization code where failure is fatal.
//
// Example:
//
//	apiKey := client.MustGet("OPENAI_API_KEY")
func (c *Client) MustGet(name string) string {
	value, err := c.Get(name)
	if err != nil {
		panic(fmt.Sprintf("secretariat: failed to get %s: %v", name, err))
	}
	return value
}

// Get is a convenience function that creates a client, gets a secret, and closes.
//
// Example:
//
//	apiKey, err := secretariat.Get("OPENAI_API_KEY")
func Get(name string) (string, error) {
	client, err := New()
	if err != nil {
		return "", err
	}
	defer client.Close()

	return client.Get(name)
}

// MustGet is a convenience function that gets a secret or panics.
//
// Example:
//
//	apiKey := secretariat.MustGet("OPENAI_API_KEY")
func MustGet(name string) string {
	value, err := Get(name)
	if err != nil {
		panic(fmt.Sprintf("secretariat: failed to get %s: %v", name, err))
	}
	return value
}

// GetOrEnv gets a secret with environment variable fallback.
//
// It first tries to get the secret from the daemon. If that fails,
// it falls back to the environment variable.
//
// Example:
//
//	apiKey := secretariat.GetOrEnv("OPENAI_API_KEY", "")
func GetOrEnv(name, envVar string) string {
	if envVar == "" {
		envVar = name
	}

	value, err := Get(name)
	if err == nil {
		return value
	}

	// Fall back to environment variable
	return os.Getenv(envVar)
}

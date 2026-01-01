# Secretariat Go SDK

Go client for the Secretariat secrets manager daemon.

## Installation

```bash
go get github.com/secretariat-team/secretariat-go
```

## Quick Start

```go
package main

import (
    "fmt"
    "log"

    secretariat "github.com/secretariat-team/secretariat-go"
)

func main() {
    // Create client (connects to daemon automatically)
    client, err := secretariat.New()
    if err != nil {
        log.Fatal(err)
    }
    defer client.Close()

    // Get a secret
    apiKey, err := client.Get("OPENAI_API_KEY")
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("API Key:", apiKey)
}
```

## Usage

### Creating a Client

```go
// Default (auto-detects socket path)
client, err := secretariat.New()

// With custom socket path
client, err := secretariat.New(
    secretariat.WithSocketPath("/custom/path/secretariat.sock"),
)

// With custom timeout
client, err := secretariat.New(
    secretariat.WithTimeout(10 * time.Second),
)

// Always close when done
defer client.Close()
```

### Getting Secrets

```go
// Get a single secret
apiKey, err := client.Get("OPENAI_API_KEY")

// Get with options (environment, app ID)
apiKey, err := client.GetWithOptions("OPENAI_API_KEY", secretariat.GetOptions{
    Environment: "production",
    AppID:       "my-app",
})

// Get multiple secrets
secrets, err := client.GetMany([]string{"OPENAI_API_KEY", "DATABASE_URL"})
fmt.Println(secrets["OPENAI_API_KEY"])

// Must get (panics on error - use for init)
apiKey := client.MustGet("OPENAI_API_KEY")
```

### Listing Secrets

```go
// List all secrets with metadata
secrets, err := client.List()
for _, s := range secrets {
    fmt.Printf("%s (provider: %s, env: %s)\n", s.Name, s.Provider, s.Environment)
}

// List just names
names, err := client.ListNames()
```

### Setting Secrets

```go
// Set a secret
err := client.Set("API_KEY", "sk-123456789")

// Set with options
err := client.SetWithOptions("API_KEY", "sk-123456789", secretariat.SetOptions{
    Environment: "production",
    Provider:    "openai",
})
```

### Deleting Secrets

```go
err := client.Delete("OLD_API_KEY")
```

### Convenience Functions

```go
// One-shot get (creates client, gets secret, closes)
apiKey, err := secretariat.Get("OPENAI_API_KEY")

// Must get (panics on error)
apiKey := secretariat.MustGet("OPENAI_API_KEY")

// Get with environment variable fallback
apiKey := secretariat.GetOrEnv("OPENAI_API_KEY", "OPENAI_API_KEY")
```

## Error Handling

```go
value, err := client.Get("API_KEY")
if err != nil {
    switch {
    case errors.Is(err, secretariat.ErrNotFound):
        log.Println("Secret not found")
    case errors.Is(err, secretariat.ErrPermissionDenied):
        log.Println("Access denied - check app permissions")
    case errors.Is(err, secretariat.ErrVaultLocked):
        log.Println("Vault is locked - run: sec unlock")
    case errors.Is(err, secretariat.ErrTimeout):
        log.Println("Request timed out")
    default:
        var secErr *secretariat.SecretariatError
        if errors.As(err, &secErr) {
            log.Printf("Secretariat error %d: %s", secErr.Code, secErr.Message)
        } else {
            log.Printf("Unknown error: %v", err)
        }
    }
}
```

## Platform Support

| Platform | Socket Path |
|----------|-------------|
| macOS | `~/Library/Application Support/Secretariat/secretariat.sock` |
| Linux | `~/.local/share/secretariat/secretariat.sock` |
| Windows | `\\.\pipe\secretariat` |

## Thread Safety

The `Client` is thread-safe. You can share a single client across goroutines.

## License

MIT

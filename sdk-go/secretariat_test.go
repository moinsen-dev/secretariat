package secretariat

import (
	"runtime"
	"testing"
)

func TestDefaultSocketPath(t *testing.T) {
	path := defaultSocketPath()

	switch runtime.GOOS {
	case "darwin":
		if path == "" || path[0] != '/' {
			t.Errorf("expected absolute path on macOS, got %s", path)
		}
		if !contains(path, "Secretariat") {
			t.Errorf("expected path to contain 'Secretariat', got %s", path)
		}
	case "linux":
		if path == "" || path[0] != '/' {
			t.Errorf("expected absolute path on Linux, got %s", path)
		}
		if !contains(path, "secretariat") {
			t.Errorf("expected path to contain 'secretariat', got %s", path)
		}
	case "windows":
		if path != `\\.\pipe\secretariat` {
			t.Errorf("expected Windows named pipe, got %s", path)
		}
	}
}

func TestSecretariatErrorString(t *testing.T) {
	tests := []struct {
		err      SecretariatError
		expected string
	}{
		{
			err:      SecretariatError{Message: "not found", Code: 404},
			expected: "secretariat error (404): not found",
		},
		{
			err:      SecretariatError{Message: "unknown error", Code: 0},
			expected: "secretariat error: unknown error",
		},
	}

	for _, tt := range tests {
		if got := tt.err.Error(); got != tt.expected {
			t.Errorf("SecretariatError.Error() = %s, want %s", got, tt.expected)
		}
	}
}

func TestWithSocketPath(t *testing.T) {
	c := &Client{}
	WithSocketPath("/custom/path")(c)

	if c.socketPath != "/custom/path" {
		t.Errorf("socketPath = %s, want /custom/path", c.socketPath)
	}
}

func TestWithTimeout(t *testing.T) {
	c := &Client{}
	WithTimeout(10 * 1000 * 1000 * 1000)(c) // 10 seconds in nanoseconds

	if c.timeout != 10*1000*1000*1000 {
		t.Errorf("timeout = %v, want 10s", c.timeout)
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr ||
		len(s) > len(substr) && (s[:len(substr)] == substr ||
			s[len(s)-len(substr):] == substr ||
			containsMiddle(s, substr)))
}

func containsMiddle(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

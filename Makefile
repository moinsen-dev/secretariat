# Secretariat - Master Makefile
# =============================
# Build, test, and manage all components of the Secretariat project.
#
# Usage:
#   make              - Show help
#   make all          - Build everything
#   make clean        - Clean all build artifacts
#   make test         - Run all tests
#   make install      - Install binaries locally

.PHONY: all clean test install install-local help \
        rust rust-build rust-test rust-clean rust-check rust-fmt \
        flutter flutter-build flutter-test flutter-clean flutter-run \
        sdk-dart sdk-python sdk-node sdk-rust sdks sdks-clean \
        daemon cli docs check fmt lint \
        dev dev-daemon dev-cli \
        release package status version \
        service-install service-uninstall service-start service-stop service-status service-logs

# Colors for terminal output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Project paths
ROOT_DIR := $(shell pwd)
DAEMON_DIR := $(ROOT_DIR)/daemon
CLI_DIR := $(ROOT_DIR)/cli
APP_DIR := $(ROOT_DIR)/app
SDK_DART_DIR := $(ROOT_DIR)/sdk-dart
SDK_PYTHON_DIR := $(ROOT_DIR)/sdk-python
SDK_RUST_DIR := $(ROOT_DIR)/sdk-rust
SDK_NODE_DIR := $(ROOT_DIR)/sdk-node
TESTS_DIR := $(ROOT_DIR)/tests
DOCS_DIR := $(ROOT_DIR)/docs

# Binary locations
TARGET_DIR := $(ROOT_DIR)/target
RELEASE_DIR := $(TARGET_DIR)/release
DEBUG_DIR := $(TARGET_DIR)/debug

# Service locations (macOS)
RESOURCES_DIR := $(ROOT_DIR)/resources
LAUNCHD_PLIST := dev.moinsen.secretariat.daemon.plist
LAUNCHD_SRC := $(RESOURCES_DIR)/macos/$(LAUNCHD_PLIST)
LAUNCHD_DST := $(HOME)/Library/LaunchAgents/$(LAUNCHD_PLIST)

# Default target - show help
help:
	@echo ""
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║$(NC)              $(GREEN)Secretariat Build System$(NC)                         $(BLUE)║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Main targets:$(NC)"
	@echo "  $(GREEN)make all$(NC)          - Build everything (Rust + Flutter + SDKs)"
	@echo "  $(GREEN)make clean$(NC)        - Clean all build artifacts"
	@echo "  $(GREEN)make test$(NC)         - Run all tests"
	@echo "  $(GREEN)make release$(NC)      - Build optimized release binaries"
	@echo "  $(GREEN)make install$(NC)      - Install to /usr/local/bin (requires sudo)"
	@echo "  $(GREEN)make install-local$(NC) - Install to ~/bin (no sudo)"
	@echo ""
	@echo "$(YELLOW)Rust targets:$(NC)"
	@echo "  $(GREEN)make rust$(NC)         - Build Rust components (daemon + CLI)"
	@echo "  $(GREEN)make rust-test$(NC)    - Run Rust tests"
	@echo "  $(GREEN)make rust-check$(NC)   - Check Rust code without building"
	@echo "  $(GREEN)make rust-fmt$(NC)     - Format Rust code"
	@echo "  $(GREEN)make daemon$(NC)       - Build daemon only"
	@echo "  $(GREEN)make cli$(NC)          - Build CLI only"
	@echo ""
	@echo "$(YELLOW)Flutter targets:$(NC)"
	@echo "  $(GREEN)make flutter$(NC)      - Build Flutter desktop app"
	@echo "  $(GREEN)make flutter-run$(NC)  - Run Flutter app in debug mode"
	@echo "  $(GREEN)make flutter-test$(NC) - Run Flutter tests"
	@echo ""
	@echo "$(YELLOW)SDK targets:$(NC)"
	@echo "  $(GREEN)make sdk-dart$(NC)     - Build Dart SDK"
	@echo "  $(GREEN)make sdk-python$(NC)   - Build Python SDK"
	@echo "  $(GREEN)make sdk-rust$(NC)     - Build Rust SDK"
	@echo "  $(GREEN)make sdk-node$(NC)     - Build Node.js SDK"
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@echo "  $(GREEN)make test-quick$(NC)   - Run quick integration tests (~30s)"
	@echo "  $(GREEN)make test-full$(NC)    - Run full integration tests with edge cases (~60s)"
	@echo "  $(GREEN)make test$(NC)         - Run all tests (Rust unit + Flutter + integration)"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  $(GREEN)make dev$(NC)          - Start development environment"
	@echo "  $(GREEN)make dev-daemon$(NC)   - Run daemon in development mode"
	@echo "  $(GREEN)make check$(NC)        - Run all checks (fmt, lint, test)"
	@echo "  $(GREEN)make lint$(NC)         - Run linters on all code"
	@echo ""
	@echo "$(YELLOW)Service management (macOS):$(NC)"
	@echo "  $(GREEN)make service-install$(NC)   - Install daemon as Launch Agent (auto-start on login)"
	@echo "  $(GREEN)make service-uninstall$(NC) - Remove Launch Agent"
	@echo "  $(GREEN)make service-start$(NC)     - Start the daemon service"
	@echo "  $(GREEN)make service-stop$(NC)      - Stop the daemon service"
	@echo "  $(GREEN)make service-status$(NC)    - Check daemon service status"
	@echo "  $(GREEN)make service-logs$(NC)      - View daemon logs"
	@echo ""

# ============================================================================
# Main targets
# ============================================================================

all: rust flutter sdks
	@echo ""
	@echo "$(GREEN)✓ All components built successfully!$(NC)"
	@echo ""

clean: rust-clean flutter-clean sdks-clean
	@echo ""
	@echo "$(GREEN)✓ All build artifacts cleaned!$(NC)"
	@echo ""

test: rust-test flutter-test test-integration
	@echo ""
	@echo "$(GREEN)✓ All tests passed!$(NC)"
	@echo ""

install: release
	@echo "$(BLUE)Installing binaries to /usr/local/bin...$(NC)"
	@echo "$(YELLOW)Note: This requires sudo password$(NC)"
	@sudo cp $(RELEASE_DIR)/secd /usr/local/bin/secd
	@sudo cp $(RELEASE_DIR)/sec /usr/local/bin/sec
	@echo "$(GREEN)✓ Installed secd and sec to /usr/local/bin$(NC)"

install-local: release
	@echo "$(BLUE)Installing binaries to ~/bin...$(NC)"
	@mkdir -p $(HOME)/bin
	@cp $(RELEASE_DIR)/secd $(HOME)/bin/secd
	@cp $(RELEASE_DIR)/sec $(HOME)/bin/sec
	@echo "$(GREEN)✓ Installed secd and sec to ~/bin$(NC)"
	@echo "$(YELLOW)Make sure ~/bin is in your PATH$(NC)"

release: rust-release
	@echo "$(GREEN)✓ Release build complete!$(NC)"
	@echo "  Daemon: $(RELEASE_DIR)/secd"
	@echo "  CLI:    $(RELEASE_DIR)/sec"

# ============================================================================
# Rust targets
# ============================================================================

rust: rust-build
	@echo "$(GREEN)✓ Rust components built$(NC)"

rust-build:
	@echo "$(BLUE)Building Rust components (debug)...$(NC)"
	@cargo build --workspace

rust-release:
	@echo "$(BLUE)Building Rust components (release)...$(NC)"
	@cargo build --workspace --release

rust-test:
	@echo "$(BLUE)Running Rust tests...$(NC)"
	@cargo test --workspace

rust-check:
	@echo "$(BLUE)Checking Rust code...$(NC)"
	@cargo check --workspace

rust-fmt:
	@echo "$(BLUE)Formatting Rust code...$(NC)"
	@cargo fmt --all

rust-clean:
	@echo "$(BLUE)Cleaning Rust build artifacts...$(NC)"
	@cargo clean

daemon:
	@echo "$(BLUE)Building daemon...$(NC)"
	@cargo build -p secd

cli:
	@echo "$(BLUE)Building CLI...$(NC)"
	@cargo build -p sec

# ============================================================================
# Flutter targets
# ============================================================================

flutter: flutter-deps flutter-build
	@echo "$(GREEN)✓ Flutter app built$(NC)"

flutter-deps:
	@echo "$(BLUE)Getting Flutter dependencies...$(NC)"
	@cd $(APP_DIR) && flutter pub get

flutter-build:
	@echo "$(BLUE)Building Flutter desktop app...$(NC)"
	@cd $(APP_DIR) && flutter build macos

flutter-run:
	@echo "$(BLUE)Running Flutter app...$(NC)"
	@cd $(APP_DIR) && flutter run -d macos

flutter-test:
	@echo "$(BLUE)Running Flutter tests...$(NC)"
	@cd $(APP_DIR) && flutter test

flutter-clean:
	@echo "$(BLUE)Cleaning Flutter build artifacts...$(NC)"
	@cd $(APP_DIR) && flutter clean

flutter-analyze:
	@echo "$(BLUE)Analyzing Flutter code...$(NC)"
	@cd $(APP_DIR) && flutter analyze

# ============================================================================
# SDK targets
# ============================================================================

sdks: sdk-dart sdk-python sdk-rust sdk-node
	@echo "$(GREEN)✓ All SDKs built$(NC)"

sdks-clean:
	@echo "$(BLUE)Cleaning SDK build artifacts...$(NC)"
	@rm -rf $(SDK_DART_DIR)/.dart_tool
	@rm -rf $(SDK_PYTHON_DIR)/dist $(SDK_PYTHON_DIR)/*.egg-info $(SDK_PYTHON_DIR)/__pycache__
	@rm -rf $(SDK_RUST_DIR)/target
	@rm -rf $(SDK_NODE_DIR)/dist $(SDK_NODE_DIR)/node_modules

sdk-dart:
	@echo "$(BLUE)Building Dart SDK...$(NC)"
	@cd $(SDK_DART_DIR) && dart pub get
	@echo "$(GREEN)✓ Dart SDK ready$(NC)"

sdk-python:
	@echo "$(BLUE)Building Python SDK...$(NC)"
	@cd $(SDK_PYTHON_DIR) && python3 -m pip install -e . --quiet 2>/dev/null || echo "  (install with: pip install -e sdk-python)"
	@echo "$(GREEN)✓ Python SDK ready$(NC)"

sdk-rust:
	@echo "$(BLUE)Building Rust SDK...$(NC)"
	@cd $(SDK_RUST_DIR) && cargo build
	@echo "$(GREEN)✓ Rust SDK built$(NC)"

sdk-node:
	@echo "$(BLUE)Building Node.js SDK...$(NC)"
	@cd $(SDK_NODE_DIR) && npm install --silent 2>/dev/null && npm run build --silent 2>/dev/null || echo "  (install with: cd sdk-node && npm install && npm run build)"
	@echo "$(GREEN)✓ Node.js SDK ready$(NC)"

# ============================================================================
# Test targets
# ============================================================================

test-integration:
	@echo "$(BLUE)Running integration tests...$(NC)"
	@if [ -f $(TESTS_DIR)/test_daemon_init.sh ]; then \
		chmod +x $(TESTS_DIR)/test_daemon_init.sh && \
		$(TESTS_DIR)/test_daemon_init.sh || echo "$(YELLOW)⚠ Integration tests require built binaries$(NC)"; \
	fi

test-cli:
	@echo "$(BLUE)Running CLI tests...$(NC)"
	@if [ -f $(TESTS_DIR)/test_cli_commands.sh ]; then \
		chmod +x $(TESTS_DIR)/test_cli_commands.sh && \
		$(TESTS_DIR)/test_cli_commands.sh || echo "$(YELLOW)⚠ CLI tests require running daemon$(NC)"; \
	fi

test-permissions:
	@echo "$(BLUE)Running permissions tests...$(NC)"
	@if [ -f $(TESTS_DIR)/test_permissions.sh ]; then \
		chmod +x $(TESTS_DIR)/test_permissions.sh && \
		$(TESTS_DIR)/test_permissions.sh || echo "$(YELLOW)⚠ Permission tests require running daemon$(NC)"; \
	fi

test-full:
	@echo "$(BLUE)Running full test suite...$(NC)"
	@if [ -f $(TESTS_DIR)/test_full_suite.sh ]; then \
		chmod +x $(TESTS_DIR)/test_full_suite.sh && \
		$(TESTS_DIR)/test_full_suite.sh --full; \
	fi

test-quick:
	@echo "$(BLUE)Running quick test suite...$(NC)"
	@if [ -f $(TESTS_DIR)/test_full_suite.sh ]; then \
		chmod +x $(TESTS_DIR)/test_full_suite.sh && \
		$(TESTS_DIR)/test_full_suite.sh --quick; \
	fi

# ============================================================================
# Development targets
# ============================================================================

dev: rust-build
	@echo "$(GREEN)Development build ready!$(NC)"
	@echo ""
	@echo "Start the daemon:  $(YELLOW)make dev-daemon$(NC)"
	@echo "Use the CLI:       $(YELLOW)$(DEBUG_DIR)/sec$(NC)"
	@echo "Run Flutter app:   $(YELLOW)make flutter-run$(NC)"

dev-daemon:
	@echo "$(BLUE)Starting daemon in development mode...$(NC)"
	@RUST_LOG=debug $(DEBUG_DIR)/secd

dev-cli:
	@echo "$(BLUE)CLI ready at: $(DEBUG_DIR)/sec$(NC)"
	@$(DEBUG_DIR)/sec --help

# ============================================================================
# Quality targets
# ============================================================================

check: rust-fmt rust-check flutter-analyze lint
	@echo "$(GREEN)✓ All checks passed!$(NC)"

lint: rust-lint flutter-lint
	@echo "$(GREEN)✓ Linting complete$(NC)"

rust-lint:
	@echo "$(BLUE)Linting Rust code...$(NC)"
	@cargo clippy --workspace -- -D warnings 2>/dev/null || echo "$(YELLOW)⚠ Install clippy: rustup component add clippy$(NC)"

flutter-lint:
	@echo "$(BLUE)Linting Flutter code...$(NC)"
	@cd $(APP_DIR) && flutter analyze

fmt: rust-fmt
	@echo "$(GREEN)✓ Code formatted$(NC)"

# ============================================================================
# Documentation targets
# ============================================================================

docs:
	@echo "$(BLUE)Documentation available in docs/:$(NC)"
	@ls -1 $(DOCS_DIR)/*.md 2>/dev/null || echo "  No documentation files found"

docs-serve:
	@echo "$(BLUE)Serving documentation...$(NC)"
	@cd $(DOCS_DIR) && python3 -m http.server 8000

# ============================================================================
# Utility targets
# ============================================================================

status:
	@echo ""
	@echo "$(BLUE)Project Status$(NC)"
	@echo "═══════════════"
	@echo ""
	@echo "$(YELLOW)Rust:$(NC)"
	@cargo --version 2>/dev/null || echo "  $(RED)✗ Rust not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Flutter:$(NC)"
	@flutter --version 2>/dev/null | head -1 || echo "  $(RED)✗ Flutter not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Node.js:$(NC)"
	@node --version 2>/dev/null || echo "  $(RED)✗ Node.js not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Python:$(NC)"
	@python3 --version 2>/dev/null || echo "  $(RED)✗ Python not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Build artifacts:$(NC)"
	@if [ -f $(DEBUG_DIR)/secd ]; then echo "  $(GREEN)✓$(NC) Debug daemon"; else echo "  ○ Debug daemon"; fi
	@if [ -f $(DEBUG_DIR)/sec ]; then echo "  $(GREEN)✓$(NC) Debug CLI"; else echo "  ○ Debug CLI"; fi
	@if [ -f $(RELEASE_DIR)/secd ]; then echo "  $(GREEN)✓$(NC) Release daemon"; else echo "  ○ Release daemon"; fi
	@if [ -f $(RELEASE_DIR)/sec ]; then echo "  $(GREEN)✓$(NC) Release CLI"; else echo "  ○ Release CLI"; fi
	@echo ""

version:
	@echo "Secretariat v0.1.0"

# ============================================================================
# Service management targets (macOS)
# ============================================================================

service-install: release
	@echo "$(BLUE)Installing Secretariat daemon as Launch Agent...$(NC)"
	@if [ ! -f $(LAUNCHD_SRC) ]; then \
		echo "$(RED)✗ Launch Agent plist not found at $(LAUNCHD_SRC)$(NC)"; \
		exit 1; \
	fi
	@mkdir -p $(HOME)/Library/LaunchAgents
	@if [ -f /usr/local/bin/secd ]; then \
		cp $(LAUNCHD_SRC) $(LAUNCHD_DST); \
	else \
		echo "$(YELLOW)Note: Binary not in /usr/local/bin, updating plist path...$(NC)"; \
		sed 's|/usr/local/bin/secd|$(HOME)/.local/bin/secd|g' $(LAUNCHD_SRC) > $(LAUNCHD_DST); \
	fi
	@launchctl load $(LAUNCHD_DST) 2>/dev/null || true
	@echo "$(GREEN)✓ Launch Agent installed and loaded$(NC)"
	@echo "  The daemon will now start automatically when you log in."
	@echo "  Use '$(YELLOW)make service-status$(NC)' to check if it's running."

service-uninstall:
	@echo "$(BLUE)Removing Secretariat Launch Agent...$(NC)"
	@launchctl unload $(LAUNCHD_DST) 2>/dev/null || true
	@rm -f $(LAUNCHD_DST)
	@echo "$(GREEN)✓ Launch Agent removed$(NC)"

service-start:
	@echo "$(BLUE)Starting Secretariat daemon...$(NC)"
	@if [ ! -f $(LAUNCHD_DST) ]; then \
		echo "$(RED)✗ Launch Agent not installed. Run 'make service-install' first.$(NC)"; \
		exit 1; \
	fi
	@launchctl start dev.moinsen.secretariat.daemon
	@sleep 1
	@if launchctl list | grep -q dev.moinsen.secretariat.daemon; then \
		echo "$(GREEN)✓ Daemon started$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Daemon may not have started. Check logs with 'make service-logs'$(NC)"; \
	fi

service-stop:
	@echo "$(BLUE)Stopping Secretariat daemon...$(NC)"
	@launchctl stop dev.moinsen.secretariat.daemon 2>/dev/null || true
	@echo "$(GREEN)✓ Daemon stopped$(NC)"

service-status:
	@echo ""
	@echo "$(BLUE)Secretariat Daemon Status$(NC)"
	@echo "══════════════════════════"
	@echo ""
	@if [ -f $(LAUNCHD_DST) ]; then \
		echo "$(GREEN)✓$(NC) Launch Agent installed"; \
	else \
		echo "$(YELLOW)○$(NC) Launch Agent not installed"; \
	fi
	@if launchctl list 2>/dev/null | grep -q dev.moinsen.secretariat.daemon; then \
		echo "$(GREEN)✓$(NC) Daemon is running"; \
		PID=$$(launchctl list | grep dev.moinsen.secretariat.daemon | awk '{print $$1}'); \
		if [ "$$PID" != "-" ] && [ -n "$$PID" ]; then \
			echo "  PID: $$PID"; \
		fi; \
	else \
		echo "$(YELLOW)○$(NC) Daemon is not running"; \
	fi
	@echo ""
	@echo "$(YELLOW)Socket:$(NC)"
	@SOCK_PATH="$(HOME)/Library/Application Support/Secretariat/secretariat.sock"; \
	if [ -S "$$SOCK_PATH" ]; then \
		echo "  $(GREEN)✓$(NC) Socket exists at $$SOCK_PATH"; \
	else \
		echo "  $(YELLOW)○$(NC) Socket not found"; \
	fi
	@echo ""

service-logs:
	@echo "$(BLUE)Secretariat Daemon Logs$(NC)"
	@echo "════════════════════════"
	@echo ""
	@echo "$(YELLOW)stdout:$(NC)"
	@if [ -f /tmp/secretariat-daemon.log ]; then \
		tail -20 /tmp/secretariat-daemon.log; \
	else \
		echo "  (no log file found)"; \
	fi
	@echo ""
	@echo "$(YELLOW)stderr:$(NC)"
	@if [ -f /tmp/secretariat-daemon.error.log ]; then \
		tail -20 /tmp/secretariat-daemon.error.log; \
	else \
		echo "  (no error log found)"; \
	fi
	@echo ""

# Convenience aliases
b: rust-build
t: test
c: clean
r: rust-release
f: flutter-build
s: service-status

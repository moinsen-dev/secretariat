# Local Secrets Orchestrator

## Project Overview

This project is a secrets management system with:
- **Rust daemon** (`daemon/`) - Backend service for secure secret storage using macOS Security Framework
- **Flutter app** (`app/`) - Desktop UI for managing secrets with biometric authentication

## Quick Commands

```bash
# Rust daemon
cd daemon && cargo build
cd daemon && cargo test

# Flutter app
cd app && flutter analyze
cd app && flutter test
```

<!-- BEGIN PREFERENCES -->
## Architecture Preferences (Auto-synced)

> Source: ~/.conductor/preferences.yaml
> Synced: 2026-01-01

### Enforcement Mode: **Strict**

Violations block execution and require explicit override with ADR documentation.

### Tool Choices

| Purpose | Use | Avoid | Severity |
|---------|-----|-------|----------|
| **Python Package Manager** | `uv` | pip, poetry, pipenv, conda | error |
| **JS Package Manager** | `pnpm` | npm, yarn, bun | error |
| **Dart Package Manager** | `pub` | - | info |
| **Rust Package Manager** | `cargo` | - | info |
| **Python Linter** | `ruff` | pylint, flake8, pyflakes, bandit | error |
| **JS Linter** | `eslint` | jslint, jshint | warning |
| **Dart Linter** | `dart_analyze` | - | info |
| **Python Formatter** | `ruff format` | black, autopep8, yapf | error |
| **JS Formatter** | `prettier` | - | warning |
| **Dart Formatter** | `dart_format` | - | info |
| **Python Type Checker** | `mypy` (strict) | pyright, pyre | error |
| **TS Type Checker** | `tsc` | - | info |
| **Python Unit Tests** | `pytest` | unittest, nose, doctest | error |
| **Python E2E Tests** | `playwright` | selenium, cypress | warning |
| **JS Unit Tests** | `vitest` | jest, mocha, jasmine | warning |
| **Dart Unit Tests** | `flutter_test` | - | info |
| **Dart E2E Tests** | `maestro` | appium | warning |

### Framework Choices

| Purpose | Use | Avoid | Severity |
|---------|-----|-------|----------|
| **Python API** | FastAPI | Flask, Django REST, Falcon, Bottle, Tornado | error |
| **Python CLI** | Click | argparse, typer, fire | error |
| **Python Terminal UI** | Rich | colorama, curses, blessed, termcolor | error |
| **Python Validation** | Pydantic v2 | marshmallow, cerberus, voluptuous | error |
| **JS Frontend** | Next.js | create-react-app, Gatsby | warning |
| **JS State** | Zustand | Redux, MobX, Recoil | warning |
| **JS UI Components** | shadcn/ui | Material UI, Chakra UI, Ant Design | warning |
| **JS Styling** | Tailwind CSS | styled-components, Emotion, CSS Modules | warning |
| **Mobile** | Flutter | React Native, Ionic, Xamarin | warning |
| **Flutter State** | Bloc | Provider (alone), Riverpod, GetX, MobX, freezed | error |
| **Desktop** | Tauri | Electron, NW.js | warning |
| **Python ORM** | SQLAlchemy | Peewee, TortoiseORM, SQLModel | error |
| **TS ORM** | Prisma | TypeORM, Sequelize, Knex | warning |
| **Dart ORM** | Drift | Floor, sqflite (raw) | warning |

### Database Choices

| Purpose | Use | Avoid | Severity |
|---------|-----|-------|----------|
| **Production SQL** | PostgreSQL 16+ | MySQL, MariaDB | warning |
| **Local/Embedded** | SQLite | - | info |
| **Document Store** | MongoDB | CouchDB | warning |
| **Cache** | Redis | Memcached | warning |
| **Search** | Elasticsearch | - | warning |

### Architecture Patterns

**Preferred:**
- Clean Architecture (API, mobile, web)
- Hexagonal Architecture (complex backend)
- Domain Driven Design (enterprise, complex domains)

**Avoid:**
- Big Ball of Mud
- God Objects
- Anemic Domain Model

### SOLID Principles

| Principle | Enforced | Notes |
|-----------|----------|-------|
| DRY | Yes | Min 3 occurrences before abstraction |
| KISS | Yes | Simple solutions over complex |
| YAGNI | Yes | Don't build what you don't need |

### Quality Gates

| Stage | Checks |
|-------|--------|
| Pre-commit | lint, format_check, type_check |
| Pre-push | unit_tests, integration_tests |
| CI | all_tests, coverage (80%+), security_scan, preference_compliance |

### Cloud & Deployment

| Purpose | Use | Avoid |
|---------|-----|-------|
| Frontend | Vercel | Heroku |
| Backend | Railway | Heroku |
| Global Distribution | Fly.io | - |
| Containers | Docker + docker-compose | Kubernetes (local) |

### Project Overrides

No project-specific overrides configured. To add overrides, create files in `.conductor/preference-overrides/`.

### Enforcement

- **Mode**: Strict (violations block finalization)
- **Overrides**: Allowed with ADR documentation
- **Check Points**: code_generation, code_review, quality_gates, ci_pipeline
<!-- END PREFERENCES -->

## Development Notes

- macOS is the primary platform with full feature support including Touch ID biometric authentication
- The daemon uses Unix socket communication at `/tmp/secrets_daemon.sock`
- Master keys are stored in macOS Keychain with LAContext biometric protection

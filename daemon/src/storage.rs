//! Storage layer for Secretariat daemon
//!
//! Handles SQLite database with SQLCipher encryption for secure secret storage.
//! Implements the secrets table with support for encrypted values, provider detection,
//! and environment management.

use anyhow::{Context, Result};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// Metadata for a secret (without encrypted value)
///
/// This structure contains all the non-sensitive information about a secret
/// that can be safely returned to clients for display purposes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecretMetadata {
    /// Unique identifier for the secret
    pub id: String,
    /// Secret name/key (e.g., "OPENAI_API_KEY")
    pub name: String,
    /// Auto-detected provider (e.g., "openai", "stripe")
    pub provider: Option<String>,
    /// Environment context (e.g., "default", "dev", "staging", "prod")
    pub environment: String,
    /// Timestamp when the secret was created
    pub created_at: String,
}

/// Metadata for a secret with version information
///
/// Extended metadata structure that includes versioning information
/// for secret rotation support.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecretMetadataWithVersion {
    /// Unique identifier for the secret
    pub id: String,
    /// Secret name/key (e.g., "OPENAI_API_KEY")
    pub name: String,
    /// Auto-detected provider (e.g., "openai", "stripe")
    pub provider: Option<String>,
    /// Environment context (e.g., "default", "dev", "staging", "prod")
    pub environment: String,
    /// Timestamp when the secret was created
    pub created_at: String,
    /// Current version number (starts at 1, increments on rotation)
    pub version: Option<i64>,
    /// Whether a previous version exists (for rollback)
    pub has_previous: bool,
}

/// Full secret record including encrypted value
///
/// This structure contains the complete secret data including the encrypted value.
/// Used internally for retrieval operations.
///
/// ## Wave 12 Features:
/// - F060: Secret structure for get_secret_by_name() method
#[derive(Debug, Clone)]
#[allow(dead_code)] // Fields populated from database query, used for complete record representation
pub struct Secret {
    /// Unique identifier for the secret
    pub id: String,
    /// Secret name/key (e.g., "OPENAI_API_KEY")
    pub name: String,
    /// Encrypted secret value (binary blob)
    pub value_encrypted: Vec<u8>,
    /// Auto-detected provider (e.g., "openai", "stripe")
    pub provider: Option<String>,
    /// Environment context (e.g., "default", "dev", "staging", "prod")
    pub environment: String,
    /// Timestamp when the secret was created
    pub created_at: String,
}

/// Application information
///
/// Contains details about a registered application including process info
/// and stable fingerprint for identity verification.
///
/// ## Wave 14 Features:
/// - F072-F075: AppInfo structure for app registration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppInfo {
    /// Process ID of the application
    pub pid: u32,
    /// Display name (extracted from executable path)
    pub name: String,
    /// Full path to the executable
    pub path: String,
    /// macOS bundle identifier (if applicable)
    pub bundle_id: Option<String>,
    /// Stable fingerprint (SHA-256 hash of path + bundle_id)
    pub fingerprint: String,
}

/// Application record from database
///
/// Contains all application information including permissions count.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApplicationRecord {
    /// Unique identifier
    pub id: String,
    /// Display name
    pub name: String,
    /// Path to executable
    pub path: Option<String>,
    /// macOS bundle identifier
    pub bundle_id: Option<String>,
    /// Stable fingerprint
    pub fingerprint: Option<String>,
    /// When the application was registered
    pub registered_at: String,
    /// When the application last accessed a secret
    pub last_access: Option<String>,
    /// Number of secrets the application has access to
    pub permission_count: i64,
}

/// Storage backend for managing secrets in an encrypted SQLite database
pub struct Storage {
    conn: Connection,
    db_path: PathBuf,
}

impl Storage {
    /// Initialize the storage layer (legacy - with SQLCipher encryption)
    ///
    /// Creates or opens the SQLite database at the specified path and sets up
    /// the schema including the secrets table.
    ///
    /// # Arguments
    /// * `db_path` - Path to the SQLite database file
    /// * `encryption_key` - SQLCipher encryption key (will be used for database encryption)
    ///
    /// # Errors
    /// Returns an error if:
    /// - Database file cannot be created/opened
    /// - Schema creation fails
    /// - Encryption key is invalid
    #[allow(dead_code)] // Kept for backwards compatibility
    pub fn new<P: AsRef<Path>>(db_path: P, encryption_key: &str) -> Result<Self> {
        let conn = Connection::open(db_path.as_ref())
            .context("Failed to open database connection")?;

        // Set up SQLCipher encryption
        // This must be done immediately after opening the connection
        conn.pragma_update(None, "key", encryption_key)
            .context("Failed to set encryption key")?;

        // Use modern cipher (AES-256)
        conn.pragma_update(None, "cipher_page_size", "4096")
            .context("Failed to set cipher page size")?;

        let mut storage = Storage {
            conn,
            db_path: db_path.as_ref().to_path_buf(),
        };
        storage.initialize_schema()?;

        Ok(storage)
    }

    /// Initialize the storage layer without SQLCipher encryption
    ///
    /// Creates or opens the SQLite database at the specified path.
    /// Individual secrets are encrypted at the application level using AES-256-GCM
    /// with keys derived from the user's master password via Argon2.
    ///
    /// # Arguments
    /// * `db_path` - Path to the SQLite database file
    ///
    /// # Errors
    /// Returns an error if:
    /// - Database file cannot be created/opened
    /// - Schema creation fails
    pub fn new_without_key<P: AsRef<Path>>(db_path: P) -> Result<Self> {
        let conn = Connection::open(db_path.as_ref())
            .context("Failed to open database connection")?;

        // Set WAL mode for better concurrency
        conn.pragma_update(None, "journal_mode", "WAL")
            .context("Failed to set WAL mode")?;

        let mut storage = Storage {
            conn,
            db_path: db_path.as_ref().to_path_buf(),
        };
        storage.initialize_schema()?;

        Ok(storage)
    }

    /// Get the path to the database file
    pub fn path(&self) -> &Path {
        &self.db_path
    }

    /// Initialize the database schema
    ///
    /// Creates all necessary tables if they don't exist.
    /// Features implemented:
    /// - F001: id TEXT PRIMARY KEY column
    /// - F002: name TEXT UNIQUE NOT NULL column
    /// - F003: value_encrypted BLOB NOT NULL column for AES-GCM ciphertext
    /// - F004: provider TEXT column for auto-detected provider
    /// - F005: environment TEXT DEFAULT 'default' column
    /// - F011: Applications table with id, name, path, bundle_id, fingerprint columns
    /// - F012: Permissions table with app_id, secret_id, granted_at columns
    /// - F013: UNIQUE(app_id, secret_id) constraint on permissions table
    /// - F014: Audit log table with id, timestamp, app_id, secret_name, action, success columns
    /// - F015: Index idx_audit_log_timestamp on audit_log(timestamp DESC)
    fn initialize_schema(&mut self) -> Result<()> {
        self.conn.execute_batch(
            r#"
            -- F001, F002, F003, F004, F005: Core secrets table
            CREATE TABLE IF NOT EXISTS secrets (
                id TEXT PRIMARY KEY,                    -- F001: Unique identifier (UUID)
                name TEXT UNIQUE NOT NULL,              -- F002: Secret name/key (e.g., "OPENAI_API_KEY")
                value_encrypted BLOB NOT NULL,          -- F003: AES-256-GCM encrypted secret value
                provider TEXT,                          -- F004: Auto-detected provider (e.g., "openai", "stripe")
                environment TEXT DEFAULT 'default',     -- F005: Environment context (default, dev, staging, prod)
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                rotated_at TIMESTAMP,                   -- Last rotation timestamp
                expires_at TIMESTAMP,                   -- Ephemeral secret expiration (NULL = permanent)
                notes TEXT,                             -- Optional user notes
                version INTEGER DEFAULT 1,              -- Version number for rotation tracking
                previous_value_encrypted BLOB           -- Previous encrypted value for rollback
            );

            -- Index for fast lookups by name (most common query pattern)
            CREATE INDEX IF NOT EXISTS idx_secrets_name ON secrets(name);

            -- Index for filtering by provider
            CREATE INDEX IF NOT EXISTS idx_secrets_provider ON secrets(provider);

            -- Index for filtering by environment
            CREATE INDEX IF NOT EXISTS idx_secrets_environment ON secrets(environment);

            -- Index for ephemeral secret cleanup (find expired secrets)
            CREATE INDEX IF NOT EXISTS idx_secrets_expires_at ON secrets(expires_at)
                WHERE expires_at IS NOT NULL;

            -- Trigger to update updated_at timestamp automatically
            CREATE TRIGGER IF NOT EXISTS update_secrets_timestamp
            AFTER UPDATE ON secrets
            FOR EACH ROW
            BEGIN
                UPDATE secrets SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
            END;

            -- F011: Applications table for registered applications
            CREATE TABLE IF NOT EXISTS applications (
                id TEXT PRIMARY KEY,                    -- Unique identifier (UUID)
                name TEXT NOT NULL,                     -- Application display name
                path TEXT,                              -- File system path to executable
                bundle_id TEXT,                         -- macOS bundle identifier or similar
                fingerprint TEXT,                       -- Stable identifier for app verification
                registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_access TIMESTAMP                   -- Last time app accessed any secret
            );

            -- Index for fast lookups by bundle_id
            CREATE INDEX IF NOT EXISTS idx_applications_bundle_id ON applications(bundle_id);

            -- Index for fast lookups by fingerprint
            CREATE INDEX IF NOT EXISTS idx_applications_fingerprint ON applications(fingerprint);

            -- F012, F013: Permissions table for app-to-secret authorization
            CREATE TABLE IF NOT EXISTS permissions (
                id TEXT PRIMARY KEY,                    -- Unique identifier (UUID)
                app_id TEXT REFERENCES applications(id), -- F012: Foreign key to applications
                secret_id TEXT REFERENCES secrets(id),  -- F012: Foreign key to secrets
                granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- F012: When permission was granted
                granted_by TEXT,                        -- 'user' or 'auto' - how permission was granted
                UNIQUE(app_id, secret_id)              -- F013: One permission per app-secret pair
            );

            -- Index for fast lookups by app_id (common query: "what secrets can this app access?")
            CREATE INDEX IF NOT EXISTS idx_permissions_app_id ON permissions(app_id);

            -- Index for fast lookups by secret_id (common query: "which apps have access to this secret?")
            CREATE INDEX IF NOT EXISTS idx_permissions_secret_id ON permissions(secret_id);

            -- F014: Audit log table for tracking all secret access
            CREATE TABLE IF NOT EXISTS audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,   -- F014: Auto-incrementing ID
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- F014: When action occurred
                app_id TEXT,                            -- F014: Which application (can be NULL for CLI)
                secret_name TEXT,                       -- F014: Which secret was accessed
                action TEXT,                            -- F014: 'read', 'write', 'delete', 'grant', 'revoke'
                success BOOLEAN,                        -- F014: Whether action succeeded
                details TEXT                            -- Additional context (error messages, etc.)
            );

            -- F015: Index for efficient time-based queries (most recent first)
            CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp DESC);

            -- Additional index for filtering by app_id
            CREATE INDEX IF NOT EXISTS idx_audit_log_app_id ON audit_log(app_id);

            -- Additional index for filtering by action type
            CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);

            -- Vault metadata table for storing configuration like salt
            -- Used for password-based key derivation and vault state
            CREATE TABLE IF NOT EXISTS vault_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            -- Trigger to update updated_at timestamp on vault_metadata
            CREATE TRIGGER IF NOT EXISTS update_vault_metadata_timestamp
            AFTER UPDATE ON vault_metadata
            FOR EACH ROW
            BEGIN
                UPDATE vault_metadata SET updated_at = CURRENT_TIMESTAMP WHERE key = NEW.key;
            END;

            -- AI Agents table for registered AI coding assistants
            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE,
                agent_type TEXT NOT NULL DEFAULT 'ai-assistant',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_access TIMESTAMP
            );

            -- Index for fast lookups by name
            CREATE INDEX IF NOT EXISTS idx_agents_name ON agents(name);

            -- Agent permissions table for per-agent secret access control
            CREATE TABLE IF NOT EXISTS agent_permissions (
                id TEXT PRIMARY KEY,
                agent_id TEXT NOT NULL,
                secret_name TEXT NOT NULL,
                environment TEXT DEFAULT 'default',
                granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(agent_id, secret_name, environment),
                FOREIGN KEY (agent_id) REFERENCES agents(id)
            );

            -- Index for fast lookups by agent_id
            CREATE INDEX IF NOT EXISTS idx_agent_permissions_agent_id ON agent_permissions(agent_id);

            -- Index for fast lookups by secret_name
            CREATE INDEX IF NOT EXISTS idx_agent_permissions_secret_name ON agent_permissions(secret_name);
            "#,
        )
        .context("Failed to initialize database schema")?;

        Ok(())
    }

    /// Get a reference to the underlying database connection
    ///
    /// Useful for executing custom queries or transactions
    #[allow(dead_code)] // Used in tests and available for future custom queries
    pub fn connection(&self) -> &Connection {
        &self.conn
    }

    /// Verify database connectivity and schema
    ///
    /// Performs a simple query to ensure the database is accessible
    /// and the schema is properly initialized.
    pub fn health_check(&self) -> Result<()> {
        let count: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM secrets", [], |row| row.get(0))
            .context("Failed to query secrets table")?;

        tracing::debug!("Health check passed: {} secrets in database", count);
        Ok(())
    }

    // ==========================================================================
    // Vault Metadata Methods
    // ==========================================================================

    /// Set a vault metadata value
    ///
    /// Stores a key-value pair in the vault_metadata table.
    /// If the key already exists, its value is updated.
    ///
    /// # Arguments
    ///
    /// * `key` - The metadata key (e.g., "salt")
    /// * `value` - The metadata value
    pub fn set_vault_metadata(&self, key: &str, value: &str) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO vault_metadata (key, value) VALUES (?, ?)",
            [key, value],
        )
        .context("Failed to set vault metadata")?;

        Ok(())
    }

    /// Get a vault metadata value
    ///
    /// Retrieves a value from the vault_metadata table by key.
    ///
    /// # Arguments
    ///
    /// * `key` - The metadata key to look up
    ///
    /// # Returns
    ///
    /// `Some(value)` if the key exists, `None` otherwise
    #[allow(dead_code)] // Used for vault.unlock (to be implemented)
    pub fn get_vault_metadata(&self, key: &str) -> Result<Option<String>> {
        let result = self.conn.query_row(
            "SELECT value FROM vault_metadata WHERE key = ?",
            [key],
            |row| row.get(0),
        );

        match result {
            Ok(value) => Ok(Some(value)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e).context("Failed to get vault metadata"),
        }
    }

    /// Check if the vault is initialized
    ///
    /// A vault is considered initialized if a salt has been stored.
    #[allow(dead_code)] // Used for vault state checks (to be implemented)
    pub fn is_vault_initialized(&self) -> Result<bool> {
        Ok(self.get_vault_metadata("salt")?.is_some())
    }

    /// Check if any secrets exist in the vault
    pub fn has_secrets(&self) -> Result<bool> {
        let count: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM secrets", [], |row| row.get(0))
            .context("Failed to count secrets")?;
        Ok(count > 0)
    }

    /// List all secrets with encrypted values (for migration/re-encryption)
    ///
    /// Returns all secrets including their encrypted values.
    /// This is used internally for vault re-initialization.
    ///
    /// # Security Note
    ///
    /// This method returns encrypted values and should only be used
    /// for internal operations like key migration.
    pub fn list_secrets_raw(&self) -> Result<Vec<Secret>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, value_encrypted, provider, environment, created_at FROM secrets"
        )?;

        let secrets = stmt.query_map([], |row| {
            Ok(Secret {
                id: row.get(0)?,
                name: row.get(1)?,
                value_encrypted: row.get(2)?,
                provider: row.get(3)?,
                environment: row.get(4)?,
                created_at: row.get(5)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(secrets)
    }

    /// Update only the encrypted value of a secret
    ///
    /// Used for re-encryption during vault re-initialization.
    ///
    /// # Arguments
    ///
    /// * `id` - The secret's unique identifier
    /// * `encrypted_value` - The new encrypted value (nonce + ciphertext)
    pub fn update_secret_encrypted(&self, id: &str, encrypted_value: &[u8]) -> Result<()> {
        let rows_affected = self.conn.execute(
            "UPDATE secrets SET value_encrypted = ? WHERE id = ?",
            rusqlite::params![encrypted_value, id],
        )
        .context("Failed to update secret encrypted value")?;

        if rows_affected == 0 {
            anyhow::bail!("Secret not found: {}", id);
        }

        Ok(())
    }

    // ==========================================================================
    // Database Statistics
    // ==========================================================================

    /// Get database statistics
    ///
    /// Returns useful information about the database state
    pub fn stats(&self) -> Result<DatabaseStats> {
        let total_secrets: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM secrets", [], |row| row.get(0))?;

        let with_provider: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM secrets WHERE provider IS NOT NULL", [], |row| row.get(0))?;

        let environments: Vec<String> = {
            let mut stmt = self.conn
                .prepare("SELECT DISTINCT environment FROM secrets ORDER BY environment")?;
            let rows = stmt.query_map([], |row| row.get(0))?;
            rows.collect::<Result<Vec<String>, _>>()?
        };

        // Wave 3 statistics
        let total_applications: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM applications", [], |row| row.get(0))?;

        let total_permissions: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM permissions", [], |row| row.get(0))?;

        let total_audit_entries: i64 = self.conn
            .query_row("SELECT COUNT(*) FROM audit_log", [], |row| row.get(0))?;

        Ok(DatabaseStats {
            total_secrets,
            with_provider,
            environments,
            total_applications,
            total_permissions,
            total_audit_entries,
        })
    }

    /// List all secrets (metadata only, no encrypted values)
    ///
    /// Returns a list of all secrets with their metadata (id, name, provider, environment, created_at).
    /// Does NOT return encrypted values for security.
    ///
    /// # Returns
    ///
    /// A vector of `SecretMetadata` containing all non-sensitive secret information
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Database query fails
    /// - Data cannot be parsed
    ///
    /// # Features
    ///
    /// - F054: Queries only id, name, provider, environment, created_at columns
    /// - F055: Returns metadata without encrypted values
    pub fn list_secrets(&self) -> Result<Vec<SecretMetadata>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, provider, environment, created_at FROM secrets ORDER BY name"
        )?;

        let secrets = stmt.query_map([], |row| {
            Ok(SecretMetadata {
                id: row.get(0)?,
                name: row.get(1)?,
                provider: row.get(2)?,
                environment: row.get(3)?,
                created_at: row.get(4)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(secrets)
    }

    /// Get a secret by name (including encrypted value)
    ///
    /// Looks up a secret by its name and returns the full record including
    /// the encrypted value blob.
    ///
    /// # Arguments
    ///
    /// * `name` - The name of the secret to retrieve
    ///
    /// # Returns
    ///
    /// A `Secret` containing all fields including the encrypted value
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The secret does not exist
    /// - Database query fails
    /// - Data cannot be parsed
    ///
    /// # Features
    ///
    /// - F060: Implements get_secret_by_name() method for secret retrieval
    ///
    /// # Security Note
    ///
    /// This method returns the encrypted value blob. The caller is responsible
    /// for proper authorization checks before using this method.
    pub fn get_secret_by_name(&self, name: &str) -> Result<Secret> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, value_encrypted, provider, environment, created_at FROM secrets WHERE name = ?"
        )?;

        let secret = stmt.query_row([name], |row| {
            Ok(Secret {
                id: row.get(0)?,
                name: row.get(1)?,
                value_encrypted: row.get(2)?,
                provider: row.get(3)?,
                environment: row.get(4)?,
                created_at: row.get(5)?,
            })
        })
        .context(format!("Secret not found: {}", name))?;

        Ok(secret)
    }

    /// Check if an app has permission to access a secret
    ///
    /// Queries the permissions table to determine if the given app_id
    /// has been granted access to the specified secret_id.
    ///
    /// # Arguments
    ///
    /// * `app_id` - The identifier of the application requesting access
    /// * `secret_id` - The unique identifier of the secret
    ///
    /// # Returns
    ///
    /// `true` if the app has permission, `false` otherwise
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails
    ///
    /// # Features
    ///
    /// - F058: Implements check_permission() method to verify app authorization
    ///
    /// # Security Note
    ///
    /// This method enforces the authorization model by checking the permissions
    /// table for a matching (app_id, secret_id) pair.
    pub fn check_permission(&self, app_id: &str, secret_id: &str) -> Result<bool> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM permissions WHERE app_id = ? AND secret_id = ?",
            [app_id, secret_id],
            |row| row.get(0)
        )
        .context("Failed to check permissions")?;

        Ok(count > 0)
    }

    /// F062: Log an access attempt to the audit log
    ///
    /// Records all secret access attempts (both successful and failed) to the
    /// audit_log table for security tracking and compliance.
    ///
    /// # Arguments
    ///
    /// * `app_id` - The identifier of the application making the request
    /// * `secret_name` - The name of the secret being accessed
    /// * `action` - The action being performed (e.g., "read", "write", "delete")
    /// * `success` - Whether the action succeeded
    /// * `details` - Optional additional details (e.g., error message)
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if the database insert fails
    ///
    /// # Features
    ///
    /// - F062: Implements log_audit() method for access logging
    ///
    /// # Security
    ///
    /// This method creates an audit trail of all secret access, which is
    /// critical for:
    /// - Detecting unauthorized access attempts
    /// - Compliance requirements
    /// - Debugging access issues
    /// - Security incident investigation
    pub fn log_audit(&self, app_id: &str, secret_name: &str, action: &str, success: bool, details: Option<&str>) -> Result<()> {
        self.conn.execute(
            "INSERT INTO audit_log (app_id, secret_name, action, success, details) VALUES (?, ?, ?, ?, ?)",
            rusqlite::params![app_id, secret_name, action, success, details]
        )
        .context("Failed to log audit entry")?;

        Ok(())
    }

    /// F064: Create a new secret or update an existing one
    ///
    /// Stores an encrypted secret value in the database. If a secret with the
    /// same name already exists, it is updated. Otherwise, a new secret is created.
    ///
    /// # Arguments
    ///
    /// * `name` - The name of the secret (e.g., "OPENAI_API_KEY")
    /// * `value_encrypted` - The encrypted secret value (nonce + ciphertext concatenated)
    /// * `provider` - Optional provider name (e.g., "openai", "stripe")
    /// * `environment` - Environment context (defaults to "default")
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Database insert/update fails
    /// - UUID generation fails
    ///
    /// # Features
    ///
    /// - F064: Implements create_secret() method for secret storage
    /// - F066: Handles both INSERT (create) and UPDATE (update) operations
    /// - F067: Updated_at timestamp is set via UPDATE query and trigger
    ///
    /// # Implementation Note
    ///
    /// Checks if secret exists, then uses INSERT or UPDATE accordingly.
    /// The UPDATE query explicitly sets updated_at to CURRENT_TIMESTAMP.
    /// A database trigger also ensures updated_at is refreshed on any UPDATE.
    /// Generates a new UUID for the secret ID on creation.
    pub fn create_secret(&self, name: &str, value_encrypted: &[u8], provider: Option<&str>, environment: &str) -> Result<()> {
        // Generate UUID for the secret
        let id = uuid::Uuid::new_v4().to_string();

        // Check if secret already exists
        let exists: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM secrets WHERE name = ?",
            [name],
            |row| row.get(0)
        )?;

        if exists > 0 {
            // Update existing secret
            self.conn.execute(
                "UPDATE secrets SET value_encrypted = ?, provider = ?, environment = ?, updated_at = CURRENT_TIMESTAMP WHERE name = ?",
                rusqlite::params![value_encrypted, provider, environment, name]
            )
            .context("Failed to update secret")?;
        } else {
            // Insert new secret
            self.conn.execute(
                "INSERT INTO secrets (id, name, value_encrypted, provider, environment) VALUES (?, ?, ?, ?, ?)",
                rusqlite::params![id, name, value_encrypted, provider, environment]
            )
            .context("Failed to insert secret")?;
        }

        Ok(())
    }

    /// F069, F070: Delete a secret by name (cascade to permissions)
    ///
    /// Removes a secret from the database along with all associated permissions.
    /// This ensures referential integrity and prevents orphaned permission records.
    ///
    /// # Arguments
    ///
    /// * `name` - The name of the secret to delete
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The secret does not exist
    /// - Database deletion fails
    ///
    /// # Features
    ///
    /// - F069: Implements delete_secret() method
    /// - F070: Cascades delete to permissions table
    ///
    /// # Implementation
    ///
    /// Uses a transaction to ensure atomicity:
    /// 1. Look up secret ID by name
    /// 2. Delete all permissions referencing this secret_id
    /// 3. Delete the secret itself
    pub fn delete_secret(&self, name: &str) -> Result<()> {
        // First, get the secret ID
        let secret_id: String = self.conn.query_row(
            "SELECT id FROM secrets WHERE name = ?",
            [name],
            |row| row.get(0)
        )
        .context(format!("Secret not found: {}", name))?;

        // F070: Delete associated permissions (cascade delete)
        self.conn.execute(
            "DELETE FROM permissions WHERE secret_id = ?",
            [&secret_id]
        )
        .context("Failed to delete permissions")?;

        // Delete the secret itself
        let affected = self.conn.execute(
            "DELETE FROM secrets WHERE id = ?",
            [&secret_id]
        )
        .context("Failed to delete secret")?;

        if affected == 0 {
            anyhow::bail!("Secret not found: {}", name);
        }

        Ok(())
    }

    /// F072-F075: Register an application in the database
    ///
    /// Stores application information including process details and fingerprint
    /// for future permission management and authentication.
    ///
    /// # Arguments
    ///
    /// * `app_info` - Application information to store
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Database insert fails
    /// - UUID generation fails
    ///
    /// # Features
    ///
    /// - F072-F075: Stores application registration data
    ///
    /// # Implementation
    ///
    /// Uses INSERT OR REPLACE to handle re-registration of the same application.
    /// The fingerprint serves as a stable identifier across runs.
    pub fn register_application(&self, app_info: &AppInfo) -> Result<()> {
        // Generate UUID for the application
        let id = uuid::Uuid::new_v4().to_string();

        // Check if app with this fingerprint already exists
        let exists: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM applications WHERE fingerprint = ?",
            [&app_info.fingerprint],
            |row| row.get(0)
        )?;

        if exists > 0 {
            // Update existing application (update last_access time)
            self.conn.execute(
                "UPDATE applications SET name = ?, path = ?, bundle_id = ?, last_access = CURRENT_TIMESTAMP WHERE fingerprint = ?",
                rusqlite::params![&app_info.name, &app_info.path, &app_info.bundle_id, &app_info.fingerprint]
            )
            .context("Failed to update application")?;
        } else {
            // Insert new application
            self.conn.execute(
                "INSERT INTO applications (id, name, path, bundle_id, fingerprint) VALUES (?, ?, ?, ?, ?)",
                rusqlite::params![id, &app_info.name, &app_info.path, &app_info.bundle_id, &app_info.fingerprint]
            )
            .context("Failed to insert application")?;
        }

        Ok(())
    }

    /// List all registered applications
    ///
    /// Returns a list of all applications that have been registered,
    /// along with their permissions count.
    ///
    /// # Returns
    ///
    /// A vector of `ApplicationRecord` containing application details
    pub fn list_applications(&self) -> Result<Vec<ApplicationRecord>> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT
                a.id,
                a.name,
                a.path,
                a.bundle_id,
                a.fingerprint,
                a.registered_at,
                a.last_access,
                (SELECT COUNT(*) FROM permissions WHERE app_id = a.id) as permission_count
            FROM applications a
            ORDER BY a.name
            "#
        )?;

        let apps = stmt.query_map([], |row| {
            Ok(ApplicationRecord {
                id: row.get(0)?,
                name: row.get(1)?,
                path: row.get(2)?,
                bundle_id: row.get(3)?,
                fingerprint: row.get(4)?,
                registered_at: row.get(5)?,
                last_access: row.get(6)?,
                permission_count: row.get(7)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(apps)
    }

    /// Revoke permission for an app to access a secret
    ///
    /// Removes the permission record linking an application to a secret.
    ///
    /// # Arguments
    ///
    /// * `app_id` - The fingerprint of the application
    /// * `secret_name` - The name of the secret to revoke access to
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The permission does not exist
    /// - Database deletion fails
    pub fn revoke_permission(&self, app_id: &str, secret_name: &str) -> Result<()> {
        // Get secret ID
        let secret_id: String = self.conn.query_row(
            "SELECT id FROM secrets WHERE name = ?",
            [secret_name],
            |row| row.get(0)
        )
        .context(format!("Secret not found: {}", secret_name))?;

        // Delete permission
        let affected = self.conn.execute(
            "DELETE FROM permissions WHERE app_id = (SELECT id FROM applications WHERE fingerprint = ?) AND secret_id = ?",
            rusqlite::params![app_id, &secret_id]
        )
        .context("Failed to revoke permission")?;

        if affected == 0 {
            anyhow::bail!("Permission not found for app '{}' and secret '{}'", app_id, secret_name);
        }

        Ok(())
    }

    /// Get permissions for a specific application
    ///
    /// Returns a list of secret names that the application has access to.
    ///
    /// # Arguments
    ///
    /// * `app_id` - The fingerprint of the application
    ///
    /// # Returns
    ///
    /// A vector of secret names
    #[allow(dead_code)] // Will be used to enhance app.list response in Phase 2
    pub fn get_app_permissions(&self, app_id: &str) -> Result<Vec<String>> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT s.name
            FROM permissions p
            JOIN applications a ON p.app_id = a.id
            JOIN secrets s ON p.secret_id = s.id
            WHERE a.fingerprint = ?
            ORDER BY s.name
            "#
        )?;

        let names = stmt.query_map([app_id], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;

        Ok(names)
    }

    /// F076-F080: Grant permission for an app to access a secret
    ///
    /// Creates a permission record linking an application to a secret.
    /// This allows the app to retrieve the secret value via secret.get.
    ///
    /// # Arguments
    ///
    /// * `app_id` - The identifier of the application (fingerprint)
    /// * `secret_name` - The name of the secret to grant access to
    /// * `granted_by` - How the permission was granted ("user" or "auto")
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` on success
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - F078: The app_id does not exist in applications table
    /// - F079: The secret_name does not exist in secrets table
    /// - Database insert fails
    ///
    /// # Features
    ///
    /// - F076: Generates UUID for permission ID
    /// - F077: Method signature for grant_permission
    /// - F078: Validates app_id exists in applications table
    /// - F079: Validates secret_name exists in secrets table
    /// - F080: Inserts permission with granted_at timestamp (via DEFAULT CURRENT_TIMESTAMP)
    ///
    /// # Implementation
    ///
    /// Uses INSERT OR REPLACE to handle re-granting (idempotent operation).
    /// The UNIQUE(app_id, secret_id) constraint ensures only one permission per pair.
    pub fn grant_permission(&self, app_id: &str, secret_name: &str, granted_by: &str) -> Result<()> {
        // F078: Validate that app_id exists in applications table
        let app_exists: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM applications WHERE fingerprint = ?",
            [app_id],
            |row| row.get(0)
        )
        .context("Failed to check if application exists")?;

        if app_exists == 0 {
            anyhow::bail!("Application not found: {}", app_id);
        }

        // F079: Validate that secret_name exists in secrets table and get its ID
        let secret_id: String = self.conn.query_row(
            "SELECT id FROM secrets WHERE name = ?",
            [secret_name],
            |row| row.get(0)
        )
        .context(format!("Secret not found: {}", secret_name))?;

        // F076, F080: Insert permission with generated UUID and granted_at timestamp
        let permission_id = uuid::Uuid::new_v4().to_string();

        // Check if permission already exists
        let exists: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM permissions WHERE app_id = (SELECT id FROM applications WHERE fingerprint = ?) AND secret_id = ?",
            rusqlite::params![app_id, &secret_id],
            |row| row.get(0)
        )?;

        if exists > 0 {
            // Permission already exists, update granted_at
            self.conn.execute(
                "UPDATE permissions SET granted_by = ?, granted_at = CURRENT_TIMESTAMP WHERE app_id = (SELECT id FROM applications WHERE fingerprint = ?) AND secret_id = ?",
                rusqlite::params![granted_by, app_id, &secret_id]
            )
            .context("Failed to update permission")?;
        } else {
            // Insert new permission
            self.conn.execute(
                "INSERT INTO permissions (id, app_id, secret_id, granted_by) SELECT ?, id, ?, ? FROM applications WHERE fingerprint = ?",
                rusqlite::params![permission_id, &secret_id, granted_by, app_id]
            )
            .context("Failed to insert permission")?;
        }

        Ok(())
    }

    /// F084: Query audit log with optional filtering
    ///
    /// Retrieves audit log entries with optional app filter and limit.
    ///
    /// # Arguments
    ///
    /// * `app_filter` - Optional app_id to filter by
    /// * `limit` - Maximum number of entries to return
    ///
    /// # Returns
    ///
    /// A vector of `AuditEntry` structs
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails
    ///
    /// # Features
    ///
    /// - F084: Implements query_audit_log() method
    ///
    /// # Implementation
    ///
    /// Returns entries ordered by timestamp DESC (most recent first).
    /// Uses idx_audit_log_timestamp index for efficient queries.
    pub fn query_audit_log(&self, app_filter: Option<&str>, limit: usize) -> Result<Vec<AuditEntry>> {
        if let Some(app_id) = app_filter {
            // Filter by app_id
            let mut stmt = self.conn.prepare(
                "SELECT id, timestamp, app_id, secret_name, action, success, details FROM audit_log WHERE app_id = ? ORDER BY timestamp DESC LIMIT ?"
            )?;

            let entries = stmt.query_map(rusqlite::params![app_id, limit as i64], |row| {
                Ok(AuditEntry {
                    id: row.get(0)?,
                    timestamp: row.get(1)?,
                    app_id: row.get(2)?,
                    secret_name: row.get(3)?,
                    action: row.get(4)?,
                    success: row.get(5)?,
                    details: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

            Ok(entries)
        } else {
            // No filter, return all entries
            let mut stmt = self.conn.prepare(
                "SELECT id, timestamp, app_id, secret_name, action, success, details FROM audit_log ORDER BY timestamp DESC LIMIT ?"
            )?;

            let entries = stmt.query_map([limit as i64], |row| {
                Ok(AuditEntry {
                    id: row.get(0)?,
                    timestamp: row.get(1)?,
                    app_id: row.get(2)?,
                    secret_name: row.get(3)?,
                    action: row.get(4)?,
                    success: row.get(5)?,
                    details: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

            Ok(entries)
        }
    }

    /// F085-F086: Clean up old audit log entries with configurable retention
    ///
    /// Removes audit log entries older than the specified number of days.
    ///
    /// # Arguments
    ///
    /// * `retention_days` - Number of days to retain audit logs (default: 30)
    ///
    /// # Returns
    ///
    /// Returns the number of deleted entries on success
    ///
    /// # Errors
    ///
    /// Returns an error if the database delete fails
    ///
    /// # Features
    ///
    /// - F085: Implements cleanup_old_logs() method that removes logs older than specified days
    /// - F086: Configurable retention period (defaults to 30 days)
    ///
    /// # Implementation
    ///
    /// Uses datetime comparison to delete entries where timestamp is older than retention_days.
    /// SQLite's datetime functions handle the calculation.
    pub fn cleanup_old_logs(&self, retention_days: Option<u32>) -> Result<usize> {
        let days = retention_days.unwrap_or(30);
        let query = format!(
            "DELETE FROM audit_log WHERE timestamp < datetime('now', '-{} days')",
            days
        );

        let deleted = self.conn.execute(&query, [])
            .context("Failed to cleanup old audit logs")?;

        if deleted > 0 {
            tracing::info!("Cleaned up {} old audit log entries (>{} days)", deleted, days);
        }

        Ok(deleted)
    }

    /// Count total secrets in the vault
    ///
    /// # Returns
    ///
    /// The number of secrets stored
    pub fn count_secrets(&self) -> Result<i64> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM secrets",
            [],
            |row| row.get(0)
        )?;
        Ok(count)
    }

    /// Count total registered applications
    ///
    /// # Returns
    ///
    /// The number of registered applications
    pub fn count_applications(&self) -> Result<i64> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM applications",
            [],
            |row| row.get(0)
        )?;
        Ok(count)
    }

    /// Get secret metadata with version information
    ///
    /// # Arguments
    ///
    /// * `name` - The secret name
    ///
    /// # Returns
    ///
    /// The secret metadata including version
    pub fn get_secret_metadata(&self, name: &str) -> Result<Option<SecretMetadataWithVersion>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, provider, environment, created_at, version, previous_value_encrypted FROM secrets WHERE name = ?"
        )?;

        let result = stmt.query_row([name], |row| {
            Ok(SecretMetadataWithVersion {
                id: row.get(0)?,
                name: row.get(1)?,
                provider: row.get(2)?,
                environment: row.get(3)?,
                created_at: row.get(4)?,
                version: row.get(5)?,
                has_previous: row.get::<_, Option<Vec<u8>>>(6)?.is_some(),
            })
        });

        match result {
            Ok(secret) => Ok(Some(secret)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Rotate a secret's value
    ///
    /// Stores the current encrypted value as previous_value_encrypted,
    /// updates with the new encrypted value, and increments the version.
    ///
    /// # Arguments
    ///
    /// * `name` - The secret name
    /// * `new_encrypted` - The new encrypted value
    /// * `new_version` - The new version number
    ///
    /// # Returns
    ///
    /// Ok(()) on success
    pub fn rotate_secret(&self, name: &str, new_encrypted: &[u8], new_version: i64) -> Result<()> {
        // First, copy current value to previous_value_encrypted, then update with new value
        self.conn.execute(
            r#"
            UPDATE secrets
            SET previous_value_encrypted = value_encrypted,
                value_encrypted = ?,
                version = ?,
                rotated_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE name = ?
            "#,
            rusqlite::params![new_encrypted, new_version, name]
        ).context("Failed to rotate secret")?;

        Ok(())
    }

    /// Rollback a secret to its previous version
    ///
    /// Restores the previous encrypted value and decrements the version.
    ///
    /// # Arguments
    ///
    /// * `name` - The secret name
    ///
    /// # Returns
    ///
    /// The new (rolled-back) version number
    ///
    /// # Errors
    ///
    /// Returns error if:
    /// - Secret doesn't exist
    /// - No previous version is available
    pub fn rollback_secret(&self, name: &str) -> Result<i64> {
        // Get current metadata to check if rollback is possible
        let metadata = self.get_secret_metadata(name)?
            .context(format!("Secret '{}' not found", name))?;

        if !metadata.has_previous {
            anyhow::bail!("No previous version available for secret '{}'", name);
        }

        let new_version = metadata.version.unwrap_or(1) - 1;
        if new_version < 1 {
            anyhow::bail!("Cannot rollback beyond version 1");
        }

        // Swap current with previous
        self.conn.execute(
            r#"
            UPDATE secrets
            SET value_encrypted = previous_value_encrypted,
                previous_value_encrypted = NULL,
                version = ?,
                rotated_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE name = ?
            "#,
            rusqlite::params![new_version, name]
        ).context("Failed to rollback secret")?;

        Ok(new_version)
    }

    /// Get secret version history
    ///
    /// Returns version information for a secret.
    ///
    /// # Arguments
    ///
    /// * `name` - The secret name
    ///
    /// # Returns
    ///
    /// A tuple of (current_version, has_previous, rotated_at)
    pub fn get_secret_history(&self, name: &str) -> Result<Option<(i64, bool, Option<String>)>> {
        let mut stmt = self.conn.prepare(
            "SELECT version, previous_value_encrypted, rotated_at FROM secrets WHERE name = ?"
        )?;

        let result = stmt.query_row([name], |row| {
            Ok((
                row.get::<_, Option<i64>>(0)?.unwrap_or(1),
                row.get::<_, Option<Vec<u8>>>(1)?.is_some(),
                row.get::<_, Option<String>>(2)?,
            ))
        });

        match result {
            Ok(r) => Ok(Some(r)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Get secrets due for rotation
    ///
    /// Returns secrets that haven't been rotated within the specified days.
    ///
    /// # Arguments
    ///
    /// * `days_since_rotation` - Number of days since last rotation
    ///
    /// # Returns
    ///
    /// List of secret names that need rotation
    pub fn get_secrets_needing_rotation(&self, days_since_rotation: u64) -> Result<Vec<String>> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT name FROM secrets
            WHERE rotated_at IS NULL
               OR rotated_at < datetime('now', '-' || ? || ' days')
            ORDER BY rotated_at ASC NULLS FIRST
            "#
        )?;

        let rows = stmt.query_map([days_since_rotation.to_string()], |row| {
            row.get::<_, String>(0)
        })?;

        let mut secrets = Vec::new();
        for row in rows {
            secrets.push(row?);
        }

        Ok(secrets)
    }

    /// Create an ephemeral secret with a TTL (time-to-live)
    ///
    /// Ephemeral secrets automatically expire after the specified duration.
    /// Use cleanup_expired_secrets() to remove expired secrets.
    ///
    /// # Arguments
    ///
    /// * `name` - The name of the secret
    /// * `value_encrypted` - The encrypted secret value
    /// * `provider` - Optional provider identifier
    /// * `environment` - Environment context
    /// * `ttl_seconds` - Time-to-live in seconds
    pub fn create_ephemeral_secret(
        &self,
        name: &str,
        value_encrypted: &[u8],
        provider: Option<&str>,
        environment: &str,
        ttl_seconds: u64,
    ) -> Result<()> {
        let id = uuid::Uuid::new_v4().to_string();

        self.conn.execute(
            r#"
            INSERT INTO secrets (id, name, value_encrypted, provider, environment, expires_at)
            VALUES (?, ?, ?, ?, ?, datetime('now', '+' || ? || ' seconds'))
            ON CONFLICT(name) DO UPDATE SET
                value_encrypted = excluded.value_encrypted,
                provider = excluded.provider,
                environment = excluded.environment,
                expires_at = excluded.expires_at,
                updated_at = CURRENT_TIMESTAMP
            "#,
            rusqlite::params![id, name, value_encrypted, provider, environment, ttl_seconds as i64]
        ).context("Failed to create ephemeral secret")?;

        Ok(())
    }

    /// Update the TTL of an existing secret
    ///
    /// # Arguments
    ///
    /// * `name` - The name of the secret
    /// * `ttl_seconds` - New time-to-live in seconds (from now), or None to make permanent
    pub fn set_secret_ttl(&self, name: &str, ttl_seconds: Option<u64>) -> Result<()> {
        match ttl_seconds {
            Some(ttl) => {
                self.conn.execute(
                    "UPDATE secrets SET expires_at = datetime('now', '+' || ? || ' seconds') WHERE name = ?",
                    rusqlite::params![ttl as i64, name]
                ).context("Failed to set secret TTL")?;
            }
            None => {
                self.conn.execute(
                    "UPDATE secrets SET expires_at = NULL WHERE name = ?",
                    [name]
                ).context("Failed to remove secret TTL")?;
            }
        }
        Ok(())
    }

    /// Clean up expired ephemeral secrets
    ///
    /// Deletes all secrets where expires_at is in the past.
    /// Should be called periodically (e.g., on daemon startup, hourly, etc.)
    ///
    /// # Returns
    ///
    /// The number of secrets that were deleted
    pub fn cleanup_expired_secrets(&self) -> Result<usize> {
        // First, get IDs of expired secrets for cascade delete
        let mut stmt = self.conn.prepare(
            "SELECT id FROM secrets WHERE expires_at IS NOT NULL AND expires_at < datetime('now')"
        )?;

        let expired_ids: Vec<String> = stmt.query_map([], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        if expired_ids.is_empty() {
            return Ok(0);
        }

        // Delete associated permissions
        for id in &expired_ids {
            self.conn.execute("DELETE FROM permissions WHERE secret_id = ?", [id])?;
            self.conn.execute("DELETE FROM agent_permissions WHERE secret_name = (SELECT name FROM secrets WHERE id = ?)", [id])?;
        }

        // Delete expired secrets
        let deleted = self.conn.execute(
            "DELETE FROM secrets WHERE expires_at IS NOT NULL AND expires_at < datetime('now')",
            []
        )?;

        if deleted > 0 {
            tracing::info!("Cleaned up {} expired ephemeral secrets", deleted);
        }

        Ok(deleted)
    }

    /// Get secrets that will expire soon (for warnings/notifications)
    ///
    /// # Arguments
    ///
    /// * `within_seconds` - Find secrets expiring within this many seconds
    ///
    /// # Returns
    ///
    /// List of secret names and their expiration times
    pub fn get_expiring_secrets(&self, within_seconds: u64) -> Result<Vec<(String, String)>> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT name, expires_at
            FROM secrets
            WHERE expires_at IS NOT NULL
              AND expires_at > datetime('now')
              AND expires_at <= datetime('now', '+' || ? || ' seconds')
            ORDER BY expires_at ASC
            "#
        )?;

        let results = stmt.query_map([within_seconds as i64], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(results)
    }
}

/// F084: Audit log entry structure
///
/// Represents a single audit log entry with all fields.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    /// Unique identifier for the audit entry
    pub id: i64,
    /// Timestamp when the action occurred
    pub timestamp: String,
    /// Application identifier (can be empty for CLI operations)
    pub app_id: String,
    /// Name of the secret that was accessed
    pub secret_name: String,
    /// Action performed (read, write, delete, grant, revoke, register)
    pub action: String,
    /// Whether the action succeeded
    pub success: bool,
    /// Optional additional details or error message
    pub details: Option<String>,
}

/// Database statistics
#[derive(Debug)]
pub struct DatabaseStats {
    pub total_secrets: i64,
    pub with_provider: i64,
    pub environments: Vec<String>,
    pub total_applications: i64,
    pub total_permissions: i64,
    pub total_audit_entries: i64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_storage_initialization() {
        let db_path = "/tmp/test_secretariat.db";

        // Clean up any existing test database
        let _ = fs::remove_file(db_path);

        // Create storage with test encryption key
        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // Verify schema was created
        storage.health_check()
            .expect("Health check failed");

        // Check stats
        let stats = storage.stats()
            .expect("Failed to get stats");

        assert_eq!(stats.total_secrets, 0);
        assert_eq!(stats.with_provider, 0);

        // Clean up
        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_schema_has_correct_columns() {
        let db_path = "/tmp/test_secretariat_schema.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // Verify table structure using PRAGMA
        let columns: Vec<String> = {
            let mut stmt = storage.connection()
                .prepare("PRAGMA table_info(secrets)")
                .expect("Failed to prepare pragma statement");

            stmt.query_map([], |row| row.get::<_, String>(1))
                .expect("Failed to query columns")
                .collect::<Result<Vec<_>, _>>()
                .expect("Failed to collect columns")
        };

        // F001-F005: Verify required columns exist
        assert!(columns.contains(&"id".to_string()), "F001: id column missing");
        assert!(columns.contains(&"name".to_string()), "F002: name column missing");
        assert!(columns.contains(&"value_encrypted".to_string()), "F003: value_encrypted column missing");
        assert!(columns.contains(&"provider".to_string()), "F004: provider column missing");
        assert!(columns.contains(&"environment".to_string()), "F005: environment column missing");

        // Additional columns from spec
        assert!(columns.contains(&"created_at".to_string()));
        assert!(columns.contains(&"updated_at".to_string()));
        assert!(columns.contains(&"rotated_at".to_string()));
        assert!(columns.contains(&"notes".to_string()));

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_applications_table_exists() {
        let db_path = "/tmp/test_secretariat_wave3_apps.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // F011: Verify applications table structure
        let columns: Vec<String> = {
            let mut stmt = storage.connection()
                .prepare("PRAGMA table_info(applications)")
                .expect("Failed to prepare pragma statement");

            stmt.query_map([], |row| row.get::<_, String>(1))
                .expect("Failed to query columns")
                .collect::<Result<Vec<_>, _>>()
                .expect("Failed to collect columns")
        };

        // Verify all required columns exist
        assert!(columns.contains(&"id".to_string()), "F011: id column missing");
        assert!(columns.contains(&"name".to_string()), "F011: name column missing");
        assert!(columns.contains(&"path".to_string()), "F011: path column missing");
        assert!(columns.contains(&"bundle_id".to_string()), "F011: bundle_id column missing");
        assert!(columns.contains(&"fingerprint".to_string()), "F011: fingerprint column missing");
        assert!(columns.contains(&"registered_at".to_string()));
        assert!(columns.contains(&"last_access".to_string()));

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_permissions_table_exists() {
        let db_path = "/tmp/test_secretariat_wave3_perms.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // F012: Verify permissions table structure
        let columns: Vec<String> = {
            let mut stmt = storage.connection()
                .prepare("PRAGMA table_info(permissions)")
                .expect("Failed to prepare pragma statement");

            stmt.query_map([], |row| row.get::<_, String>(1))
                .expect("Failed to query columns")
                .collect::<Result<Vec<_>, _>>()
                .expect("Failed to collect columns")
        };

        // Verify all required columns exist
        assert!(columns.contains(&"id".to_string()), "F012: id column missing");
        assert!(columns.contains(&"app_id".to_string()), "F012: app_id column missing");
        assert!(columns.contains(&"secret_id".to_string()), "F012: secret_id column missing");
        assert!(columns.contains(&"granted_at".to_string()), "F012: granted_at column missing");
        assert!(columns.contains(&"granted_by".to_string()));

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_permissions_unique_constraint() {
        let db_path = "/tmp/test_secretariat_wave3_unique.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // F013: Test UNIQUE(app_id, secret_id) constraint
        let conn = storage.connection();

        // Create test applications and secrets first (foreign key requirements)
        conn.execute(
            "INSERT INTO applications (id, name) VALUES (?, ?)",
            ["app1", "Test App 1"],
        ).expect("Failed to create test application 1");

        conn.execute(
            "INSERT INTO applications (id, name) VALUES (?, ?)",
            ["app2", "Test App 2"],
        ).expect("Failed to create test application 2");

        conn.execute(
            "INSERT INTO secrets (id, name, value_encrypted) VALUES (?1, ?2, ?3)",
            rusqlite::params!["secret1", "TEST_SECRET", &[1u8, 2, 3, 4, 5]],
        ).expect("Failed to create test secret");

        // Insert first permission
        let result1 = conn.execute(
            "INSERT INTO permissions (id, app_id, secret_id, granted_by) VALUES (?, ?, ?, ?)",
            ["perm1", "app1", "secret1", "user"],
        );
        assert!(result1.is_ok(), "F013: First insert should succeed");

        // Try to insert duplicate (same app_id and secret_id)
        let result2 = conn.execute(
            "INSERT INTO permissions (id, app_id, secret_id, granted_by) VALUES (?, ?, ?, ?)",
            ["perm2", "app1", "secret1", "user"],
        );
        assert!(result2.is_err(), "F013: Duplicate insert should fail due to UNIQUE constraint");

        // Different app_id should work
        let result3 = conn.execute(
            "INSERT INTO permissions (id, app_id, secret_id, granted_by) VALUES (?, ?, ?, ?)",
            ["perm3", "app2", "secret1", "user"],
        );
        assert!(result3.is_ok(), "F013: Different app_id should succeed");

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_audit_log_table_exists() {
        let db_path = "/tmp/test_secretariat_wave3_audit.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // F014: Verify audit_log table structure
        let columns: Vec<String> = {
            let mut stmt = storage.connection()
                .prepare("PRAGMA table_info(audit_log)")
                .expect("Failed to prepare pragma statement");

            stmt.query_map([], |row| row.get::<_, String>(1))
                .expect("Failed to query columns")
                .collect::<Result<Vec<_>, _>>()
                .expect("Failed to collect columns")
        };

        // Verify all required columns exist
        assert!(columns.contains(&"id".to_string()), "F014: id column missing");
        assert!(columns.contains(&"timestamp".to_string()), "F014: timestamp column missing");
        assert!(columns.contains(&"app_id".to_string()), "F014: app_id column missing");
        assert!(columns.contains(&"secret_name".to_string()), "F014: secret_name column missing");
        assert!(columns.contains(&"action".to_string()), "F014: action column missing");
        assert!(columns.contains(&"success".to_string()), "F014: success column missing");
        assert!(columns.contains(&"details".to_string()));

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_audit_log_index_exists() {
        let db_path = "/tmp/test_secretariat_wave3_index.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        // F015: Verify idx_audit_log_timestamp index exists
        let indexes: Vec<String> = {
            let mut stmt = storage.connection()
                .prepare("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='audit_log'")
                .expect("Failed to prepare index query");

            stmt.query_map([], |row| row.get::<_, String>(0))
                .expect("Failed to query indexes")
                .collect::<Result<Vec<_>, _>>()
                .expect("Failed to collect indexes")
        };

        assert!(
            indexes.contains(&"idx_audit_log_timestamp".to_string()),
            "F015: idx_audit_log_timestamp index missing. Found indexes: {:?}",
            indexes
        );

        drop(storage);
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_wave3_stats_include_new_tables() {
        let db_path = "/tmp/test_secretariat_wave3_stats.db";
        let _ = fs::remove_file(db_path);

        let storage = Storage::new(db_path, "test_key_12345")
            .expect("Failed to initialize storage");

        let stats = storage.stats()
            .expect("Failed to get stats");

        // Verify Wave 3 statistics are included
        assert_eq!(stats.total_applications, 0);
        assert_eq!(stats.total_permissions, 0);
        assert_eq!(stats.total_audit_entries, 0);

        drop(storage);
        let _ = fs::remove_file(db_path);
    }
}

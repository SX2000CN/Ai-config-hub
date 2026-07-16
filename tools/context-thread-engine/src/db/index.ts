/**
 * Database Layer
 *
 * Handles SQLite database initialization and connection management.
 */

import { SqliteDatabase, SqliteBackend, createDatabase } from './sqlite-adapter';
import { createHash } from 'crypto';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { SchemaVersion } from '../types';
import { runMigrations, getCurrentVersion, CURRENT_SCHEMA_VERSION } from './migrations';
import { getContextThreadDir } from '../directory';
import {
  ContentMode,
  ContentModeState,
  readContentModeState,
  writeContentMode,
} from '../content-mode';
import { ConfigError } from '../errors';
import { installStructureContentGuards } from './structure-guards';

export { SqliteDatabase, SqliteBackend } from './sqlite-adapter';

/**
 * Apply connection-level PRAGMAs. Shared by `initialize` and `open` so the two
 * paths can't drift.
 *
 * `busy_timeout` is set FIRST, before any pragma that might touch the database
 * file (notably `journal_mode`). If another process holds a write lock at open
 * time, the later pragmas — and the connection's first query — then wait out
 * the lock instead of throwing "database is locked" immediately. See issue #238.
 *
 * The 5s window (was 120s) rides out a normal incremental sync; the old
 * 2-minute wait presented as a frozen, hung agent. With WAL, reads never block
 * on a writer, so this timeout only governs cross-process write contention
 * (e.g. the git-hook `context-thread sync` running while the MCP server writes).
 */
function configureConnection(db: SqliteDatabase): void {
  db.pragma('busy_timeout = 5000');      // MUST be first — see above
  db.pragma('foreign_keys = ON');
  db.pragma('journal_mode = WAL');       // node:sqlite supports WAL on every platform
  db.pragma('synchronous = NORMAL');     // safe with WAL mode
  db.pragma('cache_size = -64000');      // 64 MB page cache
  db.pragma('temp_store = MEMORY');      // temp tables in memory
  db.pragma('mmap_size = 268435456');    // 256 MB memory-mapped I/O
}

/**
 * Immutable SQLite connections report `journal_mode=delete` even when the
 * database header is persistently configured for WAL. Read the file format
 * versions directly so read-only status stays accurate without sidecar I/O.
 */
function readPersistentJournalMode(dbPath: string): 'wal' | 'delete' | null {
  const header = Buffer.alloc(20);
  let fd: number | null = null;
  try {
    fd = fs.openSync(dbPath, 'r');
    if (fs.readSync(fd, header, 0, header.length, 0) !== header.length) return null;
    if (header.subarray(0, 16).toString('binary') !== 'SQLite format 3\0') return null;

    const writeVersion = header[18];
    const readVersion = header[19];
    if (writeVersion === 2 && readVersion === 2) return 'wal';
    if (writeVersion === 1 && readVersion === 1) return 'delete';
    return null;
  } catch {
    return null;
  } finally {
    if (fd !== null) fs.closeSync(fd);
  }
}

function getPrivacyBackupPrefix(dbPath: string): string {
  const databaseId = createHash('sha256')
    .update(path.resolve(dbPath))
    .digest('hex')
    .slice(0, 12);
  return `context-thread-privacy-backup-${databaseId}-`;
}

/**
 * Database connection wrapper with lifecycle management
 */
export class DatabaseConnection {
  private db: SqliteDatabase;
  private dbPath: string;
  private backend: SqliteBackend;
  private readOnly: boolean;
  private contentModeState: ContentModeState;

  private constructor(
    db: SqliteDatabase,
    dbPath: string,
    backend: SqliteBackend,
    readOnly: boolean,
    contentModeState: ContentModeState
  ) {
    this.db = db;
    this.dbPath = dbPath;
    this.backend = backend;
    this.readOnly = readOnly;
    this.contentModeState = contentModeState;
  }

  /**
   * Initialize a new database at the given path
   */
  static initialize(
    dbPath: string,
    options: { contentMode?: ContentMode } = {}
  ): DatabaseConnection {
    // Ensure parent directory exists
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    // Create and configure database
    const { db, backend } = createDatabase(dbPath);

    configureConnection(db);

    // Run schema initialization
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf-8');
    db.exec(schema);
    installStructureContentGuards(db);

    // Record current schema version so migrations aren't re-applied on open
    const currentVersion = getCurrentVersion(db);
    if (currentVersion < CURRENT_SCHEMA_VERSION) {
      db.prepare(
        'INSERT OR IGNORE INTO schema_versions (version, applied_at, description) VALUES (?, ?, ?)'
      ).run(CURRENT_SCHEMA_VERSION, Date.now(), 'Initial schema includes all migrations');
    }

    const contentMode = options.contentMode ?? 'structure';
    writeContentMode(db, contentMode);

    return new DatabaseConnection(
      db,
      dbPath,
      backend,
      false,
      { mode: contentMode, label: contentMode, legacy: false }
    );
  }

  /**
   * Open an existing database
   */
  static open(dbPath: string, options: { readOnly?: boolean } = {}): DatabaseConnection {
    if (!fs.existsSync(dbPath)) {
      throw new Error(`Database not found: ${dbPath}`);
    }

    const readOnly = options.readOnly ?? false;
    const { db, backend } = createDatabase(dbPath, { readOnly });

    if (!readOnly) {
      configureConnection(db);
    }

    // A read-only open must never mutate schema or connection state. Callers
    // can still inspect an older database, but must reopen writable to migrate.
    if (!readOnly) {
      const currentVersion = getCurrentVersion(db);
      if (currentVersion < CURRENT_SCHEMA_VERSION) {
        runMigrations(db, currentVersion);
      }
    }

    const contentModeState = readContentModeState(db);
    return new DatabaseConnection(db, dbPath, backend, readOnly, contentModeState);
  }

  /**
   * Get the underlying database instance
   */
  getDb(): SqliteDatabase {
    return this.db;
  }

  /**
   * Get the SQLite backend serving this connection. Per-instance so
   * MCP cross-project queries report the right backend even when
   * multiple project DBs are open in the same process.
   */
  getBackend(): SqliteBackend {
    return this.backend;
  }

  isReadOnly(): boolean {
    return this.readOnly;
  }

  getContentModeState(): ContentModeState {
    return { ...this.contentModeState };
  }

  setContentMode(mode: ContentMode): void {
    writeContentMode(this.db, mode);
    this.contentModeState = { mode, label: mode, legacy: false };
  }

  private checkpointWalOrThrow(phase: string): void {
    const raw = this.db.pragma('wal_checkpoint(TRUNCATE)');
    const row = Array.isArray(raw) ? raw[0] : raw;
    const busy = row && typeof row === 'object'
      ? Number((row as Record<string, unknown>).busy ?? 0)
      : 0;
    const logFrames = row && typeof row === 'object'
      ? Number((row as Record<string, unknown>).log ?? 0)
      : 0;
    const checkpointedFrames = row && typeof row === 'object'
      ? Number((row as Record<string, unknown>).checkpointed ?? 0)
      : 0;

    if (busy !== 0 || checkpointedFrames < logFrames) {
      throw new ConfigError(
        `Cannot complete the privacy transition because the WAL is busy during ${phase}. ` +
        'Close active ContextThread readers and retry.',
        { phase, busy, logFrames, checkpointedFrames }
      );
    }
  }

  private setJournalModeOrThrow(mode: 'DELETE' | 'WAL', phase: string): void {
    const row = this.db
      .prepare(`PRAGMA journal_mode = ${mode}`)
      .get() as Record<string, unknown> | undefined;
    const actual = String(row?.journal_mode ?? '').toUpperCase();
    if (actual !== mode) {
      throw new ConfigError(
        `Cannot switch SQLite journal mode to ${mode} during ${phase}. Close active readers and retry.`,
        { phase, requested: mode, actual: actual || 'unknown' }
      );
    }
  }

  private restorePrivacyBackup(backupPath: string): void {
    this.db.close();
    for (const suffix of ['-wal', '-shm', '-journal']) {
      fs.rmSync(`${this.dbPath}${suffix}`, { force: true });
    }
    fs.copyFileSync(backupPath, this.dbPath);
    fs.rmSync(backupPath, { force: true });
  }

  /**
   * Remove all optional source-derived payloads, rebuild the external-content
   * FTS table, then compact both the main DB and WAL so deleted bytes are not
   * left recoverable in free pages.
   */
  transitionToStructure(): void {
    let backupDir: string | null = null;
    let backupPath: string | null = null;
    let backupReady = false;
    let preserveBackup = false;
    let transactionOpen = false;

    // A verified WAL checkpoint is the zero-change preflight. Switching to the
    // rollback journal then requires an exclusive SQLite lock, so a reader that
    // races the preflight fails the transition before graph data is touched.
    this.checkpointWalOrThrow('preflight');
    this.setJournalModeOrThrow('DELETE', 'privacy preflight');
    this.db.pragma('locking_mode = EXCLUSIVE');

    try {
      // Acquire and retain the exclusive rollback-journal lock across backup,
      // scrub and VACUUM. The backup makes every later failure reversible.
      this.db.exec('BEGIN EXCLUSIVE');
      this.db.exec('COMMIT');
      backupDir = fs.mkdtempSync(path.join(os.tmpdir(), getPrivacyBackupPrefix(this.dbPath)));
      backupPath = path.join(backupDir, 'context-thread.db');
      this.db.prepare('VACUUM INTO ?').run(backupPath);
      backupReady = true;

      this.db.pragma('secure_delete = ON');
      this.db.exec('BEGIN EXCLUSIVE');
      transactionOpen = true;
      this.db.exec(`
        UPDATE nodes
        SET docstring = NULL,
            signature = NULL,
            decorators = NULL,
            type_parameters = NULL
        WHERE docstring IS NOT NULL
           OR signature IS NOT NULL
           OR decorators IS NOT NULL
           OR type_parameters IS NOT NULL;
        UPDATE edges SET metadata = NULL WHERE metadata IS NOT NULL;
        UPDATE unresolved_refs SET candidates = NULL WHERE candidates IS NOT NULL;
        INSERT INTO nodes_fts(nodes_fts) VALUES('rebuild');
      `);
      writeContentMode(this.db, 'structure');
      this.db.exec('COMMIT');
      transactionOpen = false;

      // In DELETE mode VACUUM rewrites the main database directly, while the
      // retained exclusive lock prevents readers from pinning old pages.
      this.db.exec('VACUUM');
      // Closing the exclusive DELETE-mode connection releases its lock and
      // removes the rollback journal. ContextThread reopens immediately after
      // this method, which restores the normal WAL configuration.
      this.db.close();
      for (const suffix of ['-wal', '-journal']) {
        const sidecarPath = `${this.dbPath}${suffix}`;
        if (fs.existsSync(sidecarPath) && fs.statSync(sidecarPath).size > 0) {
          throw new ConfigError('Privacy transition left a non-empty SQLite sidecar.', {
            sidecarPath,
            sidecarSize: fs.statSync(sidecarPath).size,
          });
        }
      }
      fs.rmSync(backupPath, { force: true });
      backupReady = false;
      this.contentModeState = { mode: 'structure', label: 'structure', legacy: false };
    } catch (error) {
      if (transactionOpen) {
        try { this.db.exec('ROLLBACK'); } catch { /* preserve the primary error */ }
      }
      if (backupReady && backupPath) {
        try {
          this.restorePrivacyBackup(backupPath);
          backupReady = false;
        } catch (restoreError) {
          preserveBackup = true;
          throw new ConfigError('Privacy transition failed and automatic database restore also failed.', {
            transitionError: error instanceof Error ? error.message : String(error),
            restoreError: restoreError instanceof Error ? restoreError.message : String(restoreError),
            backupPath,
          });
        }
      }
      throw error;
    } finally {
      if (this.db.open) {
        // SQLite retains an exclusive locking-mode lock until this connection
        // closes. ContextThread reopens after success/failure to release it.
        try { this.db.pragma('locking_mode = NORMAL'); } catch { /* reopen releases it */ }
      }
      if (!preserveBackup && backupDir && fs.existsSync(backupDir)) {
        fs.rmSync(backupDir, {
          recursive: true,
          force: true,
          maxRetries: 3,
          retryDelay: 50,
        });
      }
    }
  }

  /** Replace graph tables from a fully built staging database atomically. */
  replaceGraphFrom(stagingDbPath: string, contentMode: ContentMode): void {
    this.db.prepare('ATTACH DATABASE ? AS rich_stage').run(stagingDbPath);
    let replaced = false;
    try {
      this.db.transaction(() => {
        this.db.exec(`
          DELETE FROM unresolved_refs;
          DELETE FROM edges;
          DELETE FROM nodes;
          DELETE FROM files;
          DELETE FROM project_metadata;

          INSERT INTO files (
            path, content_hash, language, size, modified_at, indexed_at, node_count, errors
          )
          SELECT path, content_hash, language, size, modified_at, indexed_at, node_count, errors
          FROM rich_stage.files;

          INSERT INTO nodes (
            id, kind, name, qualified_name, file_path, language,
            start_line, end_line, start_column, end_column,
            docstring, signature, visibility,
            is_exported, is_async, is_static, is_abstract,
            decorators, type_parameters, updated_at
          )
          SELECT
            id, kind, name, qualified_name, file_path, language,
            start_line, end_line, start_column, end_column,
            docstring, signature, visibility,
            is_exported, is_async, is_static, is_abstract,
            decorators, type_parameters, updated_at
          FROM rich_stage.nodes;

          INSERT INTO edges (id, source, target, kind, metadata, line, col, provenance)
          SELECT id, source, target, kind, metadata, line, col, provenance
          FROM rich_stage.edges;

          INSERT INTO unresolved_refs (
            id, from_node_id, reference_name, reference_kind,
            line, col, candidates, file_path, language
          )
          SELECT
            id, from_node_id, reference_name, reference_kind,
            line, col, candidates, file_path, language
          FROM rich_stage.unresolved_refs;

          INSERT INTO project_metadata (key, value, updated_at)
          SELECT key, value, updated_at FROM rich_stage.project_metadata;
          INSERT INTO nodes_fts(nodes_fts) VALUES('rebuild');
        `);
        writeContentMode(this.db, contentMode);
      })();
      replaced = true;
    } finally {
      try {
        this.db.exec('DETACH DATABASE rich_stage');
      } catch (error) {
        if (replaced) throw error;
      }
    }

    this.contentModeState = { mode: contentMode, label: contentMode, legacy: false };
  }

  /**
   * Get database file path
   */
  getPath(): string {
    return this.dbPath;
  }

  /**
   * The journal mode actually in effect (e.g. 'wal', 'delete').
   *
   * SQLite silently keeps the prior mode if WAL can't be enabled — e.g. on
   * filesystems without shared-memory support (some network/virtualized mounts,
   * WSL2 /mnt), and always on the wasm backend. So the effective mode can differ
   * from what `configureConnection` requested. Surfaced in `context-thread status` so
   * a "database is locked" report is triageable: 'wal' ⇒ readers never block on a
   * writer; anything else ⇒ they can. See issue #238.
   */
  getJournalMode(): string {
    if (this.readOnly) {
      const persistentMode = readPersistentJournalMode(this.dbPath);
      if (persistentMode) return persistentMode;
    }

    const raw = this.db.pragma('journal_mode');
    const row = Array.isArray(raw) ? raw[0] : raw;
    const mode = row && typeof row === 'object'
      ? (row as Record<string, unknown>).journal_mode
      : row;
    return String(mode ?? '').toLowerCase();
  }

  /**
   * Get current schema version
   */
  getSchemaVersion(): SchemaVersion | null {
    const row = this.db
      .prepare('SELECT version, applied_at, description FROM schema_versions ORDER BY version DESC LIMIT 1')
      .get() as { version: number; applied_at: number; description: string | null } | undefined;

    if (!row) return null;

    return {
      version: row.version,
      appliedAt: row.applied_at,
      description: row.description ?? undefined,
    };
  }

  /**
   * Execute a function within a transaction
   */
  transaction<T>(fn: () => T): T {
    return this.db.transaction(fn)();
  }

  /**
   * Get database file size in bytes
   */
  getSize(): number {
    const stats = fs.statSync(this.dbPath);
    return stats.size;
  }

  /**
   * Optimize database (vacuum and analyze)
   */
  optimize(): void {
    this.db.exec('VACUUM');
    this.db.exec('ANALYZE');
  }

  /**
   * Lightweight, non-blocking maintenance to run after bulk writes
   * (indexAll, sync). Two operations:
   *
   *   - `PRAGMA optimize` — incremental ANALYZE; SQLite only re-analyzes
   *     tables whose row counts changed materially since the last
   *     ANALYZE. Without it, the query planner has no statistics on the
   *     freshly-bulk-loaded tables and can pick suboptimal indexes.
   *
   *   - `PRAGMA wal_checkpoint(PASSIVE)` — fold pending WAL pages back
   *     into the main database file so the WAL file doesn't grow
   *     unboundedly between automatic checkpoints (auto-fires at 1000
   *     pages by default; large indexAll runs blow past that).
   *
   * Both operations are silently swallowed on failure — they're a
   * best-effort optimization, never load-bearing for correctness.
   */
  runMaintenance(): void {
    try {
      this.db.exec('PRAGMA optimize');
    } catch {
      // ignore
    }
    try {
      this.db.exec('PRAGMA wal_checkpoint(PASSIVE)');
    } catch {
      // ignore (e.g., not in WAL mode)
    }
  }

  /**
   * Close the database connection
   */
  close(): void {
    this.db.close();
  }

  /**
   * Check if the database connection is open
   */
  isOpen(): boolean {
    return this.db.open;
  }
}

/**
 * Default database filename
 */
export const DATABASE_FILENAME = 'context-thread.db';

/**
 * Get the default database path for a project
 */
export function getDatabasePath(projectRoot: string): string {
  return path.join(getContextThreadDir(projectRoot), DATABASE_FILENAME);
}

/**
 * SQLite Adapter
 *
 * Thin wrapper over Node's built-in `node:sqlite` (`DatabaseSync`), exposed
 * through a small better-sqlite3-shaped interface so the rest of the codebase
 * is storage-agnostic.
 *
 * ContextThread ships with a bundled Node runtime, so `node:sqlite` (real SQLite,
 * with WAL + FTS5) is always available — there is no native build step and no
 * wasm fallback. When run from source instead, it requires Node >= 22.19.
 */

import * as crypto from 'crypto';
import * as fs from 'fs';
import { pathToFileURL } from 'url';
import { ConfigError } from '../errors';

const READ_ONLY_OPEN_ATTEMPTS = 3;
const SQLITE_HEADER_BYTES = 100;

interface DatabaseFingerprint {
  size: bigint;
  mtimeNs: bigint;
  ctimeNs: bigint;
  ino: bigint;
  headerHash: string;
}

function fingerprintDatabase(filePath: string): DatabaseFingerprint {
  const before = fs.statSync(filePath, { bigint: true });
  const header = Buffer.alloc(SQLITE_HEADER_BYTES);
  const fd = fs.openSync(filePath, 'r');
  let bytesRead = 0;
  try {
    bytesRead = fs.readSync(fd, header, 0, header.length, 0);
  } finally {
    fs.closeSync(fd);
  }
  const after = fs.statSync(filePath, { bigint: true });

  if (
    before.size !== after.size ||
    before.mtimeNs !== after.mtimeNs ||
    before.ctimeNs !== after.ctimeNs ||
    before.ino !== after.ino
  ) {
    throw new ConfigError('Database changed while its read-only fingerprint was being captured.', {
      filePath,
    });
  }

  return {
    size: after.size,
    mtimeNs: after.mtimeNs,
    ctimeNs: after.ctimeNs,
    ino: after.ino,
    headerHash: crypto.createHash('sha256').update(header.subarray(0, bytesRead)).digest('hex'),
  };
}

interface ReadOnlyFileState {
  database: DatabaseFingerprint;
  walExists: boolean;
  walSize: bigint;
}

function captureReadOnlyFileState(dbPath: string): ReadOnlyFileState {
  const walPath = `${dbPath}-wal`;
  const journalPath = `${dbPath}-journal`;
  const journalSize = fs.existsSync(journalPath)
    ? fs.statSync(journalPath, { bigint: true }).size
    : 0n;
  if (journalSize > 0n) {
    throw new ConfigError(
      'Cannot open ContextThread read-only while an active rollback journal exists.',
      { dbPath, journalPath, journalSize: journalSize.toString() }
    );
  }

  const walExists = fs.existsSync(walPath);
  const walSize = walExists ? fs.statSync(walPath, { bigint: true }).size : 0n;
  if (walSize > 0n) {
    throw new ConfigError(
      'Cannot open ContextThread read-only without modifying SQLite coordination files while committed WAL frames are pending. Close active writers or checkpoint the database, then retry.',
      { dbPath, walPath, walSize: walSize.toString() }
    );
  }

  return {
    database: fingerprintDatabase(dbPath),
    walExists,
    walSize,
  };
}

function sameReadOnlyFileState(left: ReadOnlyFileState, right: ReadOnlyFileState): boolean {
  return left.database.size === right.database.size &&
    left.database.mtimeNs === right.database.mtimeNs &&
    left.database.ctimeNs === right.database.ctimeNs &&
    left.database.ino === right.database.ino &&
    left.database.headerHash === right.database.headerHash &&
    left.walExists === right.walExists &&
    left.walSize === right.walSize;
}

export interface SqliteStatement {
  run(...params: any[]): { changes: number; lastInsertRowid: number | bigint };
  get(...params: any[]): any;
  all(...params: any[]): any[];
}

export interface SqliteDatabase {
  prepare(sql: string): SqliteStatement;
  exec(sql: string): void;
  pragma(str: string, options?: { simple?: boolean }): any;
  transaction<T>(fn: (...args: any[]) => T): (...args: any[]) => T;
  close(): void;
  readonly open: boolean;
}

/**
 * The active SQLite backend. Only one now (`node:sqlite`); kept as a named type
 * so `context-thread status` and the per-instance reporting have a stable shape.
 */
export type SqliteBackend = 'node-sqlite';

/**
 * Wraps Node's built-in `node:sqlite` (`DatabaseSync`) to match the
 * better-sqlite3 interface the rest of the code expects.
 *
 * node:sqlite is real SQLite compiled into Node, so it supports WAL, FTS5,
 * mmap, and `@named` params natively — the only shims needed are the
 * better-sqlite3 conveniences node:sqlite omits: a `.pragma()` helper, a
 * `.transaction()` helper, and `open` (node:sqlite exposes `isOpen`).
 */
class NodeSqliteAdapter implements SqliteDatabase {
  private _db: any;

  constructor(dbPath: string, readOnly: boolean) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    if (!readOnly) {
      this._db = new DatabaseSync(dbPath);
      return;
    }

    const target = `${pathToFileURL(dbPath).href}?mode=ro&immutable=1`;
    for (let attempt = 1; attempt <= READ_ONLY_OPEN_ATTEMPTS; attempt++) {
      const before = captureReadOnlyFileState(dbPath);
      const candidate = new DatabaseSync(target, { readOnly: true });
      let after: ReadOnlyFileState;
      try {
        after = captureReadOnlyFileState(dbPath);
      } catch (error) {
        candidate.close();
        throw error;
      }

      if (sameReadOnlyFileState(before, after)) {
        this._db = candidate;
        return;
      }
      candidate.close();
    }

    throw new ConfigError(
      `Database changed while establishing a zero-write read-only view after ${READ_ONLY_OPEN_ATTEMPTS} attempts.`,
      { dbPath }
    );
  }

  get open(): boolean {
    return this._db.isOpen;
  }

  prepare(sql: string): SqliteStatement {
    // node:sqlite matches better-sqlite3's calling convention (variadic
    // positional args, or a single object for @named params), so params forward
    // through unchanged.
    const stmt = this._db.prepare(sql);
    return {
      run(...params: any[]) {
        const r = stmt.run(...params);
        return {
          changes: Number(r?.changes ?? 0),
          lastInsertRowid: r?.lastInsertRowid ?? 0,
        };
      },
      get(...params: any[]) {
        return stmt.get(...params);
      },
      all(...params: any[]) {
        return stmt.all(...params);
      },
    };
  }

  exec(sql: string): void {
    this._db.exec(sql);
  }

  pragma(str: string, options?: { simple?: boolean }): any {
    const trimmed = str.trim();
    // Write pragma ("key = value"): node:sqlite is real SQLite, so every pragma
    // (WAL, mmap, synchronous, …) applies as-is.
    if (trimmed.includes('=')) {
      this._db.exec(`PRAGMA ${trimmed}`);
      return;
    }
    // Read pragma. Default: the row object (e.g. { journal_mode: 'wal' }).
    // `{ simple: true }` returns just the single column value, like better-sqlite3.
    const row = this._db.prepare(`PRAGMA ${trimmed}`).get();
    if (options?.simple) {
      return row && typeof row === 'object' ? Object.values(row)[0] : row;
    }
    return row;
  }

  transaction<T>(fn: (...args: any[]) => T): (...args: any[]) => T {
    return (...args: any[]) => {
      this._db.exec('BEGIN');
      try {
        const result = fn(...args);
        this._db.exec('COMMIT');
        return result;
      } catch (error) {
        this._db.exec('ROLLBACK');
        throw error;
      }
    };
  }

  close(): void {
    // node:sqlite's DatabaseSync.close() throws if already closed; make it
    // idempotent to match better-sqlite3 (callers may close more than once).
    if (this._db.isOpen) this._db.close();
  }
}

/**
 * Create a database connection backed by `node:sqlite`.
 *
 * Returns the active backend alongside the db so each `DatabaseConnection` can
 * report it per-instance — MCP can open multiple project DBs in one process, so
 * a process-global would race.
 */
export function createDatabase(
  dbPath: string,
  options: { readOnly?: boolean } = {}
): { db: SqliteDatabase; backend: SqliteBackend } {
  try {
    return { db: new NodeSqliteAdapter(dbPath, options.readOnly ?? false), backend: 'node-sqlite' };
  } catch (error) {
    if (error instanceof ConfigError) throw error;
    const msg = error instanceof Error ? error.message : String(error);
    throw new Error(
      'Failed to open SQLite via the built-in node:sqlite module.\n' +
      'ContextThread requires node:sqlite (Node.js 22.19+). Install the self-contained\n' +
      'ContextThread release (it bundles a compatible Node), or run on Node 22.19+.\n' +
      `Underlying error: ${msg}`
    );
  }
}

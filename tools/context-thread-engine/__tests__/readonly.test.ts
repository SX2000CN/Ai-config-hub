import { createHash } from 'crypto';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, unlinkSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread, { ConfigError } from '../src';

async function expectConfigError(operation: () => unknown | Promise<unknown>): Promise<void> {
  try {
    await operation();
    throw new Error('Expected a CONFIG_ERROR');
  } catch (error) {
    expect(error).toBeInstanceOf(ConfigError);
    expect((error as ConfigError).code).toBe('CONFIG_ERROR');
  }
}

function snapshotDirectory(directory: string): Record<string, { size: number; hash: string }> {
  return Object.fromEntries(readdirSync(directory).sort().map((name) => {
    const filePath = join(directory, name);
    return [name, {
      size: statSync(filePath).size,
      hash: createHash('sha256').update(readFileSync(filePath)).digest('hex'),
    }];
  }));
}

function readOnlyTempEntries(): string[] {
  return readdirSync(tmpdir())
    .filter((name) => name.startsWith('context-thread-readonly-'))
    .sort();
}

describe('read-only ContextThread connections', () => {
  const projects: string[] = [];
  const contexts: ContextThread[] = [];

  afterEach(() => {
    for (const context of contexts.splice(0)) {
      try { context.close(); } catch { /* already closed */ }
    }
    for (const project of projects.splice(0)) {
      rmSync(project, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });

  it('supports queries but rejects every public write operation and watch', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');

    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    const context = await ContextThread.open(projectRoot, { readOnly: true });
    contexts.push(context);
    expect(context.searchNodes('alpha')).toHaveLength(1);
    expect(context.getChangedFiles()).toEqual({ added: [], modified: [], removed: [] });

    await expectConfigError(() => context.indexAll());
    await expectConfigError(() => context.indexFiles(['main.ts']));
    await expectConfigError(() => context.sync());
    await expectConfigError(() => context.resolveReferencesBatched());
    await expectConfigError(() => context.resolveReferences());
    await expectConfigError(() => context.watch());
    await expectConfigError(() => context.optimize());
    await expectConfigError(() => context.clear());
    await expectConfigError(() => context.uninitialize());
    await expectConfigError(() => context.setContentMode('rich'));
    await expectConfigError(() => context.setDatabaseTracking(true));

    const queries = (context as unknown as {
      queries: { setMetadata(key: string, value: string): void };
    }).queries;
    expect(() => queries.setMetadata('read_only_probe', 'blocked')).toThrow();
    expect(context.searchNodes('alpha')).toHaveLength(1);
  });

  it('supports read-only openSync and rejects sync-on-open', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-sync-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    const databasePath = join(projectRoot, '.Ai-config', 'context-thread', 'context-thread.db');
    const rawDb = new DatabaseSync(databasePath);
    rawDb.prepare('UPDATE schema_versions SET version = 3 WHERE version = 5').run();
    rawDb.close();

    const context = ContextThread.openSync(projectRoot, { readOnly: true });
    contexts.push(context);
    expect(context.searchNodes('alpha')).toHaveLength(1);
    const connection = (context as unknown as {
      db: { getSchemaVersion(): { version: number } | null };
    }).db;
    expect(connection.getSchemaVersion()?.version).toBe(3);

    await expectConfigError(() => ContextThread.open(projectRoot, {
      readOnly: true,
      sync: true,
    }));
  });

  it('does not repair directory files or mutate the database during read-only validation', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-zero-write-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    const dataDir = join(projectRoot, '.Ai-config', 'context-thread');
    const gitignorePath = join(dataDir, '.gitignore');
    const databasePath = join(dataDir, 'context-thread.db');
    unlinkSync(gitignorePath);
    const beforeFiles = readdirSync(dataDir).sort();
    const beforeMtime = statSync(databasePath).mtimeMs;
    const beforeTemp = readOnlyTempEntries();

    const context = await ContextThread.open(projectRoot, { readOnly: true });
    expect(context.searchNodes('alpha')).toHaveLength(1);
    expect(context.getJournalMode()).toBe('wal');
    expect(context.getPrivacyStatus().contentMode).toBe('structure');
    context.close();

    expect(existsSync(gitignorePath)).toBe(false);
    expect(readdirSync(dataDir).sort()).toEqual(beforeFiles);
    expect(statSync(databasePath).mtimeMs).toBe(beforeMtime);
    expect(readOnlyTempEntries()).toEqual(beforeTemp);
  });

  it('fails explicitly on committed WAL frames without touching project or temp files', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-wal-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    const dataDir = join(projectRoot, '.Ai-config', 'context-thread');
    const databasePath = join(dataDir, 'context-thread.db');
    const writer = new DatabaseSync(databasePath);
    writer.exec('PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0;');
    writer.prepare("UPDATE nodes SET name = 'beta', qualified_name = 'beta' WHERE name = 'alpha'").run();

    const beforeDirectory = snapshotDirectory(dataDir);
    const beforeTemp = readOnlyTempEntries();
    try {
      await expectConfigError(() => ContextThread.open(projectRoot, { readOnly: true }));
      expect(snapshotDirectory(dataDir)).toEqual(beforeDirectory);
      expect(readOnlyTempEntries()).toEqual(beforeTemp);
    } finally {
      writer.close();
    }
  });

  it('fails explicitly on a non-empty rollback journal without touching project or temp files', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-journal-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    const dataDir = join(projectRoot, '.Ai-config', 'context-thread');
    const journalPath = join(dataDir, 'context-thread.db-journal');
    writeFileSync(journalPath, 'active rollback journal', 'utf-8');
    const beforeDirectory = snapshotDirectory(dataDir);
    const beforeTemp = readOnlyTempEntries();

    await expectConfigError(() => ContextThread.open(projectRoot, { readOnly: true }));
    expect(snapshotDirectory(dataDir)).toEqual(beforeDirectory);
    expect(readOnlyTempEntries()).toEqual(beforeTemp);
  });

  it('fingerprints only the SQLite header instead of reading a large database in full', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-readonly-header-'));
    projects.push(projectRoot);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    const writable = await ContextThread.init(projectRoot, { index: true });
    writable.close();

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const nodeFs = require('fs') as typeof import('fs');
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    const databasePath = join(projectRoot, '.Ai-config', 'context-thread', 'context-thread.db');
    const raw = new DatabaseSync(databasePath);
    raw.exec('CREATE TABLE readonly_padding (payload BLOB);');
    raw.prepare('INSERT INTO readonly_padding(payload) VALUES (zeroblob(?))').run(2 * 1024 * 1024);
    raw.exec('PRAGMA wal_checkpoint(TRUNCATE); VACUUM;');
    raw.close();
    expect(statSync(databasePath).size).toBeGreaterThan(1024 * 1024);

    const originalReadSync = nodeFs.readSync;
    let maximumRequested = 0;
    let totalRequested = 0;
    nodeFs.readSync = ((...args: Parameters<typeof nodeFs.readSync>) => {
      const requested = typeof args[3] === 'number' ? args[3] : 0;
      maximumRequested = Math.max(maximumRequested, requested);
      totalRequested += requested;
      return originalReadSync(...args);
    }) as typeof nodeFs.readSync;

    try {
      const context = ContextThread.openSync(projectRoot, { readOnly: true });
      expect(context.searchNodes('alpha')).toHaveLength(1);
      context.close();
    } finally {
      nodeFs.readSync = originalReadSync;
    }

    expect(maximumRequested).toBeLessThanOrEqual(100);
    expect(totalRequested).toBeLessThanOrEqual(200);
  });
});

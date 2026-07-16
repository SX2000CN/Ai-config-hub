import { createHash } from 'crypto';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread, { CONTENT_MODE_METADATA_KEY, getDatabasePath } from '../src';
import type { Edge, Node, UnresolvedReference } from '../src';

type RawDatabase = {
  exec(sql: string): void;
  prepare(sql: string): {
    run(...params: unknown[]): unknown;
    get(...params: unknown[]): Record<string, unknown> | undefined;
    all(...params: unknown[]): Array<Record<string, unknown>>;
  };
  close(): void;
};

function openRawDatabase(projectRoot: string): RawDatabase {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { DatabaseSync } = require('node:sqlite');
  return new DatabaseSync(getDatabasePath(projectRoot)) as RawDatabase;
}

function createProject(source: string): string {
  const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-content-mode-'));
  writeFileSync(join(projectRoot, 'main.ts'), source, 'utf-8');
  return projectRoot;
}

function privacyBackupTempEntries(projectRoot: string): string[] {
  const databaseId = createHash('sha256')
    .update(getDatabasePath(projectRoot))
    .digest('hex')
    .slice(0, 12);
  const prefix = `context-thread-privacy-backup-${databaseId}-`;
  return readdirSync(tmpdir())
    .filter((name) => name.startsWith(prefix))
    .sort();
}

function getQueries(context: ContextThread): {
  updateNode(node: Node): void;
  insertEdge(edge: Edge): void;
  insertUnresolvedRef(ref: UnresolvedReference): void;
  getMetadata(key: string): string | null;
} {
  return (context as unknown as { queries: ReturnType<typeof getQueries> }).queries;
}

describe('content persistence policies', () => {
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

  it('defaults new indexes to structure and filters optional payloads at every write boundary', async () => {
    const projectRoot = createProject(
      'export function alpha(value: PrivateSignatureType): string { return String(value); }\n' +
      'export function beta(): void {}\n'
    );
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    expect(context.getPrivacyStatus()).toMatchObject({
      contentMode: 'structure',
      contentModeLabel: 'structure',
      legacyRich: false,
      databaseIgnored: true,
    });

    const nodes = context.getNodesInFile('main.ts');
    const alpha = nodes.find((node) => node.name === 'alpha')!;
    const beta = nodes.find((node) => node.name === 'beta')!;
    const queries = getQueries(context);
    queries.updateNode({
      ...alpha,
      docstring: 'PRIVATE_DOCSTRING_MARKER',
      signature: '(value: PRIVATE_SIGNATURE_MARKER): string',
      decorators: ['PRIVATE_DECORATOR_MARKER'],
      typeParameters: ['PRIVATE_TYPE_PARAMETER_MARKER'],
    });
    queries.insertEdge({
      source: alpha.id,
      target: beta.id,
      kind: 'calls',
      metadata: { marker: 'PRIVATE_EDGE_MARKER' },
      line: 7,
      column: 9,
      provenance: 'heuristic',
    });
    queries.insertUnresolvedRef({
      fromNodeId: alpha.id,
      referenceName: 'beta',
      referenceKind: 'calls',
      line: 7,
      column: 9,
      candidates: ['PRIVATE_CANDIDATE_MARKER'],
      filePath: 'main.ts',
      language: 'typescript',
    });

    const raw = openRawDatabase(projectRoot);
    const nodeRow = raw.prepare(
      'SELECT docstring, signature, decorators, type_parameters FROM nodes WHERE id = ?'
    ).get(alpha.id)!;
    const edgeRow = raw.prepare(
      'SELECT metadata, kind, line, col, provenance FROM edges WHERE source = ? AND target = ? AND line = 7'
    ).get(alpha.id, beta.id)!;
    const unresolvedRow = raw.prepare(
      'SELECT candidates FROM unresolved_refs WHERE from_node_id = ? AND line = 7'
    ).get(alpha.id)!;
    raw.close();

    expect(nodeRow).toMatchObject({
      docstring: null,
      signature: null,
      decorators: null,
      type_parameters: null,
    });
    expect(edgeRow).toMatchObject({
      metadata: null,
      kind: 'calls',
      line: 7,
      col: 9,
      provenance: 'heuristic',
    });
    expect(unresolvedRow.candidates).toBeNull();
    expect(context.searchNodes('PRIVATE_SIGNATURE_MARKER')).toEqual([]);
  });

  it('migrates persistent guards that sanitize legacy rich writes in structure mode', async () => {
    const projectRoot = createProject(
      '/** LEGACYDOCMARKERXYZ */\n' +
      'export function alpha(value: LEGACYSIGMARKERXYZ): string { return String(value); }\n' +
      'export function beta(): void {}\n'
    );
    projects.push(projectRoot);
    const initial = await ContextThread.init(projectRoot, { index: true, contentMode: 'structure' });
    contexts.push(initial);
    initial.close();

    const beforeMigration = openRawDatabase(projectRoot);
    for (const triggerName of [
      'structure_guard_nodes_insert',
      'structure_guard_nodes_update',
      'structure_guard_edges_insert',
      'structure_guard_edges_update',
      'structure_guard_refs_insert',
      'structure_guard_refs_update',
    ]) {
      beforeMigration.exec(`DROP TRIGGER IF EXISTS ${triggerName}`);
    }
    beforeMigration.prepare('UPDATE schema_versions SET version = 4 WHERE version = 5').run();
    beforeMigration.close();

    const context = await ContextThread.open(projectRoot);
    contexts.push(context);
    const alpha = context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')!;
    const beta = context.getNodesInFile('main.ts').find((node) => node.name === 'beta')!;

    const raw = openRawDatabase(projectRoot);
    const guardCount = raw.prepare(
      "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'structure_guard_%'"
    ).get() as { count: number };
    expect(guardCount.count).toBe(6);

    raw.prepare(`
      UPDATE nodes SET
        docstring = ?, signature = ?, decorators = ?, type_parameters = ?
      WHERE id = ?
    `).run('LEGACYDOCMARKERXYZ', '(value: LEGACYSIGMARKERXYZ)', '["legacy"]', '["Legacy"]', alpha.id);

    raw.prepare(`
      INSERT OR REPLACE INTO nodes (
        id, kind, name, qualified_name, file_path, language,
        start_line, end_line, start_column, end_column,
        docstring, signature, visibility,
        is_exported, is_async, is_static, is_abstract,
        decorators, type_parameters, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      'legacy-node', 'function', 'legacyAlpha', 'legacyAlpha', 'main.ts', 'typescript',
      1, 1, 0, 1,
      'LEGACYDOCMARKERXYZ', '(value: LEGACYSIGMARKERXYZ)', 'public',
      1, 0, 0, 0,
      '["legacy"]', '["Legacy"]', Date.now()
    );

    raw.prepare(`
      INSERT OR IGNORE INTO edges (source, target, kind, metadata, line, col, provenance)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(alpha.id, beta.id, 'calls', '{"marker":"LEGACYEDGEMARKERXYZ"}', 1, 0, 'legacy');

    raw.prepare(`
      INSERT INTO unresolved_refs (
        from_node_id, reference_name, reference_kind,
        line, col, candidates, file_path, language
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(alpha.id, 'missingLegacy', 'calls', 1, 0, '["LEGACYREFMARKERXYZ"]', 'main.ts', 'typescript');

    const richNodes = raw.prepare(`
      SELECT COUNT(*) AS count FROM nodes
      WHERE docstring IS NOT NULL OR signature IS NOT NULL
         OR decorators IS NOT NULL OR type_parameters IS NOT NULL
    `).get() as { count: number };
    const richEdges = raw.prepare('SELECT COUNT(*) AS count FROM edges WHERE metadata IS NOT NULL').get() as { count: number };
    const richRefs = raw.prepare('SELECT COUNT(*) AS count FROM unresolved_refs WHERE candidates IS NOT NULL').get() as { count: number };
    const docMatches = raw.prepare("SELECT COUNT(*) AS count FROM nodes_fts WHERE nodes_fts MATCH 'LEGACYDOCMARKERXYZ'").get() as { count: number };
    const signatureMatches = raw.prepare("SELECT COUNT(*) AS count FROM nodes_fts WHERE nodes_fts MATCH 'LEGACYSIGMARKERXYZ'").get() as { count: number };
    raw.close();

    expect(richNodes.count).toBe(0);
    expect(richEdges.count).toBe(0);
    expect(richRefs.count).toBe(0);
    expect(docMatches.count).toBe(0);
    expect(signatureMatches.count).toBe(0);
  });

  it('preserves rich payloads only when rich is explicitly selected', async () => {
    const projectRoot = createProject(
      '/** RICH_DOC_MARKER */\n' +
      'export function alpha(value: RichSignatureMarker): string { return String(value); }\n'
    );
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true, contentMode: 'rich' });
    contexts.push(context);

    const alpha = context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')!;
    expect(context.getPrivacyStatus()).toMatchObject({
      contentMode: 'rich',
      contentModeLabel: 'rich',
      legacyRich: false,
    });
    expect(alpha.signature).toContain('RichSignatureMarker');

    const queries = getQueries(context);
    queries.updateNode({
      ...alpha,
      docstring: 'RICH_DOC_PERSISTED',
      decorators: ['RICH_DECORATOR_PERSISTED'],
      typeParameters: ['RICH_TYPE_PARAMETER_PERSISTED'],
    });

    const raw = openRawDatabase(projectRoot);
    const row = raw.prepare(
      'SELECT docstring, signature, decorators, type_parameters FROM nodes WHERE id = ?'
    ).get(alpha.id)!;
    raw.close();
    expect(row.docstring).toBe('RICH_DOC_PERSISTED');
    expect(row.signature).toContain('RichSignatureMarker');
    expect(row.decorators).toContain('RICH_DECORATOR_PERSISTED');
    expect(row.type_parameters).toContain('RICH_TYPE_PARAMETER_PERSISTED');
  });

  it('reports databases without metadata as legacy-rich without silently migrating them', async () => {
    const projectRoot = createProject('export function alpha(): void {}\n');
    projects.push(projectRoot);
    const initialized = await ContextThread.init(projectRoot, { index: true, contentMode: 'rich' });
    initialized.close();

    const raw = openRawDatabase(projectRoot);
    raw.prepare('DELETE FROM project_metadata WHERE key = ?').run(CONTENT_MODE_METADATA_KEY);
    raw.close();

    const context = await ContextThread.open(projectRoot);
    contexts.push(context);
    expect(context.getPrivacyStatus()).toMatchObject({
      contentMode: 'rich',
      contentModeLabel: 'legacy-rich',
      legacyRich: true,
    });
    await context.sync();
    expect(getQueries(context).getMetadata(CONTENT_MODE_METADATA_KEY)).toBeNull();
  });

  it('scrubs rich bytes, rebuilds FTS, and preserves structural relationship fields', async () => {
    const marker = 'PERSISTED_PRIVATE_MARKER_6F1D4A';
    const projectRoot = createProject(
      `export function alpha(value: ${marker}): string { return String(value); }\n` +
      'export function beta(): void {}\n'
    );
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true, contentMode: 'rich' });
    contexts.push(context);

    const nodes = context.getNodesInFile('main.ts');
    const alpha = nodes.find((node) => node.name === 'alpha')!;
    const beta = nodes.find((node) => node.name === 'beta')!;
    const queries = getQueries(context);
    queries.updateNode({ ...alpha, docstring: marker, signature: `(${marker}): string` });
    queries.insertEdge({
      source: alpha.id,
      target: beta.id,
      kind: 'calls',
      metadata: { marker },
      line: 11,
      column: 13,
      provenance: 'heuristic',
    });
    queries.insertUnresolvedRef({
      fromNodeId: alpha.id,
      referenceName: 'beta',
      referenceKind: 'calls',
      line: 11,
      column: 13,
      candidates: [marker],
      filePath: 'main.ts',
      language: 'typescript',
    });
    expect(context.searchNodes(marker).length).toBeGreaterThan(0);

    const transition = await context.setContentMode('structure');
    expect(transition).toMatchObject({
      previousMode: 'rich',
      contentMode: 'structure',
      rebuilt: false,
    });
    expect(context.searchNodes(marker)).toEqual([]);

    const raw = openRawDatabase(projectRoot);
    const nodeRow = raw.prepare(
      'SELECT docstring, signature, decorators, type_parameters FROM nodes WHERE id = ?'
    ).get(alpha.id)!;
    const edgeRow = raw.prepare(
      'SELECT metadata, kind, line, col, provenance FROM edges WHERE source = ? AND target = ? AND line = 11'
    ).get(alpha.id, beta.id)!;
    const unresolvedRow = raw.prepare(
      'SELECT candidates FROM unresolved_refs WHERE from_node_id = ? AND line = 11'
    ).get(alpha.id)!;
    raw.close();
    expect(Object.values(nodeRow)).toEqual([null, null, null, null]);
    expect(edgeRow).toMatchObject({
      metadata: null,
      kind: 'calls',
      line: 11,
      col: 13,
      provenance: 'heuristic',
    });
    expect(unresolvedRow.candidates).toBeNull();

    context.close();
    contexts.splice(contexts.indexOf(context), 1);
    const dataDir = join(projectRoot, '.Ai-config', 'context-thread');
    for (const file of readdirSync(dataDir).filter((name) => name.startsWith('context-thread.db'))) {
      const filePath = join(dataDir, file);
      if (existsSync(filePath)) {
        expect(readFileSync(filePath).includes(Buffer.from(marker))).toBe(false);
      }
    }
  });

  it('keeps rich data unchanged when an active reader prevents WAL-safe scrubbing', async () => {
    const marker = 'BUSY_WAL_PRIVATE_MARKER_4C19D2';
    const projectRoot = createProject('export function alpha(): void {}\n');
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true, contentMode: 'rich' });
    contexts.push(context);

    const alpha = context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')!;
    getQueries(context).updateNode({ ...alpha, docstring: marker, signature: `(): ${marker}` });

    const databasePath = getDatabasePath(projectRoot);
    // Keep the failure test fast instead of waiting for the production 5s busy timeout.
    const internalDb = (context as unknown as {
      db: { getDb(): { pragma(value: string): unknown } };
    }).db.getDb();
    internalDb.pragma('busy_timeout = 50');

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    const reader = new DatabaseSync(databasePath, { readOnly: true });
    reader.exec('BEGIN');
    reader.prepare("SELECT docstring FROM nodes WHERE name = 'alpha'").get();
    const beforeTemp = privacyBackupTempEntries(projectRoot);
    try {
      await expect(context.setContentMode('structure')).rejects.toThrow(/WAL is busy/);
      expect(context.getPrivacyStatus().contentMode).toBe('rich');
      expect(context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')?.docstring)
        .toBe(marker);
      expect(privacyBackupTempEntries(projectRoot)).toEqual(beforeTemp);
    } finally {
      reader.exec('ROLLBACK');
      reader.close();
    }

    const retry = await context.setContentMode('structure');
    expect(retry.contentMode).toBe('structure');
    expect(context.getPrivacyStatus().contentMode).toBe('structure');
    expect(privacyBackupTempEntries(projectRoot)).toEqual(beforeTemp);

    const dataDir = join(projectRoot, '.Ai-config', 'context-thread');
    for (const name of readdirSync(dataDir)) {
      const filePath = join(dataDir, name);
      if (!existsSync(filePath) || !name.startsWith('context-thread.db')) continue;
      expect(readFileSync(filePath).includes(Buffer.from(marker))).toBe(false);
      expect(name).not.toContain('privacy-backup');
    }
  });

  it('fully rebuilds when upgrading structure to rich', async () => {
    const projectRoot = createProject(
      'export function alpha(value: RebuildSignatureMarker): string { return String(value); }\n'
    );
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);
    expect(context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')?.signature).toBeUndefined();

    const transition = await context.setContentMode('rich');
    expect(transition.rebuilt).toBe(true);
    expect(transition.contentMode).toBe('rich');
    expect(transition.indexResult?.success).toBe(true);
    expect(
      context.getNodesInFile('main.ts').find((node) => node.name === 'alpha')?.signature
    ).toContain('RebuildSignatureMarker');
  });

  it('preserves the structure graph when a rich rebuild is aborted', async () => {
    const projectRoot = createProject(
      'export function alpha(): void { beta(); }\n' +
      'export function beta(): void {}\n'
    );
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    const nodes = context.getNodesInFile('main.ts');
    const alpha = nodes.find((node) => node.name === 'alpha')!;
    const beta = nodes.find((node) => node.name === 'beta')!;
    getQueries(context).insertEdge({
      source: alpha.id,
      target: beta.id,
      kind: 'calls',
      line: 99,
      column: 1,
      provenance: 'heuristic',
    });

    const beforeFiles = context.getFiles();
    const beforeNodes = context.getNodesInFile('main.ts');
    const beforeEdges = context.getOutgoingEdges(alpha.id);
    const controller = new AbortController();
    controller.abort();

    const transition = await context.setContentMode('rich', { signal: controller.signal });
    expect(transition).toMatchObject({
      contentMode: 'structure',
      rebuilt: true,
      indexResult: { success: false },
    });
    expect(context.getPrivacyStatus().contentMode).toBe('structure');
    expect(context.getFiles()).toEqual(beforeFiles);
    expect(context.getNodesInFile('main.ts')).toEqual(beforeNodes);
    expect(context.getOutgoingEdges(alpha.id)).toEqual(beforeEdges);
  });
});

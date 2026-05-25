import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread from '../src';

describe('ContextThread sync', () => {
  const projects: string[] = [];

  afterEach(() => {
    for (const project of projects.splice(0)) {
      rmSync(project, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });

  it('re-indexes unchanged dependents when a target file changes', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-sync-'));
    projects.push(projectRoot);

    writeFileSync(
      join(projectRoot, 'producer.ts'),
      'export function target() { return 1; }\n',
      'utf-8'
    );
    writeFileSync(
      join(projectRoot, 'consumer.ts'),
      'import { target } from "./producer";\nexport function consumer() { return target(); }\n',
      'utf-8'
    );

    const cg = await ContextThread.init(projectRoot, { index: true });
    const before = cg.getCallees(cg.searchNodes('consumer')[0]!.node.id);
    expect(before.map((entry) => entry.node.name)).toContain('target');

    writeFileSync(
      join(projectRoot, 'producer.ts'),
      'export function renamedTarget() { return 1; }\n',
      'utf-8'
    );

    const result = await cg.sync();

    expect(result.changedFilePaths).toContain('producer.ts');
    expect(result.changedFilePaths).toContain('consumer.ts');
    expect(result.filesModified).toBeGreaterThanOrEqual(2);
    expect(cg.searchNodes('target').map((entry) => entry.node.name)).not.toContain('target');

    const after = cg.getCallees(cg.searchNodes('consumer')[0]!.node.id);
    expect(after.map((entry) => entry.node.name)).not.toContain('target');

    cg.close();
  });
});

import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread from '../src';

describe('search filter composition', () => {
  const projects: string[] = [];
  const contexts: ContextThread[] = [];

  afterEach(() => {
    for (const context of contexts.splice(0)) context.close();
    for (const project of projects.splice(0)) {
      rmSync(project, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });

  it('intersects query kind/lang filters with SearchOptions', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-search-filters-'));
    projects.push(projectRoot);
    writeFileSync(
      join(projectRoot, 'symbols.ts'),
      'export function tsFunction() { return 1; }\nexport class TsClass {}\n',
      'utf-8'
    );
    writeFileSync(join(projectRoot, 'symbols.py'), 'def py_function():\n    return 1\n', 'utf-8');

    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    expect(context.searchNodes('kind:function', { kinds: ['class'] })).toEqual([]);
    expect(context.searchNodes('lang:typescript', { languages: ['python'] })).toEqual([]);

    const kindOverlap = context.searchNodes('kind:function', {
      kinds: ['function', 'class'],
    });
    expect(kindOverlap.length).toBeGreaterThan(0);
    expect(kindOverlap.every((result) => result.node.kind === 'function')).toBe(true);

    const languageOverlap = context.searchNodes('lang:typescript', {
      languages: ['typescript', 'python'],
    });
    expect(languageOverlap.length).toBeGreaterThan(0);
    expect(languageOverlap.every((result) => result.node.language === 'typescript')).toBe(true);
  });
});

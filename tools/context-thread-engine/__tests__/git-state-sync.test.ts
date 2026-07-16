import { execFileSync } from 'child_process';
import { createHash } from 'crypto';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, unlinkSync, utimesSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread, { getDatabasePath } from '../src';

function git(projectRoot: string, args: string[]): string {
  return execFileSync('git', args, {
    cwd: projectRoot,
    encoding: 'utf-8',
    stdio: ['pipe', 'pipe', 'pipe'],
  }).trim();
}

function createGitProject(source = 'export function alpha() { return 1; }\n'): string {
  const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-git-state-'));
  git(projectRoot, ['init']);
  git(projectRoot, ['config', 'user.email', 'context-thread@example.test']);
  git(projectRoot, ['config', 'user.name', 'ContextThread Tests']);
  writeFileSync(join(projectRoot, 'main.ts'), source, 'utf-8');
  git(projectRoot, ['add', 'main.ts']);
  git(projectRoot, ['commit', '-m', 'initial']);
  return projectRoot;
}

describe('git_state_v1 incremental sync', () => {
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

  it('full-scans after switching to a clean branch', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const originalBranch = git(projectRoot, ['branch', '--show-current']);

    git(projectRoot, ['switch', '-c', 'alternate']);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function beta() { return 2; }\n', 'utf-8');
    git(projectRoot, ['add', 'main.ts']);
    git(projectRoot, ['commit', '-m', 'alternate source']);
    git(projectRoot, ['switch', originalBranch]);

    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);
    expect(context.searchNodes('alpha')).toHaveLength(1);

    git(projectRoot, ['switch', 'alternate']);
    const result = await context.sync();

    expect(result.filesChecked).toBeGreaterThan(0);
    expect(context.searchNodes('alpha')).toHaveLength(0);
    expect(context.searchNodes('beta')).toHaveLength(1);
  });

  it('reconciles files removed by a clean branch switch during indexAll', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const originalBranch = git(projectRoot, ['branch', '--show-current']);

    git(projectRoot, ['switch', '-c', 'replacement']);
    unlinkSync(join(projectRoot, 'main.ts'));
    writeFileSync(join(projectRoot, 'replacement.ts'), 'export function replacement() { return 9; }\n', 'utf-8');
    git(projectRoot, ['add', '-A']);
    git(projectRoot, ['commit', '-m', 'replace source file']);
    git(projectRoot, ['switch', originalBranch]);

    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);
    expect(context.searchNodes('alpha')).toHaveLength(1);

    git(projectRoot, ['switch', 'replacement']);
    const result = await context.indexAll();
    expect(result.success).toBe(true);
    expect(context.getFiles().map((file) => file.path)).toEqual(['replacement.ts']);
    expect(context.searchNodes('alpha')).toHaveLength(0);
    expect(
      context.searchNodes('replacement').some((entry) => entry.node.name === 'replacement')
    ).toBe(true);

    const sync = await context.sync();
    expect(sync.filesChecked).toBe(0);
    expect(context.searchNodes('alpha')).toHaveLength(0);
  });

  it('full-scans after a dirty change is committed before sync', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    writeFileSync(join(projectRoot, 'main.ts'), 'export function committed() { return 3; }\n', 'utf-8');
    git(projectRoot, ['add', 'main.ts']);
    git(projectRoot, ['commit', '-m', 'committed source']);

    const result = await context.sync();
    expect(result.filesChecked).toBeGreaterThan(0);
    expect(context.searchNodes('alpha')).toHaveLength(0);
    expect(context.searchNodes('committed')).toHaveLength(1);
  });

  it('rehashes a previously dirty tracked file after it is reverted', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    writeFileSync(join(projectRoot, 'main.ts'), 'export function dirty() { return 4; }\n', 'utf-8');
    await context.sync();
    expect(context.searchNodes('dirty')).toHaveLength(1);

    git(projectRoot, ['restore', 'main.ts']);
    const result = await context.sync();

    expect(result.filesModified).toBeGreaterThanOrEqual(1);
    expect(context.searchNodes('dirty')).toHaveLength(0);
    expect(context.searchNodes('alpha')).toHaveLength(1);
  });

  it('loads grammars for indexFiles and invalidates the Git baseline after targeted writes', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    writeFileSync(join(projectRoot, 'main.ts'), 'export function targetedDirty() { return 10; }\n', 'utf-8');
    const indexed = await context.indexFiles(['main.ts']);
    expect(indexed.success).toBe(true);
    expect(context.searchNodes('targetedDirty')).toHaveLength(1);

    git(projectRoot, ['restore', 'main.ts']);
    expect(context.getChangedFiles()).toEqual({
      added: [],
      modified: ['main.ts'],
      removed: [],
    });
    await context.sync();
    expect(context.searchNodes('targetedDirty')).toHaveLength(0);
    expect(context.searchNodes('alpha')).toHaveLength(1);
  });

  it('removes a previously indexed untracked file after deletion', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);

    const extraPath = join(projectRoot, 'extra.ts');
    writeFileSync(extraPath, 'export function extra() { return 5; }\n', 'utf-8');
    await context.sync();
    expect(context.searchNodes('extra').some((result) => result.node.name === 'extra')).toBe(true);

    unlinkSync(extraPath);
    const result = await context.sync();

    expect(result.filesRemoved).toBe(1);
    expect(context.searchNodes('extra').some((entry) => entry.node.name === 'extra')).toBe(false);
  });

  it('backfills missing metadata only after a successful sync', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const initialized = await ContextThread.init(projectRoot, { index: true });
    initialized.close();

    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require('node:sqlite');
    const rawDb = new DatabaseSync(getDatabasePath(projectRoot));
    rawDb.prepare('DELETE FROM project_metadata WHERE key = ?').run('git_state_v1');
    rawDb.close();

    const context = ContextThread.openSync(projectRoot);
    contexts.push(context);
    const queries = (context as unknown as {
      queries: { getMetadata(key: string): string | null };
    }).queries;

    expect(queries.getMetadata('git_state_v1')).toBeNull();
    expect(context.getChangedFiles()).toEqual({ added: [], modified: [], removed: [] });
    expect(queries.getMetadata('git_state_v1')).toBeNull();

    const result = await context.sync();
    expect(result.filesChecked).toBeGreaterThan(0);
    const storedState = JSON.parse(queries.getMetadata('git_state_v1')!) as {
      head: string;
      dirtyPaths: string[];
    };
    expect(storedState).toEqual({
      head: git(projectRoot, ['rev-parse', '--verify', 'HEAD']),
      dirtyPaths: [],
    });
  });

  it('stores dirty paths relative to a project nested inside a git repository', async () => {
    const repositoryRoot = mkdtempSync(join(tmpdir(), 'context-thread-parent-repo-'));
    projects.push(repositoryRoot);
    const projectRoot = join(repositoryRoot, 'packages', 'app');
    mkdirSync(projectRoot, { recursive: true });
    git(repositoryRoot, ['init']);
    git(repositoryRoot, ['config', 'user.email', 'context-thread@example.test']);
    git(repositoryRoot, ['config', 'user.name', 'ContextThread Tests']);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function alpha() { return 1; }\n', 'utf-8');
    git(repositoryRoot, ['add', 'packages/app/main.ts']);
    git(repositoryRoot, ['commit', '-m', 'nested project']);

    const context = await ContextThread.init(projectRoot, { index: true });
    contexts.push(context);
    writeFileSync(join(projectRoot, 'main.ts'), 'export function nestedDirty() { return 2; }\n', 'utf-8');
    await context.sync();

    const queries = (context as unknown as {
      queries: { getMetadata(key: string): string | null };
    }).queries;
    const storedState = JSON.parse(queries.getMetadata('git_state_v1')!) as {
      dirtyPaths: string[];
    };
    expect(storedState.dirtyPaths).toEqual(['main.ts']);
    expect(context.searchNodes('nestedDirty')).toHaveLength(1);
  });

  it('does not refresh or rewrite the Git index during read-only status checks', async () => {
    const projectRoot = createGitProject();
    projects.push(projectRoot);
    const initialized = await ContextThread.init(projectRoot, { index: true });
    initialized.close();

    // Make the cached stat data stale without changing file content. A normal
    // `git status` refreshes and rewrites .git/index in this situation.
    const sourcePath = join(projectRoot, 'main.ts');
    const future = new Date(Date.now() + 5000);
    utimesSync(sourcePath, future, future);

    const gitIndexPath = join(projectRoot, '.git', 'index');
    const beforeHash = createHash('sha256').update(readFileSync(gitIndexPath)).digest('hex');
    const beforeMtime = statSync(gitIndexPath).mtimeMs;

    const context = await ContextThread.open(projectRoot, { readOnly: true });
    expect(context.getChangedFiles()).toEqual({ added: [], modified: [], removed: [] });
    context.close();

    expect(createHash('sha256').update(readFileSync(gitIndexPath)).digest('hex')).toBe(beforeHash);
    expect(statSync(gitIndexPath).mtimeMs).toBe(beforeMtime);
  });
});

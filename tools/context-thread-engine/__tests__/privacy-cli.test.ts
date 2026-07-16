import { execFileSync, spawnSync } from 'child_process';
import { mkdtempSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread from '../src';

const cliEntry = join(__dirname, '..', 'dist', 'bin', 'context-thread.js');

function runCli(args: string[]) {
  return spawnSync(process.execPath, [cliEntry, ...args], {
    encoding: 'utf-8',
    env: { ...process.env, CONTEXT_THREAD_ALLOW_UNSAFE_NODE: '1' },
  });
}

describe('privacy CLI and database tracking policy', () => {
  const projects: string[] = [];

  afterEach(() => {
    for (const project of projects.splice(0)) {
      rmSync(project, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });

  it('initSync defaults to structure and ignores the database', () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-init-sync-'));
    projects.push(projectRoot);
    const context = ContextThread.initSync(projectRoot);
    try {
      expect(context.getPrivacyStatus()).toMatchObject({
        contentMode: 'structure',
        contentModeLabel: 'structure',
        databaseIgnored: true,
      });
      expect(
        readFileSync(join(projectRoot, '.Ai-config', 'context-thread', '.gitignore'), 'utf-8')
      ).toMatch(/^context-thread\.db$/m);
    } finally {
      context.close();
    }
  });

  it('requires an explicit trackDb choice and reports actual Git tracking', () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-track-db-'));
    projects.push(projectRoot);
    execFileSync('git', ['init'], { cwd: projectRoot, stdio: 'ignore' });

    const context = ContextThread.initSync(projectRoot, { contentMode: 'rich', trackDb: true });
    try {
      const gitignore = readFileSync(
        join(projectRoot, '.Ai-config', 'context-thread', '.gitignore'),
        'utf-8'
      );
      expect(gitignore).not.toMatch(/^context-thread\.db$/m);
      expect(context.getPrivacyStatus()).toMatchObject({
        contentMode: 'rich',
        databaseIgnored: false,
        databaseTracked: false,
      });

      execFileSync('git', ['add', '.Ai-config/context-thread/context-thread.db'], {
        cwd: projectRoot,
        stdio: 'ignore',
      });
      expect(context.getPrivacyStatus().databaseTracked).toBe(true);
    } finally {
      context.close();
    }
  });

  it('exposes content and tracking policy through init, privacy, and status commands', () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-privacy-cli-'));
    projects.push(projectRoot);

    const init = runCli(['init', projectRoot, '--content-mode', 'rich', '--track-db']);
    expect(init.status, init.stderr).toBe(0);

    const privacy = runCli(['privacy', projectRoot, '--json']);
    expect(privacy.status, privacy.stderr).toBe(0);
    const privacyJson = JSON.parse(privacy.stdout.trim()) as Record<string, unknown>;
    expect(privacyJson).toMatchObject({
      contentMode: 'rich',
      contentModeLabel: 'rich',
      legacyRich: false,
      databaseIgnored: false,
    });

    const downgrade = runCli(['privacy', projectRoot, '--content-mode', 'structure', '--json']);
    expect(downgrade.status, downgrade.stderr).toBe(0);
    expect(JSON.parse(downgrade.stdout.trim())).toMatchObject({
      contentMode: 'structure',
      contentModeLabel: 'structure',
      changed: true,
    });

    const status = runCli(['status', projectRoot, '--json']);
    expect(status.status, status.stderr).toBe(0);
    expect(JSON.parse(status.stdout.trim())).toMatchObject({
      initialized: true,
      contentMode: 'structure',
      contentModeLabel: 'structure',
      databaseIgnored: false,
    });
  });

  it('rejects invalid content modes before initialization', () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-invalid-mode-'));
    projects.push(projectRoot);
    const result = runCli(['init', projectRoot, '--content-mode', 'everything']);
    expect(result.status).toBe(1);
    expect(result.stdout + result.stderr).toContain('Invalid content mode');
  });
});

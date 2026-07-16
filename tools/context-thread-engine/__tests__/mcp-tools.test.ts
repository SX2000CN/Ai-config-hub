import { mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { describe, expect, it, vi } from 'vitest';
import { ToolHandler } from '../src/mcp/tools';

describe('ToolHandler', () => {
  it('closes each cached project connection only once', () => {
    const handler = new ToolHandler(null);
    const close = vi.fn();
    const projectCache = (handler as unknown as {
      projectCache: Map<string, { close: () => void }>;
    }).projectCache;
    const connection = { close };

    projectCache.set('D:/repo', connection);
    projectCache.set('D:/repo/src', connection);

    handler.closeAll();

    expect(close).toHaveBeenCalledTimes(1);
    expect(projectCache.size).toBe(0);
  });

  it('reports the actual node and CLI entry path for an uninitialized project', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'context-thread-uninitialized-'));
    const originalArgv = process.argv;
    process.argv = ['C:\\runtime\\node.exe', 'C:\\runtime\\context-thread.js'];

    try {
      const handler = new ToolHandler(null);
      const result = await handler.execute('context_thread_status', { projectPath: projectRoot });
      const message = result.content[0]!.text;

      expect(result.isError).toBe(true);
      expect(message).toContain('context-thread is not a global command');
      expect(message).toContain('"C:\\runtime\\node.exe" "C:\\runtime\\context-thread.js" init');
      expect(message).toContain(`"${projectRoot}" --index`);
    } finally {
      process.argv = originalArgv;
      rmSync(projectRoot, { recursive: true, force: true });
    }
  });
});

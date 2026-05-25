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
});

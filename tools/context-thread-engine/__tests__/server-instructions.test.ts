import { describe, expect, it } from 'vitest';
import { SERVER_INSTRUCTIONS } from '../src/mcp/server-instructions';

describe('SERVER_INSTRUCTIONS', () => {
  it('matches the watcher debounce timing', () => {
    expect(SERVER_INSTRUCTIONS).toContain('~2s to debounce + sync');
    expect(SERVER_INSTRUCTIONS).toContain('about 2-3 seconds');
    expect(SERVER_INSTRUCTIONS).not.toContain('~500ms');
  });
});

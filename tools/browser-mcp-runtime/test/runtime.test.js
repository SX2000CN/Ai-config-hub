import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { resolveServer } from '../bin/browser-mcp-runtime.js';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const entry = path.join(root, 'bin', 'browser-mcp-runtime.js');

test('resolves the exact pinned Chrome DevTools MCP package', () => {
  assert.equal(resolveServer('chrome-devtools').version, '1.6.0');
});

test('doctor returns JSON readiness without starting a browser', () => {
  const result = spawnSync(process.execPath, [entry, '--doctor'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const payload = JSON.parse(result.stdout);
  assert.equal(payload.ok, true);
  assert.deepEqual(payload.servers.map((server) => server.server), ['chrome-devtools']);
});

test('rejects unknown server names', () => {
  assert.throws(() => resolveServer('unknown'), /Unknown browser MCP server/);
});

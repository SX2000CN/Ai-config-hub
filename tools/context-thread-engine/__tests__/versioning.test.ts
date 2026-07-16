import { readFileSync } from 'fs';
import { join } from 'path';
import { describe, expect, it } from 'vitest';
import {
  MAX_NODE_VERSION_EXCLUSIVE,
  MIN_NODE_VERSION,
  getNodeVersionCompatibility,
} from '../src/bin/node-version-check';
import { SERVER_INFO } from '../src/mcp';
import { PACKAGE_NAME, PACKAGE_VERSION } from '../src/package-info';

describe('runtime and package versioning', () => {
  it('enforces the complete supported Node version range', () => {
    expect(MIN_NODE_VERSION).toBe('22.19.0');
    expect(MAX_NODE_VERSION_EXCLUSIVE).toBe('25.0.0');
    expect(getNodeVersionCompatibility('22.18.99')).toBe('too-old');
    expect(getNodeVersionCompatibility('22.19.0')).toBe('supported');
    expect(getNodeVersionCompatibility('23.0.0')).toBe('supported');
    expect(getNodeVersionCompatibility('24.99.99')).toBe('supported');
    expect(getNodeVersionCompatibility('25.0.0')).toBe('too-new');
    expect(getNodeVersionCompatibility('24.1.0+vendor.2')).toBe('supported');
    expect(getNodeVersionCompatibility('24.1.0-rc.1')).toBe('too-old');
    expect(getNodeVersionCompatibility('24.1.0garbage')).toBe('too-old');
  });

  it('uses package metadata as the CLI and MCP version source', () => {
    const packageJson = JSON.parse(
      readFileSync(join(__dirname, '..', 'package.json'), 'utf-8')
    ) as { name: string; version: string; engines: { node: string } };
    const cliSource = readFileSync(join(__dirname, '..', 'src', 'bin', 'context-thread.ts'), 'utf-8');

    expect(PACKAGE_NAME).toBe(packageJson.name);
    expect(PACKAGE_VERSION).toBe('0.9.6');
    expect(PACKAGE_VERSION).toBe(packageJson.version);
    expect(SERVER_INFO.version).toBe(PACKAGE_VERSION);
    expect(packageJson.engines.node).toBe('>=22.19.0 <25.0.0');
    expect(cliSource).toContain("import { PACKAGE_VERSION } from '../package-info'");
    expect(cliSource).toContain('.version(PACKAGE_VERSION)');
  });
});

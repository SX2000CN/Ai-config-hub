/**
 * Node.js version compatibility check.
 *
 * Node 25.x has a V8 turboshaft WASM JIT Zone allocator bug that
 * reliably crashes ContextThread with `Fatal process out of memory: Zone`
 * during tree-sitter grammar compilation. This module owns the
 * user-facing banner shown before exit. Kept side-effect-free so it's
 * safe to import from tests without triggering CLI bootstrap.
 */

/**
 * Build the bordered banner shown when ContextThread detects an
 * unsupported Node.js major version (currently 25+). Pinned via unit
 * test so the recovery commands and override instructions can't be
 * silently stripped by future edits.
 *
 * Uses ASCII glyphs to stay readable on Windows OEM-codepage consoles
 * (see ../ui/glyphs.ts for the rationale).
 */
export function buildNode25BlockBanner(nodeVersion: string): string {
  const sep = '-'.repeat(72);
  return [
    sep,
    `[ContextThread] Unsupported Node.js version: ${nodeVersion}`,
    sep,
    'Node.js 25.x has a V8 WASM JIT (turboshaft) Zone allocator bug that',
    'crashes with `Fatal process out of memory: Zone` when ContextThread',
    'compiles tree-sitter grammars. Later majors remain blocked until they',
    'are validated. See https://github.com/ai-config-hub/context-thread/issues/81',
    '',
    'Fix: install Node.js 22 LTS:',
    '  nvm install 22 && nvm use 22                          # nvm',
    '  brew install node@22 && brew link --overwrite --force node@22  # Homebrew',
    '',
    'To override (NOT recommended - you will likely OOM):',
    '  CONTEXT_THREAD_ALLOW_UNSAFE_NODE=1 context-thread ...',
    sep,
  ].join('\n');
}

/**
 * Supported runtime range. The patch-level floor matters because the built-in
 * node:sqlite implementation used by ContextThread is only supported from the
 * selected Node 22 maintenance release onward.
 */
export const MIN_NODE_VERSION = '22.19.0';
export const MAX_NODE_VERSION_EXCLUSIVE = '25.0.0';

export type NodeVersionCompatibility = 'supported' | 'too-old' | 'too-new';

function parseVersion(version: string): [number, number, number] | null {
  // Accept complete stable SemVer (with an optional build suffix). Pre-release
  // runtimes are intentionally unsupported because package `engines` ranges do
  // not opt into them and they have not passed the WASM/SQLite compatibility CI.
  const match = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+[-0-9A-Za-z.]+)?$/.exec(version.trim());
  if (!match) return null;
  return [Number(match[1]), Number(match[2]), Number(match[3])];
}

function compareVersions(
  left: [number, number, number],
  right: [number, number, number]
): number {
  for (let i = 0; i < 3; i++) {
    const delta = left[i]! - right[i]!;
    if (delta !== 0) return delta;
  }
  return 0;
}

export function getNodeVersionCompatibility(nodeVersion: string): NodeVersionCompatibility {
  const parsed = parseVersion(nodeVersion);
  const minimum = parseVersion(MIN_NODE_VERSION)!;
  const maximum = parseVersion(MAX_NODE_VERSION_EXCLUSIVE)!;
  if (!parsed || compareVersions(parsed, minimum) < 0) return 'too-old';
  if (compareVersions(parsed, maximum) >= 0) return 'too-new';
  return 'supported';
}

/**
 * Build the bordered banner shown when ContextThread detects a Node.js major below
 * {@link MIN_NODE_VERSION}. Pinned via unit test so the recovery commands and the
 * override env var can't be silently stripped by future edits.
 *
 * Uses ASCII glyphs to stay readable on Windows OEM-codepage consoles
 * (see ../ui/glyphs.ts for the rationale).
 */
export function buildNodeTooOldBanner(nodeVersion: string): string {
  const sep = '-'.repeat(72);
  return [
    sep,
    `[ContextThread] Unsupported Node.js version: ${nodeVersion}`,
    sep,
    `ContextThread requires Node.js ${MIN_NODE_VERSION} or newer (and below ${MAX_NODE_VERSION_EXCLUSIVE}).`,
    'Older versions lack the supported node:sqlite runtime ContextThread depends on.',
    '',
    'Fix: install Node.js 22 LTS:',
    '  nvm install 22 && nvm use 22                          # nvm',
    '  brew install node@22 && brew link --overwrite --force node@22  # Homebrew',
    '',
    'To override (NOT recommended - unsupported):',
    '  CONTEXT_THREAD_ALLOW_UNSAFE_NODE=1 context-thread ...',
    sep,
  ].join('\n');
}

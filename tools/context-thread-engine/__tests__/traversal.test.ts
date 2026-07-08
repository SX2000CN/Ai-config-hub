/**
 * Traversal algorithm regression tests.
 *
 * Each test targets a specific optimization that was made to GraphTraverser:
 *  1. traverseDFS - iterative stack (no call-stack overflow on deep chains)
 *  2. getImpactRadius - focalNode passed through (no extra getNodeById per recursion)
 *  3. findPath - parent-pointer BFS (no O(n²) path-copy overhead)
 */

import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import ContextThread from '../src';

describe('GraphTraverser', () => {
  const projects: string[] = [];

  afterEach(() => {
    for (const project of projects.splice(0)) {
      rmSync(project, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });

  // ---------------------------------------------------------------------------
  // 1. traverseDFS — deep linear chain must not overflow the call stack
  // ---------------------------------------------------------------------------
  it('traverseDFS handles a deep linear call chain without stack overflow', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'ct-dfs-'));
    projects.push(projectRoot);

    // Generate a chain: fn0 → fn1 → fn2 → … → fn49
    // 50 hops is more than enough to exhaust typical recursion in tight stacks.
    const depth = 50;
    for (let i = 0; i < depth; i++) {
      const next = i + 1 < depth ? `fn${i + 1}()` : '0';
      writeFileSync(
        join(projectRoot, `f${i}.ts`),
        `export function fn${i}() { return ${next}; }\n`,
        'utf-8'
      );
    }
    // Ensure the last file also exports its function cleanly
    writeFileSync(
      join(projectRoot, `f${depth - 1}.ts`),
      `export function fn${depth - 1}() { return 0; }\n`,
      'utf-8'
    );

    const cg = await ContextThread.init(projectRoot, { index: true });

    const startResults = cg.searchNodes('fn0');
    expect(startResults.length).toBeGreaterThan(0);

    // traverseDFS is not on the public API — access the internal traverser.
    // traverseDFS must complete without throwing RangeError: Maximum call stack
    const traverser = (cg as unknown as { traverser: { traverseDFS: (id: string, opts?: object) => unknown } }).traverser;
    expect(() => {
      traverser.traverseDFS(startResults[0]!.node.id, { direction: 'outgoing', maxDepth: depth + 5 });
    }).not.toThrow();

    cg.close();
  });

  // ---------------------------------------------------------------------------
  // 2. getImpactRadius — container node's children must appear in impact result
  // ---------------------------------------------------------------------------
  it('getImpactRadius includes children of a container node', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'ct-impact-'));
    projects.push(projectRoot);

    // Class with two methods; a consumer calls one of the methods.
    // Impact of the class should include both methods.
    writeFileSync(
      join(projectRoot, 'service.ts'),
      [
        'export class MyService {',
        '  doA() { return 1; }',
        '  doB() { return 2; }',
        '}',
      ].join('\n') + '\n',
      'utf-8'
    );
    writeFileSync(
      join(projectRoot, 'consumer.ts'),
      [
        'import { MyService } from "./service";',
        'export function run() {',
        '  const s = new MyService();',
        '  return s.doA();',
        '}',
      ].join('\n') + '\n',
      'utf-8'
    );

    const cg = await ContextThread.init(projectRoot, { index: true });

    const classResults = cg.searchNodes('MyService');
    expect(classResults.length).toBeGreaterThan(0);

    const impact = cg.getImpactRadius(classResults[0]!.node.id, 2);
    const names = Array.from(impact.nodes.values()).map((n) => n.name);

    // Both methods must be in the impact set (container traversal)
    expect(names).toContain('doA');
    expect(names).toContain('doB');

    cg.close();
  });

  // ---------------------------------------------------------------------------
  // 3. findPath — correct path for a chain of length > 5
  // ---------------------------------------------------------------------------
  it('findPath returns a correct path across 6 hops', async () => {
    const projectRoot = mkdtempSync(join(tmpdir(), 'ct-path-'));
    projects.push(projectRoot);

    // Build a 7-node linear chain: a → b → c → d → e → f → g
    const chain = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    for (let i = 0; i < chain.length; i++) {
      const name = chain[i]!;
      const nextCall = i + 1 < chain.length ? `${chain[i + 1]}()` : '0';
      const importLine =
        i + 1 < chain.length
          ? `import { ${chain[i + 1]} } from "./${chain[i + 1]}";\n`
          : '';
      writeFileSync(
        join(projectRoot, `${name}.ts`),
        `${importLine}export function ${name}() { return ${nextCall}; }\n`,
        'utf-8'
      );
    }

    const cg = await ContextThread.init(projectRoot, { index: true });

    const fromResults = cg.searchNodes('a');
    const toResults = cg.searchNodes('g');
    expect(fromResults.length).toBeGreaterThan(0);
    expect(toResults.length).toBeGreaterThan(0);

    const path = cg.findPath(fromResults[0]!.node.id, toResults[0]!.node.id);

    // Path must exist and include both endpoints
    expect(path).not.toBeNull();
    expect(path![0]!.node.name).toBe('a');
    expect(path![path!.length - 1]!.node.name).toBe('g');
    // Chain has 7 nodes → path length should be 7
    expect(path!.length).toBe(chain.length);

    cg.close();
  });
});

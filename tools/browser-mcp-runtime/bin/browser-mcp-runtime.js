#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const serverPackages = Object.freeze({
  'chrome-devtools': {
    packageName: 'chrome-devtools-mcp',
    expectedVersion: '1.6.0',
    entry: 'build/src/bin/chrome-devtools-mcp.js',
  },
});

export function resolveServer(serverName) {
  const definition = serverPackages[serverName];
  if (!definition) {
    throw new Error(`Unknown browser MCP server '${serverName}'. Expected one of: ${Object.keys(serverPackages).join(', ')}`);
  }

  const packageJsonPath = require.resolve(`${definition.packageName}/package.json`);
  const packageJson = require(packageJsonPath);
  if (packageJson.version !== definition.expectedVersion) {
    throw new Error(`${definition.packageName} version mismatch: expected ${definition.expectedVersion}, found ${packageJson.version}`);
  }

  const entryPath = path.join(path.dirname(packageJsonPath), definition.entry);
  require.resolve(entryPath);
  return {
    server: serverName,
    package: definition.packageName,
    version: packageJson.version,
    entry: entryPath,
  };
}

function printDoctor(serverName) {
  const names = serverName ? [serverName] : Object.keys(serverPackages);
  const result = names.map(resolveServer);
  process.stdout.write(`${JSON.stringify({ ok: true, servers: result })}\n`);
}

function runServer(serverName, args) {
  const resolved = resolveServer(serverName);
  const child = spawn(process.execPath, [resolved.entry, ...args], {
    stdio: 'inherit',
    windowsHide: true,
  });

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      if (!child.killed) child.kill(signal);
    });
  }
  child.on('error', (error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
  child.on('exit', (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
      return;
    }
    process.exitCode = code ?? 1;
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [command, ...args] = process.argv.slice(2);
  try {
    if (command === '--doctor') {
      printDoctor(args[0]);
    } else if (!command || command === '--help' || command === '-h') {
      process.stdout.write('Usage: browser-mcp-runtime <chrome-devtools> [args...]\n');
    } else {
      runServer(command, args);
    }
  } catch (error) {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  }
}

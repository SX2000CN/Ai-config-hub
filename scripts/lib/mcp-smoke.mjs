import { spawn } from 'node:child_process';
import process from 'node:process';
import readline from 'node:readline';

const [command, encodedArgs, timeoutText = '15000'] = process.argv.slice(2);
if (!command || !encodedArgs) {
  throw new Error('Usage: mcp-smoke.mjs <command> <base64-json-args> [timeout-ms]');
}

const args = JSON.parse(Buffer.from(encodedArgs, 'base64url').toString('utf8'));
const timeoutMs = Number(timeoutText);
const child = spawn(command, args, {
  stdio: ['pipe', 'pipe', 'pipe'],
  windowsHide: true,
  env: process.env,
});

let stderr = '';
child.stderr.setEncoding('utf8');
child.stderr.on('data', (chunk) => {
  stderr = `${stderr}${chunk}`.slice(-4000);
});

function send(message) {
  child.stdin.write(`${JSON.stringify(message)}\n`);
}

function finish(payload, exitCode) {
  clearTimeout(timer);
  if (!child.killed) child.kill();
  process.stdout.write(`${JSON.stringify(payload)}\n`);
  process.exitCode = exitCode;
}

const timer = setTimeout(() => {
  finish({ ok: false, error: `MCP smoke probe timed out after ${timeoutMs} ms`, stderr }, 1);
}, timeoutMs);

child.on('error', (error) => finish({ ok: false, error: error.message, stderr }, 1));
child.on('exit', (code) => {
  if (process.exitCode === undefined && code !== 0) {
    finish({ ok: false, error: `MCP server exited with code ${code}`, stderr }, 1);
  }
});

const lines = readline.createInterface({ input: child.stdout });
lines.on('line', (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  if (message.id === 1) {
    if (message.error) {
      finish({ ok: false, error: JSON.stringify(message.error), stderr }, 1);
      return;
    }
    send({ jsonrpc: '2.0', method: 'notifications/initialized' });
    send({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} });
  } else if (message.id === 2) {
    if (message.error) {
      finish({ ok: false, error: JSON.stringify(message.error), stderr }, 1);
      return;
    }
    const tools = Array.isArray(message.result?.tools) ? message.result.tools : [];
    finish({ ok: true, toolCount: tools.length, tools: tools.map((tool) => tool.name), stderr }, 0);
  }
});

send({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'ai-config-hub-doctor', version: '1.0.0' },
  },
});

#!/usr/bin/env node
// Claude Code PreToolUse guard for ai-config-hub.
//
// Why this exists: rules are context, not enforced configuration. A boundary that
// only lives in a rules file is obeyed at the model's discretion and decays when
// the model generation changes. Enforcement that lives in a hook does not ride on
// the model's judgement, so a model upgrade does not retire it.
//
// Decision semantics map directly onto the collaboration contract:
//   ask  -> "first get user confirmation" for irreversible / user-level-config work
//   allow -> everything else, because the boundary follows reversibility, not risk size
// Nothing is denied outright: the contract is a confirmation gate, not a ban list.
//
// Input : one JSON object on stdin (Claude Code PreToolUse payload).
// Output: JSON with hookSpecificOutput.permissionDecision in {allow, ask}.
// Exit  : 0 always when a decision was produced; 2 on unexpected failure so the
//         tool call is blocked rather than silently allowed.

import { homedir } from 'node:os'
import path from 'node:path'
import process from 'node:process'

const USER_CONFIG_ROOTS = [
  '.claude',
  '.codex',
  '.grok',
  '.agents',
  '.ai-config-hub',
  path.join('.config', 'opencode'),
]

const CREDENTIAL_NAME_PATTERNS = [
  /^\.env(\..*)?$/i,
  /\.(secret|secrets|local)\..*$/i,
  /^auth\.json$/i,
  /\.(pem|key|p12|pfx|ppk)$/i,
  /^id_(rsa|ed25519|ecdsa|dsa)/i,
  /^(netrc|npmrc|pypirc)$/i,
]

const BASH_RISK_PATTERNS = [
  /\bgit\s+push\b[^\n]*(--force\b|(?<!\S)-f(?!\S))/i,
  /\bgit\s+rebase\b/i,
  /\bgit\s+reset\s+--hard\b/i,
  /\bgit\s+filter-(branch|repo)\b/i,
  /\bgit\s+clean\s+-[a-z]*f/i,
  /\bgit\s+branch\s+-D\b/i,
  /\bgit\s+push\b[^\n]*--delete\b/i,
  /\brm\s+-[a-z]*r[a-z]*f\b[^\n]*(\s\/(?:\s|$)|\s\*|\s~(?:\s|$))/i,
  /\bmkfs(\.\w+)?\b/i,
  /\bdd\s+[^\n]*of=\/dev\//i,
]

const FILE_WRITE_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit'])

function decide(input) {
  const toolName = String(input?.tool_name ?? '')
  const toolInput = input?.tool_input ?? {}

  if (FILE_WRITE_TOOLS.has(toolName)) {
    return decideWrite(String(toolInput.file_path ?? toolInput.notebook_path ?? ''))
  }
  if (toolName === 'Bash') {
    return decideBash(String(toolInput.command ?? ''))
  }
  return { decision: 'allow', reason: `tool ${toolName} is outside the guard surface` }
}

function decideWrite(rawPath) {
  if (!rawPath) {
    return { decision: 'ask', reason: 'write without a resolvable path: confirm intent' }
  }

  const home = homedir()
  const expanded = rawPath.startsWith('~') ? path.join(home, rawPath.slice(1)) : rawPath
  const absolute = path.resolve(expanded)
  const relative = path.relative(home, absolute)
  const insideHome = relative && !relative.startsWith('..') && !path.isAbsolute(relative)

  if (insideHome) {
    const firstSegment = relative.split(path.sep)[0]
    const nested = path.join(relative.split(path.sep)[0], relative.split(path.sep)[1] ?? '')
    for (const root of USER_CONFIG_ROOTS) {
      if (firstSegment === root || nested === root) {
        return {
          decision: 'ask',
          reason: `user-level configuration write (${root}): confirm before touching shared tool state`,
        }
      }
    }
  }

  const segments = absolute.split(path.sep)
  if (segments.includes('private')) {
    return {
      decision: 'ask',
      reason: 'private/ holds machine-local and possibly sensitive notes: confirm before writing',
    }
  }

  const base = path.basename(absolute)
  for (const pattern of CREDENTIAL_NAME_PATTERNS) {
    if (pattern.test(base)) {
      return {
        decision: 'ask',
        reason: `credential-shaped filename (${base}): confirm, and do not write real secrets into tracked files`,
      }
    }
  }

  return { decision: 'allow', reason: 'workspace write with no guard condition' }
}

function decideBash(command) {
  for (const pattern of BASH_RISK_PATTERNS) {
    if (pattern.test(command)) {
      return {
        decision: 'ask',
        reason: `destructive or history-rewriting command matched ${pattern}: confirm before running`,
      }
    }
  }
  return { decision: 'allow', reason: 'command with no guard condition' }
}

function emit(result) {
  const permissionDecision = result.decision === 'ask' ? 'ask' : 'allow'
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision,
        permissionDecisionReason: result.reason,
      },
    }) + '\n',
  )
}

let raw = ''
process.stdin.setEncoding('utf8')
for await (const chunk of process.stdin) {
  raw += chunk
}

try {
  // Some hosts emit a UTF-8 BOM on the pipe; a leading BOM is not valid JSON.
  const payload = raw.replace(/^\uFEFF/, '').trim() ? JSON.parse(raw.replace(/^\uFEFF/, '').trim()) : {}
  emit(decide(payload))
  process.exit(0)
} catch (error) {
  // Fail toward confirmation rather than silent permission.
  emit({
    decision: 'ask',
    reason: `guard could not parse its input (${error?.message ?? 'unknown'}); confirm the action`,
  })
  process.exit(0)
}

// Deterministic scorer for the A/B runway.
//
// Why deterministic: "asking the model whether it needs an instruction is not a
// measurement." Everything that can be judged by a regex anchor is judged by one.
// Only the residual goes to a judge, and only the diff is ever shown to it.
//
// A claim whose trigger surface never appears in the diff is reported as
// `held-by-inertia` (vacuous, not earned) rather than as a pass. That is the
// companion falsifier: a claim that stays held-by-inertia across a whole run is
// dead weight and gets deleted.

import { readFileSync } from 'node:fs'

export function loadRubric(path) {
  const parsed = JSON.parse(readFileSync(path, 'utf8'))
  if (parsed.schemaVersion !== 1) throw new Error(`unsupported rubric schema ${parsed.schemaVersion}`)
  if (!Array.isArray(parsed.claims) || parsed.claims.length === 0) {
    throw new Error('rubric has no claims')
  }
  return parsed
}

export function scoreDiff(diff, rubric) {
  const lines = String(diff ?? '').split(/\r?\n/)
  return rubric.claims.map((claim) => {
    const applies = safeRegex(claim.appliesIf)
    const holds = safeRegex(claim.holds)

    const surface = applies ? lines.some((line) => applies.test(line)) : true
    if (!surface) {
      return { id: claim.id, status: 'held-by-inertia', reason: 'trigger surface never appeared in the diff' }
    }

    const satisfied = holds ? lines.some((line) => holds.test(line)) : false
    return satisfied
      ? { id: claim.id, status: 'hold', reason: 'anchor matched' }
      : { id: claim.id, status: 'violated', reason: 'trigger surface present but no satisfying anchor' }
  })
}

export function summarize(results, rubric) {
  const hidden = new Set(rubric.hiddenFromConfig ?? [])
  const scored = results.filter((r) => !hidden.has(r.id))
  const holds = scored.filter((r) => r.status === 'hold').length
  const violated = scored.filter((r) => r.status === 'violated').length
  const inertia = results.filter((r) => r.status === 'held-by-inertia').map((r) => r.id)
  return {
    holds,
    violated,
    heldByInertia: inertia,
    deadWeight: inertia,
    verdict: violated === 0 && holds > 0 ? 'pass' : violated === 0 ? 'no-signal' : 'fail',
  }
}

// Pairwise comparison of two conditions on one task. Order is caller supplied so the
// runner can evaluate both seating orders; a verdict that flips on order swap is a tie.
export function pairwise(a, b, judge) {
  const forward = judge(a, b)
  const backward = judge(b, a)
  if (forward !== backward) return 'tie'
  return forward
}

function safeRegex(source) {
  if (!source) return null
  try {
    return new RegExp(source, 'm')
  } catch {
    throw new Error(`bad regex in rubric: ${source}`)
  }
}

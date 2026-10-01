import test from 'node:test'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import { loadRubric, scoreDiff, summarize, pairwise } from './score.mjs'

const rubric = loadRubric(fileURLToPath(new URL('./rubric.json', import.meta.url)))

test('claim whose trigger surface never appears is held-by-inertia, not a pass', () => {
  const results = scoreDiff('diff --git a/x.txt b/x.txt\n+hello world\n', rubric)
  const noDoc = results.find((r) => r.id === 'no-irrelevant-doc')
  assert.equal(noDoc.status, 'held-by-inertia')
})

test('trigger surface present with satisfying anchor holds', () => {
  const diff = ['diff --git a/src/a.ts b/src/a.ts', '+function greet() {', '+  // 复用既有 helper', '+}'].join('\n')
  const results = scoreDiff(diff, rubric)
  const claim = results.find((r) => r.id === 'no-new-sibling-implementation')
  assert.equal(claim.status, 'hold')
})

test('trigger surface present without satisfying anchor is violated', () => {
  const diff = ['diff --git a/src/a.ts b/src/a.ts', '+function greet() {', '+  return 1', '+}'].join('\n')
  const results = scoreDiff(diff, rubric)
  const claim = results.find((r) => r.id === 'no-new-sibling-implementation')
  assert.equal(claim.status, 'violated')
})

test('summary keeps hidden claims out of the score but reports them as inertia', () => {
  const diff = ['diff --git a/src/a.ts b/src/a.ts', '+function greet() { return 1 }'].join('\n')
  const results = scoreDiff(diff, rubric)
  const summary = summarize(results, rubric)
  assert.ok(summary.deadWeight.includes('claim-scoped-comments'))
  assert.equal(summary.verdict, 'fail')
})

test('verdict is no-signal when nothing held and nothing violated', () => {
  const results = scoreDiff('diff --git a/x.txt b/x.txt\n+hello\n', rubric)
  assert.equal(summarize(results, rubric).verdict, 'no-signal')
})

test('pairwise resolves to tie when the verdict flips on seating order', () => {
  const judge = (x, y) => (x === 'good' && y === 'bad' ? 'a' : 'b')
  assert.equal(pairwise('good', 'bad', judge), 'tie')
})

test('pairwise keeps the verdict when both seating orders agree', () => {
  // Judge is expressed pairwise: it names the winner by identity, not by seat.
  const judge = (x, y) => (x === 'good' && y === 'bad' ? 'a' : y === 'good' && x === 'bad' ? 'a' : 'b')
  assert.equal(pairwise('good', 'bad', judge), 'a')
})

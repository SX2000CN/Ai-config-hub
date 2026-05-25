/**
 * Server-level instructions emitted in the MCP `initialize` response.
 *
 * MCP clients (Claude Code, Cursor, opencode, LangChain, OpenAI Agent
 * SDK, …) surface this text in the agent's system prompt automatically,
 * giving the agent a high-level playbook for the context-thread toolset
 * before it sees individual tool descriptions.
 *
 * Goals when editing this:
 *   - Tool selection by intent (which tool for which question)
 *   - Common chains (refactor planning = X then Y)
 *   - Anti-patterns (don't grep when context_thread_search is faster)
 *
 * Keep it tight. The agent reads this every session — long instructions
 * burn tokens. Reference only tools that exist on `main`; gate any
 * conditional tools behind feature checks if/when they ship.
 */
export const SERVER_INSTRUCTIONS = `# ContextThread — code intelligence over an indexed knowledge graph

ContextThread is a SQLite knowledge graph of every symbol, edge, and file
in the workspace. Reads are sub-millisecond; when the MCP server is running
and the file watcher is active, the index usually lags writes by about a
second. Consult it BEFORE writing or editing code, not during.

## Answer directly — don't delegate exploration

For "how does X work", architecture, trace, or where-is-X questions,
answer DIRECTLY using 2-3 context-thread calls: \`context_thread_context\` first,
then ONE \`context_thread_explore\` for the source of the symbols it surfaces.
ContextThread IS the pre-built search index — so delegating the lookup to a
separate file-reading sub-task/agent, or running your own grep + read
loop, repeats work context-thread already did and costs more for the same
answer. Reach for raw Read/Grep only to confirm a specific detail
context-thread didn't cover. A direct context-thread answer is typically a handful
of calls; a grep/read exploration is dozens.

## Tool selection by intent

- **"What is the symbol named X?"** → \`context_thread_search\`
- **"What's the deal with this task / feature / area?"** → \`context_thread_context\` (PRIMARY — composes search + node + callers + callees in one call)
- **"What calls this?"** → \`context_thread_callers\`
- **"What does this call?"** → \`context_thread_callees\`
- **"What would changing this break?"** → \`context_thread_impact\`
- **"Show me this symbol's source / signature / docstring."** → \`context_thread_node\`
- **"Show me several related symbols' source / survey an area."** → \`context_thread_explore\` (ONE capped call; prefer over many context_thread_node/Read)
- **"What's in directory X?"** → \`context_thread_files\`
- **"Is the index ready / fresh / what's its size?"** → \`context_thread_status\`

## Common chains

- **Onboarding**: \`context_thread_context\` first. If still unclear, \`context_thread_explore\` for breadth, then \`context_thread_node\` on specific symbols.
- **Refactor planning**: \`context_thread_search\` → \`context_thread_callers\` → \`context_thread_impact\`. The blast-radius answer comes from impact, not from walking callers manually.
- **Debugging a regression**: \`context_thread_callers\` of the suspected symbol; widen with \`context_thread_impact\` if an unexpected call appears.

## Anti-patterns

- **Don't grep first** when looking up a symbol by name — \`context_thread_search\` is faster and returns kind + location + signature.
- **Don't chain \`context_thread_search\` + \`context_thread_node\`** when you just want context — \`context_thread_context\` is one round-trip.
- **Don't loop \`context_thread_node\` over many symbols** — one \`context_thread_explore\` call returns them all grouped by file, while each separate call re-reads the whole context and costs far more. Use \`context_thread_node\` for a single symbol.
- **Don't query the index immediately after editing a file** — the watcher needs ~500ms to debounce + sync. Wait for the next turn.

## Limitations

- Auto-sync requires an initialized project plus an active MCP watcher; otherwise
  check \`context_thread_status\` for pending changes and refresh or verify from files.
- With an active watcher, the index usually lags file writes by ~1 second.
- Cross-file resolution is best-effort name matching; ambiguous calls may return multiple candidates.
- No live correctness validation — that's still the TypeScript compiler / test suite / linter's job. ContextThread supplements those with structural context they don't have.
`;

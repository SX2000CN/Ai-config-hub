# context-thread engine

This is the local source engine used by ai-config-hub's "脉络" MCP workflow.
The full design and implementation notes live in `../../docs/context-thread/`.

It is built from this repo, then published to a user-level runtime:

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

Runtime location:

```text
C:\Users\sx200\.ai-config-hub\mcp\context-thread\
```

The engine is intentionally local-first:

- no npm global CLI install is required;
- MCP config points at the user-level runtime, not this repo path;
- no external service is called;
- project indexes live in `.Ai-config/context-thread/`;
- new indexes default to the `structure` persistence policy and ignore
  `context-thread.db` in Git;
- MCP tools are exposed with the `context_thread_*` prefix.

Initialize an index only when the task genuinely needs cross-file code relationships.
From this repository, prefer the project wrapper:

```powershell
.\scripts\context-thread.ps1 init <project-path> --index
```

`structure` keeps symbol identity, locations and relationships while omitting
docstrings, signatures, decorators, type parameters, edge metadata and unresolved
candidates. Use `--content-mode rich` only when persisting those details is
intentional. Add `--track-db` only when the database should be eligible for Git
tracking. Existing databases without policy metadata remain `legacy-rich` until
an explicit privacy command changes them.

```powershell
node <context-thread-entry> privacy <project-path>
node <context-thread-entry> privacy <project-path> --content-mode structure
node <context-thread-entry> privacy <project-path> --track-db
node <context-thread-entry> status <project-path> --json
```

Changing `rich` to `structure` scrubs the optional columns, rebuilds FTS and
compacts SQLite. Changing `structure` to `rich` performs a complete re-index.

In a project without that wrapper, call the installed runtime through Node:

```powershell
node "$HOME\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js" init <project-path> --index
```

Simple questions and local edits should normally use direct file search and reads instead.

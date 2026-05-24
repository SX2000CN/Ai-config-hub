# context-thread engine

This is the local source engine used by ai-config-hub's "脉络" MCP workflow.
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
- MCP tools are exposed with the `context_thread_*` prefix.

Use `context-thread init -i <project-path>` only when a real L2/L3 code
relationship task needs an index. Small tasks should fall back to normal file
search and reads.

# context-thread engine

This is the local source engine used by ai-config-hub's "脉络" MCP workflow.
It is built and launched through the repository wrapper:

```powershell
.\scripts\context-thread.ps1 bootstrap
.\scripts\context-thread.ps1 serve --mcp
```

The engine is intentionally local-first:

- no global CLI install is required;
- no external service is called;
- project indexes live in `.context-thread/`;
- MCP tools are exposed with the `context_thread_*` prefix.

Use `context-thread init -i <project-path>` only when a real L2/L3 code
relationship task needs an index. Small tasks should fall back to normal file
search and reads.

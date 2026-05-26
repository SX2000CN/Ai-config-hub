# 同步流程

本文记录全局规则、skills 和 MCP 配置片段的本机同步流程。所有同步脚本默认先 dry-run，只有显式 `-Apply` 才写入真实全局目录。

## 全局同步前总检查

同步任一真实用户级配置前，优先运行：

```powershell
.\scripts\check-all.ps1
```

该脚本会依次执行规则、skills、MCP 配置片段的 render、check 和 dry-run。若只检查单个管线，也应至少运行对应的 render、check、sync dry-run，并确认输出中的 `would update` / `missing target` 与本次预期一致。

## 全局规则

1. 修改源文件：
   - `rules/shared/core.md`
   - `rules/tools/claude-code.md`
   - `rules/tools/codex.md`

   当前工作状态约定属于共享规则，维护在 `rules/shared/core.md`。

2. 渲染输出：

```powershell
.\scripts\render.ps1
```

3. 检查生成结果：

```powershell
.\scripts\check.ps1
```

4. 预览同步目标；不传 `-Apply` 时只 dry-run：

```powershell
.\scripts\sync.ps1
```

5. 确认无误后应用：

```powershell
.\scripts\sync.ps1 -Apply
```

`sync.ps1 -Apply` 会先备份目标文件，再覆盖：

- `rules/rendered/CLAUDE.md` → `C:\Users\sx200\.claude\CLAUDE.md`
- `rules/rendered/AGENTS.md` → `C:\Users\sx200\.codex\AGENTS.md`

## 注意事项

- 不要直接编辑 rendered 文件作为长期源头；应修改 `rules/` 下的源文件。
- 如果手动改过真实全局文件，应先把差异同步回本项目源文件，再重新渲染。
- 完整 `C:\Users\sx200\.codex\config.toml` 不作为仓库事实源；只有 MCP 配置片段流程会合并明确托管的 server section。

## Skills

1. 修改源文件：
   - `skills/shared/<skill-name>/`
   - `skills/claude-code/<skill-name>/SKILL.md`
   - `skills/codex/<skill-name>/SKILL.md`

   当前全局 skills：`project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread`、`pencil-design-workflow`。

2. 渲染输出：

```powershell
.\scripts\render-skills.ps1
```

3. 检查生成结果：

```powershell
.\scripts\check-skills.ps1
```

4. 预览同步目标：

```powershell
.\scripts\sync-skills.ps1
```

5. 确认无误后应用：

```powershell
.\scripts\sync-skills.ps1 -Apply
```

如需同时写入历史 Codex 兼容目录：

```powershell
.\scripts\sync-skills.ps1 -Apply -IncludeCodexLegacy
```

默认同步目标：

- `skills/rendered/claude-code/<skill-name>/` → `C:\Users\sx200\.claude\skills\<skill-name>\`
- `skills/rendered/codex/<skill-name>/` → `C:\Users\sx200\.agents\skills\<skill-name>\`

可选历史兼容目标：

- `skills/rendered/codex-legacy/<skill-name>/` → `C:\Users\sx200\.codex\skills\<skill-name>\`

注意事项：

- 不要直接编辑 `skills/rendered/` 作为长期源头；应修改 `skills/shared/` 或工具专属入口源。
- `.codex\skills` 不是新 Codex skill 的默认目标，只在兼容已有环境时使用。
- 当前渲染产物会带有 `<!-- ai-config-hub-managed: <skill-name> -->` 标记。
- `sync-skills.ps1 -Apply` 会优先把带对应标记的目录视为托管产物；历史安装如果仍保留匹配的 `name: <skill-name>` 也会被接管，但不匹配这两种标记的目录会拒绝覆盖。
- `sync-skills.ps1 -Apply` 的备份目录位于 skills 发现目录外：`C:\Users\sx200\.claude\ai-config-hub-skill-backups\` 和 `C:\Users\sx200\.agents\ai-config-hub-skill-backups\`，避免备份被工具误识别为可用 skill。

## MCP / 工具配置片段

MCP 配置片段只管理明确命名的非敏感 server，不保存或覆盖完整用户配置。

1. 修改源文件：
   - `tool-configs/mcp/shared/browser-visual.json`
   - `tool-configs/mcp/shared/context-thread.json`

   `pencil` MCP 不写入 `tool-configs/mcp/shared/`，因为它依赖本机 Pencil Desktop / 插件安装路径。它由 `scripts\mcp-local.ps1` 在同步本机时自动发现；Claude Code 侧通过 `claude mcp add -s user` 注册，Codex 侧合并到真实用户配置。

2. 如果改动了 `tools/context-thread-engine/` 或首次配置本机 runtime，先同步脉络运行时：

```powershell
.\scripts\sync-context-thread-runtime.ps1
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

默认运行时位置：`C:\Users\sx200\.ai-config-hub\mcp\context-thread\`。

3. 渲染输出：

```powershell
.\scripts\render-mcp.ps1
```

4. 检查生成结果：

```powershell
.\scripts\check-mcp.ps1
```

5. 预览同步目标：

```powershell
.\scripts\sync-mcp.ps1
```

也可以只预览单个工具：

```powershell
.\scripts\sync-mcp.ps1 -ClaudeCode
.\scripts\sync-mcp.ps1 -Codex
```

6. 确认无误后应用：

```powershell
.\scripts\sync-mcp.ps1 -Apply
```

或分工具应用：

```powershell
.\scripts\sync-mcp.ps1 -Apply -ClaudeCode
.\scripts\sync-mcp.ps1 -Apply -Codex
```

当前托管目标：

- `tool-configs/mcp/rendered/claude-code.mcp.json` → 合并 `mcpServers.chrome-devtools` / `mcpServers.playwright` 到 `C:\Users\sx200\.claude.json`
- `tool-configs/mcp/rendered/claude-code.mcp.json` → 合并 `mcpServers.context-thread` 到 `C:\Users\sx200\.claude.json`
- `tool-configs/mcp/rendered/codex.mcp.toml` → 合并托管 `browser-visual` 和 `context-thread` blocks 到 `C:\Users\sx200\.codex\config.toml`
- `scripts\mcp-local.ps1` → 本机发现 Pencil MCP server 后，`sync-mcp.ps1` 通过 `claude mcp add -s user pencil ...` 注册 Claude Code 的 `pencil`，并合并 `[mcp_servers.pencil]` 到 Codex 用户配置。

注意事项：

- 不要提交完整 `C:\Users\sx200\.claude.json` 或 `C:\Users\sx200\.codex\config.toml`。
- `sync-mcp.ps1` 默认 dry-run；只有显式 `-Apply` 才写真实用户配置。
- Claude Code 的 `chrome-devtools`、`playwright` 和 `context-thread` 仍合并到 `C:\Users\sx200\.claude.json`；`pencil` 不再直接写 `.claude.json`，改用 Claude Code 官方 MCP 命令注册。为避免正在运行的 Claude Code 会话用旧配置覆盖新注册，持久同步 `pencil` 时应完全退出 Claude Code 后，从普通终端运行 `sync-mcp.ps1 -Apply -ClaudeCode`。
- Codex 同步使用 `# >>> ai-config-hub managed mcp: <group>` marker block，只替换托管 block 或同名 server section，保留其他私有配置。
- Pencil MCP 是同步本机的本地自动配置项：优先发现 `AI_CONFIG_HUB_PENCIL_MCP_COMMAND`，再发现 `~\.pencil\mcp\<app>\out\mcp-server-windows-x64.exe` 中的 VS Code / Cursor 等插件端。Desktop transport 暂不自动发现；如果现有用户配置仍指向 Desktop，`sync-mcp.ps1` 会替换为可发现的插件端。发现失败只给 warning，不阻塞 browser/context-thread MCP 校验；真正执行设计请求前仍要在当前会话确认 Pencil MCP 工具和目标画布可用。
- `context-thread` MCP 配置声明的是 `node C:\Users\sx200\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js serve --mcp`；源码仍由本仓库维护，运行时由 `sync-context-thread-runtime.ps1 -Apply` 分发。本项目不依赖 npm 全局 `context-thread` 命令，也不自动初始化项目 `.Ai-config/context-thread/` 索引。`check-mcp.ps1` 会在 runtime 缺失时给出 warning，但不阻塞浏览器 MCP 校验。
- 每个目标项目的 context-thread 索引都是项目本地文件，默认位置是 `.Ai-config/context-thread/context-thread.db`。全局 MCP runtime 存在不等于目标项目已经有索引；复杂任务按需初始化，L0/L1 无索引时直接回退到普通文件搜索和读取。
- MCP server 已运行且 watcher 可用时，受支持源码变更会自动增量同步；MCP 没运行、watcher 被禁用或平台不支持递归 watch 时不会自动更新。复杂任务前可用 `context_thread_status` 或 `context-thread status` 查看 pending changes，必要时运行 `context-thread sync`。
- `sync-mcp.ps1 -Apply` 会先备份到 `C:\Users\sx200\.claude\ai-config-hub-config-backups\` 或 `C:\Users\sx200\.codex\ai-config-hub-config-backups\`。

# 架构说明

`ai-config-hub` 使用纯文本源文件和 PowerShell 脚本管理 AI 编程工具配置。

## 数据流

### 全局规则

```text
rules/shared/core.md
        +
rules/tools/claude-code.md
        +
templates/CLAUDE.md.tpl
        ↓
rules/rendered/CLAUDE.md
        ↓
C:\Users\sx200\.claude\CLAUDE.md
```

```text
rules/shared/core.md
        +
rules/tools/codex.md
        +
templates/AGENTS.md.tpl
        ↓
rules/rendered/AGENTS.md
        ↓
C:\Users\sx200\.codex\AGENTS.md
```

### Skills

每个全局 skill 使用同一条渲染和同步路径：

```text
skills/shared/<skill-name>/
        +
skills/claude-code/<skill-name>/SKILL.md
        ↓
skills/rendered/claude-code/<skill-name>/
        ↓
C:\Users\sx200\.claude\skills\<skill-name>\
```

```text
skills/shared/<skill-name>/
        +
skills/codex/<skill-name>/SKILL.md
        ↓
skills/rendered/codex/<skill-name>/
        ↓
C:\Users\sx200\.agents\skills\<skill-name>\
```

当前全局 skills：

- `project-ai-config-hub`
- `global-frontend-design`
- `global-thinking-partner`
- `global-context-thread`
- `pencil-design-workflow`

可选历史兼容目标：

```text
skills/rendered/codex-legacy/<skill-name>/
        ↓
C:\Users\sx200\.codex\skills\<skill-name>\
```

### MCP / 工具配置片段

MCP 配置只管理明确命名的非敏感片段，不保存完整用户配置。

```text
tool-configs/mcp/shared/browser-visual.json
tool-configs/mcp/shared/context-thread.json
        ↓
scripts/sync-context-thread-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\context-thread\
        ↓
tool-configs/mcp/rendered/claude-code.mcp.json
        ↓
merge managed mcpServers.chrome-devtools/playwright/context-thread only
        ↓
C:\Users\sx200\.claude.json
```

`context-thread` server 的 command 指向 `node C:\Users\sx200\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js serve --mcp`。源码仍在 `tools/context-thread-engine/` 中维护，MCP 启动不再依赖当前仓库路径。

```text
tool-configs/mcp/shared/browser-visual.json
tool-configs/mcp/shared/context-thread.json
        ↓
tool-configs/mcp/rendered/codex.mcp.toml
        ↓
merge managed browser-visual and context-thread blocks only
        ↓
C:\Users\sx200\.codex\config.toml
```

### 当前工作状态

```text
.Ai-config/CURRENT.md
        ↓
AI 接手入口和多任务状态总览
        ↓
.Ai-config/tasks/*.md
        ↓
单个任务的无损接手卡；archive/ 仅作为可选长期整理目录
```

### 视觉验证产物

```text
designs/pencil/<slug>/
        ↓
Pencil .pen 设计文件和导出图
```

```text
docs/visual-validation/<page>.html
        ↓
无构建依赖的静态验证页面
        ↓
docs/visual-validation/exports/
        ↓
真实浏览器 MCP 截图证据
```

`Pencil` 导出图只证明设计产物可视化结果，不能替代真实浏览器截图、console、DOM 或可访问性检查。

## 设计原则

- 共享规则只写一份，避免 Claude Code 和 Codex 长期漂移。
- 工具专属内容放在 `rules/tools/`，不污染通用规则。
- rendered 文件保留在仓库中，方便审阅最终效果。
- 同步真实全局规则文件必须显式执行 `sync.ps1 -Apply`。
- 同步真实全局 MCP 配置片段必须显式执行 `sync-mcp.ps1 -Apply`；完整 Claude Code / Codex 用户配置仍不自动管理，只合并明确托管的 MCP server。
- Codex 完整 `config.toml` 不作为仓库事实源，只提供安全示例模板和托管 MCP 片段。
- skills 使用 `skills/shared/<skill-name>/` 作为事实源，工具目录只放入口源文件。
- skill rendered 包通过 `render-skills.ps1` 为每个已登记全局 skill 生成，不应手工作为长期事实源编辑。
- `global-context-thread` 是“脉络”轻量结构化事实层：context-thread 只负责代码结构关系，非代码复杂工作流仍由 `.Ai-config` 任务卡关系索引承接；没有可用索引或 MCP 工具时回退到普通文件读取。
- `scripts/sync-context-thread-runtime.ps1` 负责把 `tools/context-thread-engine/` 的构建产物和生产依赖分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`；`scripts/context-thread.ps1` 是面向人类和脚本的轻量 wrapper，默认调用该用户级 runtime，不要求 npm 全局安装 `context-thread`。
- `.Ai-config/CURRENT.md` 是项目级 AI 接手入口和多任务状态总览，不是完整日志或完成记录；具体任务事实保存在 `.Ai-config/tasks/*.md`，未确认或有风险的任务不得直接丢弃。
- `project-ai-config-hub` 的 rendered skill 包会带托管标记，便于 `sync-skills.ps1` 区分历史安装和本仓库产物。
- `.codex\skills` 只作为历史兼容目标，Codex 当前官方路径优先使用 `.agents\skills`。

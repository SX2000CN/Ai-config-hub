# 架构说明

`ai-config-hub` 的架构先是一套 AI 编程协作配置，再是一套把配置交付到工具中的分发系统。

配置本体负责规定 AI 如何工作：什么时候轻量处理、什么时候升级、什么时候使用 skills、什么时候读取 `.Ai-config` 或脉络索引、什么时候验证和交接。分发系统负责把这些配置渲染、检查并同步到 Claude Code、Codex 等工具中。

设计总览见：[AI 配置设计与实现](ai-config-design.md)。
脉络作为结构化事实层的详细设计见：[context-thread/](context-thread/README.md)。

## 配置能力层

```text
核心行为层
rules/shared/core.md
        ↓
工具适配层
rules/tools/* + templates/*
        ↓
可复用能力层
skills/shared/<skill-name>/
        ↓
项目状态层
.Ai-config/CURRENT.md + .Ai-config/tasks/
        ↓
结构化事实层
.Ai-config/context-thread/context-thread.db + 任务卡关系索引
        ↓
工具桥接层
tool-configs/ + tools/context-thread-engine/ + 按需临时验证产物
        ↓
分发与验证层
render / check / sync 脚本
```

各层职责：

- 核心行为层：定义默认轻量、按风险升级、文档同步、验证、敏感信息和版本控制边界。
- 工具适配层：处理 Claude Code、Codex 等工具差异，不复制通用原则。
- 可复用能力层：把项目中枢、前端设计、思维伙伴、脉络和 Pencil workflow 做成 skills。
- 项目状态层：在具体项目中保存当前工作状态、任务卡和接手入口。
- 结构化事实层：用脉络索引和任务卡关系索引辅助复杂关系判断。
- 工具桥接层：提供 MCP、本地引擎能力，以及按需生成的临时浏览器 / Pencil 验证产物。
- 分发与验证层：让配置可审阅、可检查、可安全同步。

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

每个全局 managed skill 使用同一条渲染和同步路径。注意：这是本仓库的全局 skill 分发管线；普通目标项目自己的项目级 skill，canonical 事实源应位于目标项目 `.Ai-config/skills/<skill-name>/`，`.claude/skills` 和 `.agents/skills` 只作为工具入口。



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
scripts/mcp-local.ps1
        ↓
scripts/sync-context-thread-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\context-thread\
        ↓
tool-configs/mcp/rendered/claude-code.mcp.json
        ↓
merge managed mcpServers.chrome-devtools/playwright/context-thread
plus local-discovered mcpServers.pencil
        ↓
C:\Users\sx200\.claude.json
```

`context-thread` server 的 command 指向 `node C:\Users\sx200\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js serve --mcp`。源码仍在 `tools/context-thread-engine/` 中维护，MCP 启动不再依赖当前仓库路径。

```text
tool-configs/mcp/shared/browser-visual.json
tool-configs/mcp/shared/context-thread.json
scripts/mcp-local.ps1
        ↓
tool-configs/mcp/rendered/codex.mcp.toml
        ↓
merge managed browser-visual/context-thread blocks
plus local-discovered mcp_servers.pencil
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

## 设计原则

- AI 配置设计优先于分发实现；render、sync 和 MCP 合并只服务配置落地。
- 共享规则只写一份，避免 Claude Code 和 Codex 长期漂移。
- 工具专属内容放在 `rules/tools/`，不污染通用规则。
- rendered 文件保留在仓库中，方便审阅最终效果。
- 同步真实全局规则文件必须显式执行 `sync.ps1 -Apply`。
- 同步真实全局 MCP 配置片段必须显式执行 `sync-mcp.ps1 -Apply`；完整 Claude Code / Codex 用户配置仍不自动管理，只合并明确托管的 MCP server 和本机自动发现的 Pencil MCP。
- Codex 完整 `config.toml` 不作为仓库事实源，只提供安全示例模板和托管 MCP 片段。
- skills 使用 `skills/shared/<skill-name>/` 作为事实源，工具目录只放入口源文件。
- skill rendered 包通过 `render-skills.ps1` 为每个已登记全局 skill 生成，不应手工作为长期事实源编辑。
- `global-context-thread` 是“脉络”轻量结构化事实层：context-thread 只负责代码结构关系，非代码复杂工作流仍由 `.Ai-config` 任务卡关系索引承接；没有可用索引或 MCP 工具时回退到普通文件读取。
- `scripts/sync-context-thread-runtime.ps1` 负责把 `tools/context-thread-engine/` 的构建产物和生产依赖分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`；`scripts/context-thread.ps1` 是面向人类和脚本的轻量 wrapper，默认调用该用户级 runtime，不要求 npm 全局安装 `context-thread`。
- `.Ai-config/CURRENT.md` 是项目级 AI 接手入口和多任务状态总览，不是完整日志或完成记录；具体任务事实保存在 `.Ai-config/tasks/*.md`，未确认或有风险的任务不得直接丢弃。
- `project-ai-config-hub` 的 rendered skill 包会带托管标记，便于 `sync-skills.ps1` 区分历史安装和本仓库产物。
- `.codex\skills` 只作为历史兼容目标，Codex 当前官方路径优先使用 `.agents\skills`。

# 架构说明

`ai-config-hub` 的架构先是一套 AI 编程协作配置，再是一套把配置交付到工具中的分发系统。

配置本体负责规定 AI 如何工作：默认怎样直接推进、何时扩大证据范围、怎样组合 skills、何时读取 `.Ai-config` 或脉络索引、何时验证和交接。分发系统负责把这些配置渲染、检查并同步到 Claude Code、Codex、OpenCode、Grok Build 等工具中。

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
config/managed-assets.psd1 + tool-configs/ + tools/context-thread-engine/ + 按需临时验证产物
        ↓
分发与验证层
render / check / sync 脚本
```

各层职责：

- 核心行为层：定义默认直接推进、证据扩展、授权与平台边界、比例验证、敏感信息和版本控制规则。
- 工具适配层：处理 Claude Code、Codex、OpenCode、Grok Build 等工具差异，不复制通用原则。
- 可复用能力层：把项目中枢和前端实现作为领域 skills，把思维伙伴作为 reasoning mode，把脉络作为工具路由 skill。
- 项目状态层：在具体项目中保存当前工作状态、任务卡和接手入口；CURRENT 必须 hygiene。
- 结构化事实层：用脉络索引和任务卡关系索引辅助复杂关系判断。
- 工具桥接层：由单一 manifest 登记托管目标，提供 MCP、本地引擎能力，以及按需生成的临时浏览器验证产物。
- 分发与验证层：提供非修改 preflight、staging、原子替换、统一备份和失败回滚，让配置可审阅、可检查、可安全同步。

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

```text
rules/shared/core.md
        +
rules/tools/grok.md
        +
templates/grok-AGENTS.md.tpl
        ↓
rules/rendered/grok-AGENTS.md
        ↓
C:\Users\sx200\.grok\AGENTS.md
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

```text
skills/shared/<skill-name>/
        +
skills/grok/<skill-name>/SKILL.md
        ↓
skills/rendered/grok/<skill-name>/
        ↓
C:\Users\sx200\.grok\skills\<skill-name>\
```

当前全局 skills：

- `project-ai-config-hub`
- `global-frontend-design`
- `global-thinking-partner`
- `global-context-thread`

路由元数据维护在 `config/managed-assets.psd1`：显式点名和平台强制触发优先，领域 skill 主导交付，`global-thinking-partner` 可作为辅助 reasoning mode，工具路由 skill 只在对应能力确实需要时加入。`skills/evals/routes.json` 保存路由正例、反例和 handoff 场景。

可选历史兼容目标：

```text
skills/rendered/codex-legacy/<skill-name>/
        ↓
C:\Users\sx200\.codex\skills\<skill-name>\
```

### MCP / 工具配置片段

MCP 配置只管理明确命名的非敏感片段，不保存完整用户配置。

`config/managed-assets.psd1` schema v2 统一登记规则目标、四个 skills、四个 MCP server 定义、五个 profiles、三套 runtime、doctor 元数据和用户目录相对路径；schema v1 由加载器先规范化。`tool-configs/mcp/shared/*.json` 继续作为单 server 命令和参数的唯一事实源。

```text
tool-configs/mcp/shared/playwright.json
tool-configs/mcp/shared/chrome-devtools.json
tool-configs/mcp/shared/context-thread.json
tool-configs/mcp/shared/local-webfetch.json
scripts/mcp-local.ps1
        ↓
core / code-intel / browser / browser-debug / full
        ↓
scripts/render-mcp.ps1
        ↓
core: tool-configs/mcp/rendered/*.json|toml
others: tool-configs/mcp/rendered/<profile>/*
        ↓
scripts/mcp-doctor.ps1
        ↓
Source / Readiness / Smoke
```

运行时分成三套：

```text
tools/local-webfetch/
        ↓
scripts/sync-local-webfetch-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\local-webfetch\

tools/context-thread-engine/
        ↓
scripts/sync-context-thread-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\context-thread\

tools/browser-mcp-runtime/
        ↓
scripts/sync-browser-mcp-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\browser\
```

三套 runtime 都通过 staging、生产依赖安装、smoke 和原子切换分发，Node.js 支持范围统一为 `>=22.19.0 <25.0.0`。浏览器 runtime 精确固定 `@playwright/mcp@0.0.78` 与 `chrome-devtools-mcp@1.6.0`，启动时不下载依赖。

```text
selected rendered profile
        ↓
scripts/sync-mcp.ps1 -Profile <name>
        ↓
Claude: merge confirmed managed mcpServers；安全移除可识别的 retired pencil
Codex: replace confirmed managed marker blocks；安全移除 retired pencil
Grok: replace confirmed managed marker blocks + managed compat；安全移除 retired pencil
OpenCode: merge only the managed mcp object into opencode.json；安全移除可识别的 retired pencil
        ↓
C:\Users\sx200\.claude.json
C:\Users\sx200\.codex\config.toml
C:\Users\sx200\.grok\config.toml
C:\Users\sx200\.config\opencode\opencode.json
```

默认 `core` 给 Claude Code、Grok 和 OpenCode 启用 local-webfetch，Codex 不注册 managed MCP。`code-intel`、`browser`、`browser-debug` 分别增加 context-thread、Playwright、Chrome DevTools；OpenCode 当前只接入 local-webfetch/context-thread；`full` 聚合各目标允许的 managed server。Grok Playwright 渲染层默认追加 `--headless`。Grok Apply 会写入 managed compat，关闭 Claude MCP/skills/agents/rules 扫描，避免双源。Profile 切换只删除能够用 marker 或 current/legacy 精确签名确认归属的 inactive server，同名用户配置不会被静默覆盖。Grok 完整 surface 见 [grok-build-surface.md](grok-build-surface.md) 与 [ADR 0001](decisions/0001-grok-first-class-target.md)；OpenCode 边界见 [opencode-surface.md](opencode-surface.md)。

`mcp-doctor.ps1` 报告 profile、source/install 版本与 hash、漂移、runtime 路径、工具数量和 PreferredFor 冲突。可比较 hash 覆盖 runtime 的完整执行 payload、`package.json`、lockfile 和 lockfile 登记的生产依赖，忽略日志与缓存，因此已锁定包的内容修改或缺失会被 Readiness 识别。Apply 前运行所选 profile 的 Smoke；required runtime 不可用时阻断，`-AllowDegraded` 只能跳过 optional server。Smoke 在 Readiness 基础上增加本地 entry probe、initialize + `tools/list` 和预期工具数校验，默认不联网。

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
- 共享规则只写一份，避免 Claude Code、Codex、OpenCode 和 Grok Build 长期漂移。
- 工具专属内容放在 `rules/tools/`，不污染通用规则。
- rendered 文件保留在仓库中，方便审阅最终效果。
- render 脚本的 `-Check` 模式只比较源文件与 rendered 产物，不写 tracked 文件；跨管线预检由 `check-all.ps1` 统一执行。
- 同步真实全局规则文件必须显式执行 `sync.ps1 -Apply`。
- 同步真实全局 MCP 配置片段必须显式执行 `sync-mcp.ps1 -Apply`；OpenCode 使用 `sync-opencode-mcp.ps1 -Apply` 只合并 `opencode.json` 的 `mcp` 节。完整 Claude Code / Codex / Grok / OpenCode 用户配置仍不自动管理，只合并明确托管的 MCP server，并安全移除可识别的 retired pencil。Grok hooks/plugins、api_key、auth 与外观配置不托管。
- MCP 通过 profile 控制能力面；默认 `core` 给 Claude Code、Grok 和 OpenCode 启用 local-webfetch，Codex core 不注册 managed MCP。代码脉络和两类浏览器分别由 `code-intel`、`browser`、`browser-debug` 启用，OpenCode 浏览器 server 暂不注册，`full` 只用于明确需要全部能力的临时场景。
- Codex 完整 `config.toml` 不作为仓库事实源，只提供安全示例模板和托管 MCP 片段。
- skills 使用 `skills/shared/<skill-name>/` 作为事实源，工具目录只放入口源文件；OpenCode 原生入口位于 `skills/opencode/` 和 `~/.config/opencode/skills/`。
- skill rendered 包通过 `render-skills.ps1` 为每个已登记全局 skill 生成，不应手工作为长期事实源编辑。
- `global-context-thread` 是“脉络”轻量结构化事实层：context-thread 只负责代码结构关系，非代码复杂工作流仍由 `.Ai-config` 任务卡关系索引承接；没有可用索引或 MCP 工具时回退到普通文件读取。
- `scripts/sync-context-thread-runtime.ps1` 负责把 `tools/context-thread-engine/` 的构建产物和生产依赖分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`；`scripts/context-thread.ps1` 是面向人类和脚本的轻量 wrapper，默认调用该用户级 runtime，不要求 npm 全局安装 `context-thread`。
- `.Ai-config/CURRENT.md` 是项目级 AI 接手入口和多任务状态总览，不是完整日志或完成记录；具体任务事实保存在 `.Ai-config/tasks/*.md`，未确认或有风险的任务不得直接丢弃。
- `project-ai-config-hub` 的 rendered skill 包会带托管标记，便于 `sync-skills.ps1` 区分历史安装和本仓库产物。
- `.codex\skills` 只作为历史兼容目标，Codex 当前官方路径优先使用 `.agents\skills`。
- 所有 `sync*.ps1 -Apply` 在写入前自动运行完整预检，并只允许把目标解析到当前或显式 `-UserHome` 内部。
- 用户级部署先写入 `~/.ai-config-hub/staging/<pipeline>/<operation-id>/`，验证后再切换；原目标备份到 `~/.ai-config-hub/backups/<pipeline>/<operation-id>/`。同一管线中途失败时回滚本次已更新目标，历史备份保留。

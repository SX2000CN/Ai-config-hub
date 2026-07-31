# ai-config-hub

`ai-config-hub` 是一套个人 AI 编程协作配置系统。它的核心不是“把文件同步到哪里”，而是设计 AI 在真实项目中如何理解任务、按风险选择工作深度、使用结构化事实、验证结果、保护敏感信息并完成跨会话接手。

分发系统只是为这套 AI 配置服务的基础设施：它负责把规则、skills、MCP 配置和本地工具运行时安全地渲染、检查并同步到 Claude Code、Codex、OpenCode、Grok Build 以及后续工具中。

完整设计见：[AI 配置设计与实现](docs/ai-config-design.md)。脉络的独立设计和技术实现见：[脉络文档索引](docs/context-thread/README.md)。

## 这套配置解决的问题

- 默认轻量：简单任务不被任务卡、索引、长计划和同步流程拖重。
- 按证据扩展：跨模块、跨会话、高风险或需要接手时才读取更多上下文并更新状态。
- 减少幻觉：优先当前文件、当前文档、结构化事实源和验证结果，而不是靠长上下文硬猜。
- 多工具一致：Claude Code、Codex、OpenCode、Grok Build 和后续工具共享核心规则，只把工具差异放到专属补充。
- 能力模块化：用 skills 沉淀前端设计、思维伙伴、脉络和项目 AI 配置中枢。
- 可接手：用 `.Ai-config/CURRENT.md` 和任务卡保存有接手价值的工作现场。
- 可落地：用 render/check/sync 脚本把配置安全同步到真实本机工具目录。

## 配置设计分层

- 核心行为层：`rules/shared/core.md`，定义默认直接推进、证据读取、授权边界、比例验证、敏感信息和版本控制规则。
- 工具适配层：`rules/tools/` 和 `templates/`，只处理 Claude Code / Codex / OpenCode / Grok Build 差异。
- 可复用能力层：`skills/`，维护全局 skills 的共享事实源、工具入口和 rendered 包。
- 项目状态层：`.Ai-config/`，维护当前仓库或目标项目的 AI 接手入口、任务卡和项目级 skill 清单。
- 结构化事实层：脉络索引和任务卡关系索引，用来缩小复杂代码关系或复杂工作流关系的理解范围。
- 工具桥接层：`tool-configs/`、`tools/context-thread-engine/` 和按需生成的临时设计 / 浏览器验证产物。
- 分发与验证层：`scripts/`、`rules/rendered/`、`skills/rendered/` 和 `tool-configs/mcp/rendered/`。

## 目录结构

```text
rules/shared/       通用规则源文件
rules/tools/        工具专属补充
rules/rendered/     渲染后的全局规则文件
templates/          渲染模板和安全示例配置
config/             托管规则、skills、MCP servers/profiles、runtime 和用户目标的单一清单
scripts/            规则、skills 和 MCP 配置的渲染、检查、同步脚本
docs/               架构、同步、安全和 skills 设计文档
skills/             skills 共享源、工具入口和 rendered 包
tool-configs/       工具配置片段源文件和 rendered 产物
private/            本机私有草稿目录，除 README 外默认忽略
```

## 文档层级

- `docs/ai-config-design.md`：整套 AI 配置的设计主文档。
- `docs/architecture.md`：配置能力层和分发数据流。
- `docs/context-thread/`：脉络专题，包含设计、技术实现和真实场景边界。
- `docs/work-state-design.md`：`.Ai-config/CURRENT.md` 和任务卡机制。
- `docs/skills-roadmap.md`：全局 skills 的能力边界和实现状态。
- `docs/sync-workflow.md`：本机 render / check / sync 流程。
- `docs/opencode-surface.md`：OpenCode 的配置路径、原生 skills 和 MCP 合并边界。
- `docs/grok-build-surface.md`：Grok Build 路径、compat 与托管边界矩阵。
- `docs/decisions/0001-grok-first-class-target.md`：Grok 一等公民 target 的架构决策。
- `.Ai-config/`：当前项目的 AI 协作状态，不承载完整项目设计文档。

## 维护和分发命令

在项目根目录运行：

```powershell
.\scripts\render.ps1
.\scripts\check.ps1
.\scripts\sync.ps1
```

跨管线修改或任何真实 `-Apply` 前运行非修改型完整预检：

```powershell
.\scripts\check-all.ps1
```

skills 管理流程：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
.\scripts\sync-skills.ps1
```

MCP 配置片段管理流程：

```powershell
.\scripts\sync-local-webfetch-runtime.ps1
.\scripts\sync-browser-mcp-runtime.ps1
.\scripts\sync-context-thread-runtime.ps1
.\scripts\render-mcp.ps1
.\scripts\check-mcp.ps1
.\scripts\mcp-doctor.ps1 -Profile core -Mode Source
.\scripts\sync-mcp.ps1 -Profile core
.\scripts\sync-opencode-mcp.ps1 -Profile code-intel
```

MCP 按 profile 管理：`core` 只给 Claude Code 提供 local-webfetch；`code-intel` 为支持的目标增加 context-thread；`browser-debug` 为 Claude Code、Codex 和 Grok 增加 Chrome DevTools；`full` 聚合各目标允许的三项 managed 能力，OpenCode 仍只接入 context-thread。Playwright MCP 已退役，旧配置只在 ownership 匹配时移除；日常浏览器自动化改用官方 Playwright CLI + skill。Grok Apply 会关闭 Claude MCP/skills/agents/rules compat 双源。日常默认 `core`/`code-intel`，不要把 `full` 当常驻。Grok hooks/plugins 不由 Hub 托管。

Playwright CLI 和官方 skill 不由 Hub 复制或同步；在用户主目录运行官方安装器：

```powershell
npm install -g @playwright/cli@0.1.17
playwright-cli install --skills=claude
playwright-cli install --skills=agents
```

脉络 MCP 使用本仓库源码构建，但运行时分发到用户级目录，不指向当前项目路径。首次使用或引擎源码变更后，先同步全局运行时：

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

默认运行时位置：`C:\Users\sx200\.ai-config-hub\mcp\context-thread\`。context-thread 支持 Node.js `>=22.19.0 <25.0.0`；不在该范围内时 CLI 和 runtime 检查会明确阻断。

脉络索引是项目级事实源，不是全局共享数据库。新索引默认使用 `structure` 内容模式，不持久化 docstring、signature、decorator、type parameter 等富文本，数据库默认忽略；只有项目明确选择 `--track-db` 时才跟踪。目标项目需要复杂代码关系分析时再初始化索引；MCP watcher 不可用时使用目标项目 wrapper，或用 `node` 加用户级 runtime 完整路径执行 `sync`。`context-thread` 不是可直接假设存在的全局命令。

确认 dry-run 结果无误后，按本次修改范围执行对应同步。所有同步脚本在真实写入前还会自动执行完整预检：

```powershell
.\scripts\sync.ps1 -Apply
.\scripts\sync-skills.ps1 -Apply
.\scripts\sync-mcp.ps1 -Apply
.\scripts\sync-opencode-mcp.ps1 -Profile code-intel -Apply
```

## 安全原则

不要把真实 token、私钥、服务器密码、私有/内部或含凭证 provider URL、机器本地 trusted project、生产凭证写入可追踪文件。需要本地落盘时，使用用户明确指定、已忽略且权限受限的文件，并确认不会提交或公开。

## 当前状态

配置能力：

- 已形成以 `rules/shared/core.md` 为核心的 AI 工作规则：默认直接推进、按证据扩展、平台约束不可绕过、文档按需同步、敏感信息保护和比例验证。
- 已设计并接入 `.Ai-config/CURRENT.md` + `.Ai-config/tasks/` 多任务工作状态机制，用于中断、隔天继续、切换任务或切换 AI 编程工具时恢复工作现场。
- 已将脉络作为轻量结构化事实层接入：代码关系由 context-thread 索引承接，非代码复杂工作流由 `.Ai-config` 任务卡关系索引承接，普通局部任务不强制升级。
- `project-ai-config-hub` 的定位是本项目的项目级分身，用来在目标项目中创建和升级 `.Ai-config/` AI 配置中枢、工作状态机制和多端项目 skills。
- `global-frontend-design` 的定位是全局前端设计 skill，用来在前端 UI 工作中先建立鲜明视觉方向，再落地可维护、可访问、响应式且状态完整的界面。
- `global-thinking-partner` 是可组合 reasoning mode：显式触发时进行自然的多轮脑暴、假设挑战和情景推演，隐式触发只做静默健全性检查。
- `global-context-thread` 是关系工具路由 skill，只在结构化查询能明显减少搜索成本时使用，不主导领域交付。
- 设计先行由 `global-frontend-design` 的短 UI brief 路径承接；`pencil-design-workflow` 已退役。

分发和工具基础设施：

- 已支持 Claude Code、Codex、OpenCode 和 Grok 全局规则的源码化管理。
- 已提供 Codex 安全示例配置模板。
- 已支持四个全局 skill 的源码化、渲染、检查和 dry-run 同步流程；新增或变更的用户级安装需执行 `sync-skills.ps1 -Apply`。
- 已支持 `core`、`code-intel`、`browser-debug`、`full` 四个 MCP profiles，并通过 doctor、runtime readiness、dry-run 和事务合并控制真实用户级配置；OpenCode MCP 以独立合并脚本保护 provider/model 配置。
- 已用 `config/managed-assets.psd1` schema v2 统一登记托管规则目标、四个 skills、退役 skill/MCP 清理、三个 active MCP server、四个 profiles、三套 runtime 和用户目录相对路径，并保留 schema v1 规范化兼容；render 脚本支持非写入 `-Check`，`check-all.ps1` 会执行源码/rendered 一致性、三个 runtime 测试集、同步安全/profile/doctor 测试、runtime 和用户配置 dry-run、敏感信息检查及 `git diff --check`。
- 用户级同步采用 staging 验证后再切换的事务式部署，备份统一保存在 `~/.ai-config-hub/backups/<pipeline>/<timestamp>-<guid>/`；中途失败会恢复本次管线已经更新的目标，不清理历史备份。
- 脉络 MCP 的源码维护在 `tools/context-thread-engine/`，运行时由 `scripts/sync-context-thread-runtime.ps1 -Apply` 分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`，MCP 配置通过 `node` 启动该用户级 runtime，不依赖当前仓库路径或全局 `context-thread` 命令。
- `local-webfetch` MCP 只交付给 Claude Code：运行时对每次目标和重定向做公共网络校验，流式限制响应大小，并把抓取内容标记为不可信外部数据。显式代理被视为可信网络边界。
- 浏览器日常自动化使用外部官方 Playwright CLI + skill；浏览器 MCP runtime 只锁定 Chrome DevTools，用于性能、Lighthouse、内存和深度调试，不在 server 启动时通过 `npx -y` 临时下载包。
- Codex 新 skill 默认同步到 `C:\Users\sx200\.agents\skills\<skill-name>\`；OpenCode 原生 skill 同步到 `C:\Users\sx200\.config\opencode\skills\<skill-name>\`；`.codex\skills` 仅作为可选历史兼容目标。

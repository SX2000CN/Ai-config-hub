# ai-config-hub

`ai-config-hub` 是一套个人 AI 编程协作配置系统。它的核心不是“把文件同步到哪里”，而是设计 AI 在真实项目中如何理解任务、按风险选择工作深度、使用结构化事实、验证结果、保护敏感信息并完成跨会话接手。

分发系统只是为这套 AI 配置服务的基础设施：它负责把规则、skills、MCP 配置和本地工具运行时安全地渲染、检查并同步到 Claude Code、Codex 以及后续工具中。

完整设计见：[AI 配置设计与实现](docs/ai-config-design.md)。脉络的独立设计和技术实现见：[脉络文档索引](docs/context-thread/README.md)。

## 这套配置解决的问题

- 默认轻量：简单任务不被任务卡、索引、长计划和同步流程拖重。
- 按风险升级：跨模块、跨会话、高风险、需要接手的任务才读取更多上下文并更新状态。
- 减少幻觉：优先当前文件、当前文档、结构化事实源和验证结果，而不是靠长上下文硬猜。
- 多工具一致：Claude Code、Codex 和后续工具共享核心规则，只把工具差异放到专属补充。
- 能力模块化：用 skills 沉淀前端设计、思维伙伴、脉络、Pencil 设计先行和项目 AI 配置中枢。
- 可接手：用 `.Ai-config/CURRENT.md` 和任务卡保存有接手价值的工作现场。
- 可落地：用 render/check/sync 脚本把配置安全同步到真实本机工具目录。

## 配置设计分层

- 核心行为层：`rules/shared/core.md`，定义 L0-L3 风险分层、上下文读取、文档同步、验证、敏感信息和版本控制规则。
- 工具适配层：`rules/tools/` 和 `templates/`，只处理 Claude Code / Codex 差异。
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
- `.Ai-config/`：当前项目的 AI 协作状态，不承载完整项目设计文档。

## 维护和分发命令

在项目根目录运行：

```powershell
.\scripts\render.ps1
.\scripts\check.ps1
.\scripts\sync.ps1
```

同步前总检查：

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
.\scripts\sync-context-thread-runtime.ps1
.\scripts\render-mcp.ps1
.\scripts\check-mcp.ps1
.\scripts\sync-mcp.ps1
```

`sync-mcp.ps1` 会在同步本机时自动发现 Pencil MCP server，并把 `pencil` 配置合并到 Claude Code / Codex 用户配置；如果本机还没有 Pencil Desktop 或对应 MCP server，只给 warning，不阻塞浏览器和脉络 MCP 同步。

脉络 MCP 使用本仓库源码构建，但运行时分发到用户级目录，不指向当前项目路径。首次使用或引擎源码变更后，先同步全局运行时：

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

默认运行时位置：`C:\Users\sx200\.ai-config-hub\mcp\context-thread\`。

脉络索引是项目级事实源，不是全局共享数据库。目标项目需要复杂代码关系分析时，再初始化自己的 `.Ai-config/context-thread/context-thread.db`；MCP 正在运行且 watcher 可用时会自动同步受支持源码变更，否则按需运行 `context-thread sync` 或直接读取当前文件确认。

确认 dry-run 结果无误后，按本次修改范围执行对应同步：

```powershell
.\scripts\sync.ps1 -Apply
.\scripts\sync-skills.ps1 -Apply
.\scripts\sync-mcp.ps1 -Apply
```

## 安全原则

不要把真实 token、私钥、服务器密码、provider URL、机器本地 trusted project、生产凭证写入可追踪文件。需要记录本机私有信息时，优先放入 `private/`，并确认不会提交或公开。

## 当前状态

配置能力：

- 已形成以 `rules/shared/core.md` 为核心的 AI 工作规则：默认轻量、按风险升级、结构化事实优先、文档按需同步、敏感信息保护和验证闭环。
- 已设计并接入 `.Ai-config/CURRENT.md` + `.Ai-config/tasks/` 多任务工作状态机制，用于中断、隔天继续、切换任务或切换 AI 编程工具时恢复工作现场。
- 已将脉络作为轻量结构化事实层接入：代码关系由 context-thread 索引承接，非代码复杂工作流由 `.Ai-config` 任务卡关系索引承接，L0/L1 小任务不强制升级。
- `project-ai-config-hub` 的定位是本项目的项目级分身，用来在目标项目中创建和升级 `.Ai-config/` AI 配置中枢、工作状态机制和多端项目 skills。
- `global-frontend-design` 的定位是全局前端设计 skill，用来在前端 UI 工作中先建立鲜明视觉方向，再落地可维护、可访问、响应式且状态完整的界面。
- `global-thinking-partner` 的定位是低副作用思维扩展 skill，用来在复杂 coding 决策前扩展方案、挑战假设、识别失败模式并寻找更简单路径。
- `global-context-thread` 的定位是“脉络”轻量结构化事实层 skill，用来在代码关系、配置关系、影响面或复杂工作流关系分析中优先查询 context-thread 或 `.Ai-config` 关系索引，同时保持 L0/L1 小任务不升级。
- `pencil-design-workflow` 的定位是全局 Pencil / `.pen` / pencli 设计先行路由 skill，用来在用户需要先生成或确认设计图时选择 Pencil Desktop/MCP、VS 插件谨慎模式或 CLI/headless 工作流。

分发和工具基础设施：

- 已支持 Claude Code 和 Codex 全局规则的源码化管理。
- 已提供 Codex 安全示例配置模板。
- 已支持五个全局 skill 的源码化、渲染、检查和 dry-run 同步流程；新增或变更的用户级安装需执行 `sync-skills.ps1 -Apply`。
- 已支持浏览器视觉验证 MCP、脉络 MCP 和 Pencil MCP 的检查与 dry-run 安全合并同步流程；其中 Pencil MCP 按本机安装自动发现，真实用户级配置需执行 `sync-mcp.ps1 -Apply`。
- 脉络 MCP 的源码维护在 `tools/context-thread-engine/`，运行时由 `scripts/sync-context-thread-runtime.ps1 -Apply` 分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`，MCP 配置通过 `node` 启动该用户级 runtime，不依赖当前仓库路径或全局 `context-thread` 命令。
- Pencil 设计先行和真实浏览器 MCP 截图检查链路已完成过验证；对应一次性夹具产物已清理，不作为长期项目资产保留。
- Codex 新 skill 默认同步到 `C:\Users\sx200\.agents\skills\<skill-name>\`；`.codex\skills` 仅作为可选历史兼容目标。

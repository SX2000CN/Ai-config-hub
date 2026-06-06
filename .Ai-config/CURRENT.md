# 当前工作状态

更新时间：2026-06-07
当前活动任务：无
整体状态：空闲；有历史待确认项，但不阻塞新任务。

## 一眼看结论

- 当前没有正在推进、暂停或阻塞的任务。
- 本仓库近期重点是让 AI 配置更快、更精准：快速路由、单 skill 默认、反触发和分层验证已完成，并已同步到本机 Claude Code / Codex 规则与 managed skills。
- MCP 配置本轮只做 dry-run 检查，未执行 `sync-mcp.ps1 -Apply`；如需同步 MCP，单独确认后再做。
- 历史待确认项主要是“用户试用后确认是否关闭任务卡”，不是必须先处理的阻塞项。
- 新任务按 F0-F4 快速路由处理；F0/F1 小任务不要因为本文件存在而启动完整状态流程。

## 当前待确认

| 优先级 | 事项 | 用户需要确认什么 | 建议下一步 |
|---|---|---|---|
| 高 | 快速路由与精准能力调度改造 | Claude Code / Codex 日常使用是否明显更快，反触发是否过强或过弱 | 已同步本机规则和 managed skills；试用后决定是否继续微调或关闭相关任务 |
| 中 | `.Ai-config/tasks/2026-05-24-context-thread.md` | `global-context-thread`、context-thread MCP、用户级 runtime 和项目索引是否符合日常使用预期 | 确认后关闭或继续记录优化点 |
| 中 | `.Ai-config/tasks/2026-05-24-ai-config-path-migration.md` | 根目录 `.Ai-config/` 取代旧版 `docs/ai/` 后，迁移和清理范围是否 OK | 确认后关闭迁移任务 |
| 中 | `.Ai-config/tasks/2026-05-19-ai-config-lightweight.md` | 轻量化规则在真实工作中是否足够快且不丢质量 | 根据试用结果关闭或继续微调 |
| 低 | `.Ai-config/tasks/2026-05-18-pencil-design-workflow.md` | Pencil 设计先行短闸门和可见 MCP 宿主规则是否符合预期 | 设计任务中继续试用，确认后关闭 |

## 快速接手导航

| 你要做什么 | 先读哪里 | 备注 |
|---|---|---|
| 普通问答 / 小修 | 不必读本文件 | 直接按 F0/F1 处理 |
| 改全局规则 | `rules/shared/core.md`、`rules/tools/`、`templates/` | 验证用规则单管线 render/check/dry-run |
| 改全局 skill | `skills/shared/<skill>/`、`skills/claude-code/<skill>/`、`skills/codex/<skill>/` | 不直接改 `skills/rendered/`，先改源再渲染 |
| 改同步流程 | `docs/sync-workflow.md`、`scripts/render*.ps1`、`scripts/check*.ps1`、`scripts/sync*.ps1` | `check-all.ps1` 只作为跨管线 / Apply 前总闸门 |
| 改 MCP / Pencil / browser 工具接入 | `tool-configs/mcp/`、`scripts/mcp-local.ps1`、`docs/sync-workflow.md` | 用户级写入必须先 dry-run 并确认 |
| 改脉络引擎 | `docs/context-thread/README.md`、`tools/context-thread-engine/` | 需要关系判断时先查 context-thread 状态 |
| 理解整体架构 | `docs/architecture.md`、`docs/ai-config-design.md` | README 只作为概览入口 |

## 最近完成

| 事项 | 结果 | 证据 |
|---|---|---|
| 快速路由与精准能力调度改造 | 已更新规则源、skill 源、状态说明和 rendered 产物，并同步到本机 Claude Code / Codex 规则与 managed skills；未同步 MCP 配置 | `check-all.ps1` 通过；`sync.ps1 -Apply`、`sync-skills.ps1 -Apply` 已执行；同步后 dry-run 均为 `unchanged` |
| 脉络更新审计 | 当前仓库索引 up to date；用户级 runtime 与仓库源指纹一致 | `scripts/context-thread.ps1 sync .`、MCP `context_thread_status` |
| AI 配置更新审计 | 规则、skills、MCP 片段曾完成渲染和 dry-run 复查 | 历史记录见相关任务卡 |
| 浏览器视觉验证 MCP | `chrome-devtools` / `playwright` 已纳入本机同步流程 | `.Ai-config/tasks/2026-05-18-browser-visual-mcp.md` |
| 初始化项目 AI 配置中枢 | 已由用户确认完成 | `.Ai-config/archive/2026-05-09-init-ai-config-hub.md` |

## 暂停 / 阻塞

- 暂无。

## 状态规则摘要

- F0/F1：简单问答、一次性命令、一轮内完成且无残留风险的小修复，不读取、创建或更新任务卡。
- F2：只有出现等待确认、验证缺失、残留风险、被打断或跨会话价值时才记录状态。
- F3/F4：按接手价值读取和更新 `.Ai-config/tasks/*.md`；用户级写入、迁移、删除或共享状态变更必须先确认。
- 切换任务前，先保存当前任务状态，不覆盖旧任务卡。
- 未确认、未验证或有残留风险的任务不要直接关闭；保持 `待用户确认`、`等待验证`、`暂停` 或 `阻塞`。

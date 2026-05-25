# 工作任务：当前项目结构页面设计与浏览器验证

任务 ID：2026-05-18-current-project-structure-page
创建时间：2026-05-18 00:00
更新时间：2026-05-25 18:47
状态：已完成
当前活动：否

## 目标

检查当前 `ai-config-hub` 项目级 AI 配置是否需要随全局 skill / MCP 同步结果更新，并通过一个“当前项目结构页面”验证 Pencil 设计先行工作流、Claude Code 浏览器 MCP、截图和视觉检查能力。

## 背景和当前上下文

`pencil-design-workflow` 全局 skill 与浏览器视觉验证 MCP 已同步到本机用户级 Claude Code / Codex 配置。当前项目没有前端应用入口，也没有项目级 `.claude/skills`、`.agents/skills` 或 `.codex/skills` 入口；本仓库主要维护全局 rules、skills、MCP 配置片段和 `.Ai-config` 工作状态。

## 最近结论

- 项目级 AI 配置不需要新增项目级 skill 入口。
- 不需要 legacy `.codex/skills`。
- 本次验证采用最小闭环：Pencil 设计产物、无依赖静态 HTML 页面、真实浏览器 MCP 截图和检查。

## 已确认事实

- `.Ai-config/CURRENT.md` 当前可作为任务状态入口。
- `.Ai-config/skills-registry.md` 登记的是本仓库维护的全局 skill 源，不是需要生成到 `.claude/skills` 的项目级 skill。
- Pencil 设计产物默认放在 `designs/pencil/<slug>/`。
- Pencil 画布验证和导出图检查不能等同真实浏览器验证。

## 已尝试 / 已排除

- 已排除新增 `.claude/skills`、`.agents/skills`、`.codex/skills` 项目级入口。
- 已排除引入 npm、Vite、Next 或其他前端构建栈。
- 已排除把浏览器截图与 Pencil 导出图放在同一目录，以免混淆验证证据。

## 当前卡点

已完成，无卡点。

## 下一步最小动作

无需继续实现；如需后续扩展，可把静态验证页作为浏览器 MCP 回归检查夹具。

## 验证状态

- 已执行 `pencil version`：`pencil 0.2.6`。
- 已执行 `pencil status`：状态 Active。
- 已执行 Pencil CLI 生成 `designs/pencil/current-project-structure/design.pen` 和 `designs/pencil/current-project-structure/exports/design.png`。
- 已用 Chrome DevTools MCP 打开真实 HTTP 页面 `http://127.0.0.1:8765/docs/visual-validation/current-project-structure.html`。
- 已保存桌面截图：`docs/visual-validation/exports/current-project-structure-browser-desktop.png`。
- 已保存移动截图：`docs/visual-validation/exports/current-project-structure-browser-mobile.png`。
- 已通过浏览器快照确认标题、状态 chips、架构卡片和验证边界内容存在。
- 已确认真实 HTTP 页面 console 无 error。
- 已运行 Lighthouse snapshot：Accessibility 100、Best Practices 100、SEO 100、Agentic Browsing 100。
- 已运行 `./scripts/check-all.ps1`：通过，输出 `All render, check, and dry-run steps passed`。
- 已运行 `git diff --check`：仅有 Windows LF/CRLF 提示，无 whitespace error。
- 已确认 `git status --short` 只包含本次计划内新增/修改文件。

## 后续修正

用户反馈本次 `.pen` 是无头 CLI 生成，设计过程不可见，且静态 HTML 页面没有按 `.pen` 设计图还原。已将该问题作为工作流修正点处理：

- 自然语言“做设计图 / 先做设计”默认视为需要用户看到设计过程，优先 Pencil Desktop + MCP。
- 只有用户明确要求后台、批量、无头、自动化或无需看过程时，才使用 Pencil CLI/headless。
- 设计确认后进入前端实现前，必须明确是“按设计稿还原”还是“独立验证夹具 / 技术验证页”。
- 若声明按设计稿实现，必须对照 Pencil 导出图和真实浏览器截图；若故意不还原设计稿，必须提前和最终汇报中说明。
- 已按用户确认执行 `./scripts/sync-skills.ps1 -Apply`，将修正后的 rendered skills 同步到本机 `.claude/skills` 和 `.agents/skills`；未同步 legacy `.codex/skills`。
- 同步后已执行 `./scripts/sync-skills.ps1` dry-run：全部 `unchanged`。
- 后续可视化重设计时发现直接执行 `Pencil.exe <file.pen>` 会让运行时把 `.pen` 当脚本解析；已将正确启动顺序写入 skill：先正常启动 Pencil Desktop，等待 MCP / Desktop transport 连接，再用 Pencil MCP `open_document` 打开目标 `.pen`。
- 已执行 `./scripts/render-skills.ps1` 与 `./scripts/check-skills.ps1`：通过。
- 已按用户确认再次执行 `./scripts/sync-skills.ps1 -Apply`，将包含 Pencil Desktop 正确启动顺序的 rendered skills 同步到本机 `.claude/skills` 和 `.agents/skills`；未同步 legacy `.codex/skills`。
- 同步后已执行 `./scripts/sync-skills.ps1` dry-run：全部 `unchanged`。
- 2026-05-25 用户确认这类旧测试产物对项目后续没有价值；已清理 `docs/visual-validation/` 和 `designs/pencil/current-project-structure/`，仅保留本任务卡中的历史记录。

## 残留风险

- Pencil CLI 可能受上游服务或本机登录状态影响。
- 浏览器 MCP 能辅助视觉检查，但不等同完整 E2E 测试或像素级视觉回归基线。
- 本次页面只用于验证工具链，不代表项目新增正式前端应用。
- 本次 HTML 和 Pencil 产物已作为一次性测试产物清理，不作为长期项目资产。

## 相关文件

- 已清理：`designs/pencil/current-project-structure/`
- 已清理：`docs/visual-validation/`

## 关闭依据 / 最终结果

已完成项目级 AI 配置审计，结论是不需要新增项目级 `.claude/skills`、`.agents/skills` 或 legacy `.codex/skills` 入口。曾生成 Pencil 设计产物和静态项目结构验证页面，并通过真实浏览器 MCP 完成桌面/移动截图、DOM 快照、console 检查和 Lighthouse snapshot；这些产物已在后续清理中删除，仅保留历史记录。

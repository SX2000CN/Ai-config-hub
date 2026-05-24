# 当前工作状态

更新时间：2026-05-24 06:45
当前活动任务：`.Ai-config/tasks/2026-05-24-ai-config-path-migration.md`

## 接手导航

1. 先读本文件，判断是否有当前活动任务和任务卡。
2. 再按需读 `.Ai-config/README.md`，理解本项目 AI 协作中枢边界。
3. 如果任务涉及全局规则，读 `rules/shared/core.md`、`rules/tools/` 和 `templates/`。
4. 如果任务涉及 `project-ai-config-hub` skill，读 `skills/shared/project-ai-config-hub/` 和 `skills/claude-code/`、`skills/codex/` 下的入口源。
5. 如果任务涉及渲染、检查或同步，读 `scripts/render*.ps1`、`scripts/check*.ps1`、`scripts/sync*.ps1` 和 `docs/sync-workflow.md`。
6. 需要理解整体数据流时，读 `docs/architecture.md`。
7. `README.md` 只作为项目概览补充，不是固定的 agent 接手入口。

## 当前活动任务

- `.Ai-config/tasks/2026-05-24-ai-config-path-migration.md`：正在把本仓库项目级 AI 配置中枢从旧版 `docs/ai/` 迁移到根目录 `.Ai-config/`，旧路径仅保留兼容提示；当前仓库已初始化 `.Ai-config/context-thread/context-thread.db`，等待本轮验证和用户确认。

## 待用户确认

- `.Ai-config/tasks/2026-05-24-context-thread.md`：已在仓库源文件、rendered 产物、dry-run 链路和本机用户级配置中引入轻量结构化事实层、`global-context-thread` skill、`context-thread` MCP 配置组和任务卡关系索引；本地引擎源码已自有化迁移到 `tools/context-thread-engine`，运行时改为分发到用户级 `.ai-config-hub` 目录，当前仓库索引已初始化，等待用户下一轮统一测试。
- `.Ai-config/tasks/2026-05-19-ai-config-lightweight.md`：AI 配置轻量化已完成仓库源文件、rendered 产物和本机全局配置同步，复查 dry-run 全部 `unchanged`；等待用户日常试用后确认轻量化手感。
- `.Ai-config/tasks/2026-05-18-pencil-design-workflow.md`：已根据真实失败反馈收紧 Pencil 设计先行规则，并进一步轻量化为短闸门；2026-05-19 已修正宿主选择语义，默认使用当前会话可用的可见 Pencil MCP 宿主，VS Code/Cursor 插件端和 Pencil Desktop 客户端都可作为有效宿主，禁止模型假装能自由切换宿主或静默降级 CLI/headless。

## 暂停 / 阻塞

- 暂无。

## 最近关闭

- 当前项目结构页面验证：已确认无需新增项目级 skill 入口；已用 Pencil 生成设计产物，并用浏览器 MCP 对真实 HTTP 页面完成桌面/移动截图、console 检查和 Lighthouse snapshot；后续已修正 Pencil 工作流，默认可视化设计过程，并要求区分设计稿还原与独立验证夹具；修正后的 skills 已同步到本机 `.claude/skills` 和 `.agents/skills`。随后补充 Pencil Desktop 正确启动顺序：先正常启动 Desktop 并等待 MCP 连接，再用 `open_document` 打开 `.pen`，不要用 `Pencil.exe <file.pen>` 直接传参；仓库 skill 已渲染检查通过，并已按用户确认再次同步到本机用户级 skill，dry-run 全部 `unchanged`。
- `pencil-design-workflow` 全局 skill：已同步到本机 Claude Code / Codex 用户级 skill 目录，未同步历史 `.codex\skills`，同步后 dry-run 全部 unchanged。
- 浏览器视觉验证 MCP：已同步 `chrome-devtools` / `playwright` 到本机 Claude Code / Codex 用户级配置，保留既有 Pencil MCP，同步后检查通过。
- `project-ai-config-hub` 自身更新语义优化：已同步到本机 Claude Code / Codex 全局 skill 目录，同步后 dry-run 全部 unchanged。
- 多任务智能工作状态机制 v2：仓库 rendered 规则与本机全局规则一致，默认 skill rendered 包与本机 Claude Code / Codex 全局 skill 目录一致，任务已确认完成。
- `global-frontend-design` 全局 skill：仓库 rendered 包与本机 Claude Code / Codex 全局 skill 目录一致，任务已确认完成。
- `global-thinking-partner` 全局 skill：仓库 rendered 包与本机 Claude Code / Codex 全局 skill 目录一致，任务已确认完成。
- 初始化项目 AI 配置中枢：已由用户确认完成，归档见 `.Ai-config/archive/2026-05-09-init-ai-config-hub.md`。

## 接手规则

- 简单问答、一次性命令、一轮内完成且无残留风险的小修复，不需要创建任务卡。
- 任务跨天、中断、切换、阻塞、等待确认，或有残留风险时，再创建或更新 `.Ai-config/tasks/*.md`。
- 切换任务前，先保存当前任务状态，不要覆盖旧任务卡。
- 未确认、未验证或有残留风险的任务不要直接关闭，应保持为待用户确认、等待验证、暂停或阻塞。
- 任务关闭时应记录结果、验证情况、残留风险和关闭依据。

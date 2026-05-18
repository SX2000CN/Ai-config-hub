# 工作任务：新增 Pencil 设计先行工作流 skill

任务 ID：2026-05-18-pencil-design-workflow
创建时间：2026-05-18 00:00
更新时间：2026-05-19 03:05
状态：待用户确认
当前活动：否

## 目标

新增并接入 `pencil-design-workflow` 全局 skill，使自然语言“做设计图”“先设计确认后写代码”等设计先行请求自动进入 Pencil / `.pen` / pencli 工作流，同时避免局部 UI bugfix 误触发。

## 背景和当前上下文

用户已确认并在真实使用中再次修正：设计请求默认都需要 Pencil Desktop + MCP 可视化流程，不要求用户额外说“我要看着做”；批量、后台、无头、自动化或明确不需要看过程时才使用 Pencil CLI/headless。VS Code / Cursor 插件只能作为用户明确指定当前 IDE 画布时的例外，不能替代默认 Desktop/MCP 路径；Pencil 画布验证不能等同于真实浏览器验证，Claude Code 真实前端视觉自检需要补 Playwright/浏览器 MCP。

2026-05-19 追加背景：用户反馈在 Claude Code 中配合 `global-frontend-design` 使用本 skill 做前端设计时，实际持续约三小时没有打开 Pencil Desktop/MCP，可视化设计请求被 CLI/终端错误重试和前端实现流程吞掉，Claude Code 没有停下说明 MCP 不可用。这说明原规则“默认优先 Desktop/MCP”不够硬，必须改为“设计请求默认必须 Desktop/MCP；不可用就停止说明，不能静默降级”。

2026-05-19 轻量化背景：用户进一步指出 Pencil MCP、pencli 和 `global-frontend-design` 经常叠加使用，三者上下文过重会增加模型幻觉和质量波动。当前优化目标是在不削弱 Desktop/MCP 强制闸门的前提下，把 `pencil-design-workflow` 改成短闸门，CLI/headless、MCP 操作细节、保存位置和审查验证都按需读取。

2026-05-19 Desktop 打开链路背景：用户再次反馈“和之前一样无法使用 pencli 桌面端打开或者新建画布”，失败信息显示 MCP server 握手成功但 `open_document` 报 `transport not connected to app: desktop`。本机复查确认 `pencil interactive -a desktop` 会连接 `\\.\pipe\pencil-desktop`，没有该 transport 时会报 `connect ENOENT \\.\pipe\pencil-desktop`。因此规则需要明确：MCP server 存在不代表 Desktop transport 已连接，正确流程必须区分启动 Desktop、连接 transport、打开 `.pen` 三个动作。

官方 Pencil CLI skill 位于 `https://unpkg.com/@pencil.dev/cli@latest/SKILL.md`，本任务将其作为上游参考，不直接照搬。

## 最近结论

- 已新增 `pencil-design-workflow` 共享事实源、Claude Code 入口源、Codex 入口源和 rendered 包。
- 已接入 `render-skills.ps1`、`check-skills.ps1`、`sync-skills.ps1`。
- 已更新 registry、README 和 `global-frontend-design` 到 Pencil workflow 的交接说明。
- 已通过 render 和 check；sync dry-run 显示新 skill 尚未同步到用户级目录。
- 2026-05-19 已收紧规则：所有设计请求默认必须走 Pencil Desktop/MCP 可视化流程；只有用户明确要求后台、无头、批量、自动化或不看过程时才允许 CLI/headless；只有用户明确指定当前 IDE 画布时才使用 VS Code / Cursor 插件例外；Desktop/MCP 不可用时必须停下说明。
- 2026-05-19 已轻量化结构：入口源默认只读 `workflow.md`；`workflow.md` 压成设计先行闸门；CLI/headless 细节拆到 `references/cli-headless.md`；MCP/IDE、保存位置、验证审查均按需读取；`global-frontend-design` 只保留 Pencil 画布证据闸门。
- 2026-05-19 已进一步处理双向引用：保留 `global-frontend-design` 对 Pencil 画布证据的硬闸门；Pencil 侧不再反向强引用 `global-frontend-design`，只定义 `.pen` 和导出图证据的交付契约。
- 2026-05-19 已补准 Desktop 打开链路：`workflow.md` 和 `references/pencil-modes.md` 明确先启动 Desktop 主窗口，再用 Pencil MCP 或 `pencil interactive -a desktop -i <file.pen>` 连接 Desktop transport；遇到 `transport not connected to app: desktop` 时停止诊断，不反复重试、不静默 CLI fallback。
- 2026-05-19 已实测验证：PowerShell 普通 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'` 会秒退且没有 `pencil-desktop` transport；`Invoke-Item 'C:\Program Files\Pencil\Pencil.exe'` 或 `explorer.exe 'C:\Program Files\Pencil\Pencil.exe'` 可以拉起真实 Desktop 窗口并创建 `\\.\pipe\pencil-desktop`。

## 已确认事实

- 本仓库全局 skill 事实源在 `skills/shared/<skill-name>/`。
- Claude Code 入口源在 `skills/claude-code/<skill-name>/SKILL.md`。
- Codex 入口源在 `skills/codex/<skill-name>/SKILL.md`。
- `scripts/render-skills.ps1`、`scripts/check-skills.ps1`、`scripts/sync-skills.ps1` 都硬编码 `$SkillNames`。
- 本机 Pencil CLI 已安装并登录：`pencil 0.2.6`，状态 Active。
- 本机 `pencil interactive --help` 明确 app 模式用法：`pencil interactive --app <name> [--in <file.pen>]` 连接运行中的 Pencil app；Desktop 示例为 `pencil interactive -a desktop -i design.pen`。
- 本机 `pencil interactive -a desktop` 在 Desktop transport 不存在时会报 `Transport connection failed: connect ENOENT \\.\pipe\pencil-desktop`；这与 MCP server 报 `transport not connected to app: desktop` 是同类根因。
- 已用 `pencil interactive -a desktop -i D:\Windows\桌面\Encoding\Ai-config-hub\designs\pencil\current-project-structure\design.pen` 确认当前活动编辑器为目标文件，并返回顶层节点 `ai-config-hub documentation dashboard`。
- Codex 中看到 Pencil MCP 自动配置，不代表 Claude Code 中一定已启用同一 MCP；执行可视化设计前必须在当前工具环境确认 Desktop/MCP 可用。
- 用户的最新偏好是：设计请求默认都要可见 Desktop/MCP 过程，不需要用户额外声明“我要看着做”；IDE 插件不是默认可视化替代。

## 已尝试 / 已排除

- 不直接复制官方 Pencil `SKILL.md` 全文，避免上游变化和归属混淆。
- 不把 Pencil skill 写成另一个通用前端实现 skill，避免和 `global-frontend-design` 冲突。
- 2026-05-19 已排除“Desktop/MCP 失败后自动改用 CLI/headless”的做法；这会违背设计请求默认可见的目标。
- 2026-05-19 已排除“把所有 Pencil/CLI/验证说明都放进默认上下文”的做法；这会让 Pencil MCP 与前端设计 skill 叠加时过重。

## 当前卡点

Desktop 打开链路规则已修正并已同步到本机用户级目录，等待日常使用继续观察。

## 下一步最小动作

1. 日常在 Claude Code / Codex 中使用设计请求验证：是否默认打开 Desktop/MCP，是否停止而不是静默 CLI fallback。
2. 若仍有误触发或上下文过重，再按实际失败场景微调入口或 workflow。

## 验证状态

- 同步前复核：`pencil-design-workflow` 源码、Claude Code/Codex 入口、三类 rendered 包、`render-skills.ps1` / `check-skills.ps1` / `sync-skills.ps1` 接入、registry、README、skills README、架构和同步文档均已就位。
- 已运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 已运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 已运行：`./scripts/sync-skills.ps1` dry-run。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标均为 `missing target`。
  - `global-frontend-design` 用户级 Claude Code / Codex 目标为 `would update managed target`，原因是新增了与 Pencil workflow 的交接说明。
  - 其他既有 skill 为 `unchanged`。
- 已运行：`./scripts/sync-skills.ps1 -IncludeCodexLegacy` dry-run，确认 legacy Codex 目标也包含 `pencil-design-workflow`；当前 legacy 目标均为 `missing target`，默认同步仍不包含 legacy。
- 2026-05-19 已重新运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 2026-05-19 已重新运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 2026-05-19 已重新运行：`./scripts/sync-skills.ps1` dry-run。
  - `global-frontend-design` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `project-ai-config-hub` 和 `global-thinking-partner` 用户级 Claude Code / Codex 目标为 `unchanged`。
- 2026-05-19 已运行：`git diff --check`，只有 Windows LF/CRLF 提示，未报告 whitespace error。
- 2026-05-19 轻量化后已重新运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包，并渲染新增的 `references/cli-headless.md`。
- 2026-05-19 轻量化后已重新运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 2026-05-19 轻量化后已重新运行：`./scripts/sync-skills.ps1` dry-run。
  - `global-frontend-design` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `project-ai-config-hub` 和 `global-thinking-partner` 用户级 Claude Code / Codex 目标为 `unchanged`。
- 2026-05-19 轻量化后已运行：`git diff --check`，只有 Windows LF/CRLF 提示，未报告 whitespace error。
- 2026-05-19 追加：Pencil 侧 verification 也改为“真实前端 review 流程”，避免默认或按需审查文档反向点名 `global-frontend-design`。
- 2026-05-19 双向引用瘦身后已重新运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 2026-05-19 双向引用瘦身后已重新运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 2026-05-19 双向引用瘦身后已重新运行：`./scripts/sync-skills.ps1` dry-run。
  - `global-frontend-design` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - `project-ai-config-hub` 和 `global-thinking-partner` 用户级 Claude Code / Codex 目标为 `unchanged`。
- 2026-05-19 双向引用瘦身后已运行：`git diff --check`，只有 Windows LF/CRLF 提示，未报告 whitespace error。
- 2026-05-19 已运行：`./scripts/sync-skills.ps1 -Apply`，已同步到本机 `C:\Users\sx200\.claude\skills\` 和 `C:\Users\sx200\.agents\skills\`，同步前已创建 timestamped backups。
- 2026-05-19 Apply 后已重新运行：`./scripts/sync-skills.ps1` dry-run，所有管理目标均为 `unchanged`。
- 2026-05-19 已抽查本机 `C:\Users\sx200\.claude\skills\pencil-design-workflow\workflow.md` 和 `C:\Users\sx200\.agents\skills\pencil-design-workflow\workflow.md`，均为轻量闸门版本，且两端都存在 `references/cli-headless.md`。
- 2026-05-19 Desktop 打开链路修正后已重新运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 2026-05-19 Desktop 打开链路修正后已重新运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 2026-05-19 Desktop 打开链路修正后已重新运行：`./scripts/sync-skills.ps1` dry-run。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标为 `would update managed target`。
  - 其他管理目标为 `unchanged`。
- 2026-05-19 Desktop 打开链路修正后已运行：`git diff --check`，只有 Windows LF/CRLF 提示，未报告 whitespace error。
- 2026-05-19 真实打开验证：先用 `Start-Process` 复现无进程、无 `pencil-desktop` transport、`pencil interactive -a desktop -i <file.pen>` 报 `connect ENOENT \\.\pipe\pencil-desktop`；再用 `explorer.exe 'C:\Program Files\Pencil\Pencil.exe'` / `Invoke-Item` 成功拉起 Desktop，出现 `pencil-desktop` transport，并确认目标 `.pen` 为当前活动编辑器。
- 2026-05-19 Windows 启动差异写入 skill 后已重新运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 2026-05-19 Windows 启动差异写入 skill 后已重新运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 2026-05-19 Windows 启动差异写入 skill 后已运行：`./scripts/sync-skills.ps1 -Apply`，并在 Apply 后 dry-run 确认所有管理目标均为 `unchanged`。

## 残留风险

- 已同步到 `C:\Users\sx200\.claude\skills\pencil-design-workflow\` 和 `C:\Users\sx200\.agents\skills\pencil-design-workflow\`；未同步历史 `.codex\skills`，符合用户确认的范围。
- 真实网页视觉验证已通过浏览器 MCP 配置分发链路同步；Pencil 画布验证仍不能等同完整真实浏览器 E2E 或像素级视觉回归。
- Windows/Git 提示部分文本文件 LF 将在下次 Git 触碰时替换为 CRLF；未见脚本检查失败。
- 当前仓库源文件、rendered 包和本机用户级 skill 已补准 Desktop transport 诊断与 Windows Shell/Explorer 启动方式；实际日常使用仍需继续观察是否还有 Claude Code MCP 配置侧差异。

## 相关文件

- `skills/shared/pencil-design-workflow/`：新增共享事实源。
- `skills/claude-code/pencil-design-workflow/SKILL.md`：新增 Claude Code 入口源。
- `skills/codex/pencil-design-workflow/SKILL.md`：新增 Codex 入口源。
- `skills/rendered/claude-code/pencil-design-workflow/`：新增 Claude Code rendered 包。
- `skills/rendered/codex/pencil-design-workflow/`：新增 Codex rendered 包。
- `skills/rendered/codex-legacy/pencil-design-workflow/`：新增 legacy rendered 包。
- `scripts/render-skills.ps1`：接入新 skill 渲染。
- `scripts/check-skills.ps1`：接入新 skill 检查。
- `scripts/sync-skills.ps1`：接入新 skill 同步。
- `docs/ai/skills-registry.md`：登记新 skill。
- `README.md`：补充新 skill 定位。
- `skills/shared/global-frontend-design/workflow.md`：补充设计先行交接说明。
- `skills/shared/global-frontend-design/templates/implementation-plan.md`：补充 Pencil 设计证据检查项。

## 不要重复

- 不要用普通 Read/Grep 读取 `.pen` 设计文件。
- 不要把 MCP server 握手成功当成 Pencil Desktop transport 已连接；必须确认 `pencil-desktop` transport 或等价画布状态。
- 不要用 `Pencil.exe <file.pen>` 作为打开 `.pen` 的方式；使用 Pencil MCP 或 `pencil interactive -a desktop -i <file.pen>`。
- Windows 下不要只依赖 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'`；如果它秒退，改用 `Invoke-Item` 或 `explorer.exe` 启动真实窗口。
- 不要把 Pencil 画布验证汇报成真实浏览器验证。
- 不要让 Pencil workflow 抢局部 UI bugfix 的触发。
- 不要把设计请求静默降级到 CLI/headless；除非用户明确要求后台、无头、批量、自动化或不看过程。
- 不要在 Pencil Desktop/MCP 未打开、未连接或没有画布证据时进入大规模前端实现。

## 关闭依据 / 最终结果

原始创建和首次同步已完成。2026-05-19 根据真实失败反馈重新打开任务并收紧规则，等待渲染检查和用户确认是否同步本轮更新。

# 工作任务：新增 Pencil 设计先行工作流 skill

任务 ID：2026-05-18-pencil-design-workflow
创建时间：2026-05-18 00:00
更新时间：2026-05-18 00:00
状态：已完成
当前活动：否

## 目标

新增并接入 `pencil-design-workflow` 全局 skill，使自然语言“做设计图”“先设计确认后写代码”等设计先行请求自动进入 Pencil / `.pen` / pencli 工作流，同时避免局部 UI bugfix 误触发。

## 背景和当前上下文

用户已确认：需要看设计过程时优先 Pencil Desktop + MCP；批量或无需看过程时使用 Pencil CLI/headless；VS 插件多窗口场景容易改到非当前画布，应谨慎使用；Pencil 画布验证不能等同于真实浏览器验证，Claude Code 真实前端视觉自检需要补 Playwright/浏览器 MCP。

官方 Pencil CLI skill 位于 `https://unpkg.com/@pencil.dev/cli@latest/SKILL.md`，本任务将其作为上游参考，不直接照搬。

## 最近结论

- 已新增 `pencil-design-workflow` 共享事实源、Claude Code 入口源、Codex 入口源和 rendered 包。
- 已接入 `render-skills.ps1`、`check-skills.ps1`、`sync-skills.ps1`。
- 已更新 registry、README 和 `global-frontend-design` 到 Pencil workflow 的交接说明。
- 已通过 render 和 check；sync dry-run 显示新 skill 尚未同步到用户级目录。

## 已确认事实

- 本仓库全局 skill 事实源在 `skills/shared/<skill-name>/`。
- Claude Code 入口源在 `skills/claude-code/<skill-name>/SKILL.md`。
- Codex 入口源在 `skills/codex/<skill-name>/SKILL.md`。
- `scripts/render-skills.ps1`、`scripts/check-skills.ps1`、`scripts/sync-skills.ps1` 都硬编码 `$SkillNames`。
- 本机 Pencil CLI 已安装并登录：`pencil 0.2.6`，状态 Active。

## 已尝试 / 已排除

- 不直接复制官方 Pencil `SKILL.md` 全文，避免上游变化和归属混淆。
- 不把 Pencil skill 写成另一个通用前端实现 skill，避免和 `global-frontend-design` 冲突。
- 未执行 `sync-skills.ps1 -Apply`，因为同步到用户级全局 skill 目录需要用户确认。

## 当前卡点

已完成，无卡点。

## 下一步最小动作

无需继续同步；用户已确认不需要历史 `.codex/skills` 兼容目录。

## 验证状态

- 同步前复核：`pencil-design-workflow` 源码、Claude Code/Codex 入口、三类 rendered 包、`render-skills.ps1` / `check-skills.ps1` / `sync-skills.ps1` 接入、registry、README、skills README、架构和同步文档均已就位。
- 已运行：`./scripts/render-skills.ps1`，成功生成 Claude Code、Codex、codex-legacy rendered 包。
- 已运行：`./scripts/check-skills.ps1`，输出 `Skill check passed`。
- 已运行：`./scripts/sync-skills.ps1` dry-run。
  - `pencil-design-workflow` 用户级 Claude Code / Codex 目标均为 `missing target`。
  - `global-frontend-design` 用户级 Claude Code / Codex 目标为 `would update managed target`，原因是新增了与 Pencil workflow 的交接说明。
  - 其他既有 skill 为 `unchanged`。
- 已运行：`./scripts/sync-skills.ps1 -IncludeCodexLegacy` dry-run，确认 legacy Codex 目标也包含 `pencil-design-workflow`；当前 legacy 目标均为 `missing target`，默认同步仍不包含 legacy。

## 残留风险

- 已同步到 `C:\Users\sx200\.claude\skills\pencil-design-workflow\` 和 `C:\Users\sx200\.agents\skills\pencil-design-workflow\`；未同步历史 `.codex\skills`，符合用户确认的范围。
- 真实网页视觉验证已通过浏览器 MCP 配置分发链路同步；Pencil 画布验证仍不能等同完整真实浏览器 E2E 或像素级视觉回归。
- Windows/Git 提示部分文本文件 LF 将在下次 Git 触碰时替换为 CRLF；未见脚本检查失败。

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

## 不要重复

- 不要用普通 Read/Grep 读取 `.pen` 设计文件。
- 不要把 Pencil 画布验证汇报成真实浏览器验证。
- 不要让 Pencil workflow 抢局部 UI bugfix 的触发。

## 关闭依据 / 最终结果

已执行 `./scripts/sync-skills.ps1 -Apply`，将 `pencil-design-workflow` 和更新后的相关全局 skills 同步到本机 Claude Code / Codex 用户级 skill 目录；同步后 `./scripts/sync-skills.ps1` dry-run 全部为 `unchanged`，`./scripts/check-all.ps1` 通过。

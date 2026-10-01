# 配置理念重构：规则瘦身与分发收敛

状态：进行中（仓库改动完成，用户级 Apply 未执行）
更新时间：2026-10-02

## 目标

按"规则只描述如何使用模型，世界事实由现场提供"的新理念重构这套配置：

- 规则层从行为手册改为协作契约（客观语态、否定式约束、按 lost-in-the-middle 排布）。
- 分发结构收敛：支持 `.agents` 的工具只配置 `.agents`，不支持的工具保留专属格式。
- MCP 去掉机器本地事实污染，修复阻断 Apply 的所有权判定缺陷。

## 已确认事实（依据）

- Claude Code 2.1.220（本机）低于 AGENTS.md 支持所需版本 2.1.277；官方 memory 文档明确「不读 `.agents/` 目录下的任何内容」。因此 Claude Code 必须保留 `~/.claude/CLAUDE.md` 与 `~/.claude/skills/` 专属格式。
- Grok 官方文档（`~/.grok/docs/user-guide/08-skills.md:29`）：「Grok also scans `.agents/skills/` (and `commands/`) at each tier (alongside `.grok/`)」。Grok 另有文档确认 `.codex` 发现机制 reserved and currently inert。
- 因此 skills 只需两个目标：`~/.claude/skills/` 与 `~/.agents/skills/`（Codex / OpenCode / Grok 共用）。

## 完成结果

- **规则层**：`rules/shared/core.md` 重写为六节协作契约（协作方式 / 信息不足时 / 用户偏好 / 文档与工作状态 / 边界 / 规则本身）；四个 `rules/tools/*.md` 去重。渲染后 `rules/rendered/CLAUDE.md` 从 8427 B 降到 4373 B。
- **去重**：context-thread CLI 契约原先在四个工具补充里各写一遍，现收敛到 `skills/shared/global-context-thread/workflow.md` 一处；`check.ps1` 的断言从「四处都要有」改为「只允许一处，补充文件里出现即失败」。
- **skills 分发**：目标从 4 个降到 2 个（移除 `CodexLegacy` 与 `Grok`）；删除 `skills/grok/`、`skills/opencode/` 残留；`skills/rendered/codex-legacy`、`skills/rendered/grok` 由 `RetiredRenderedRoots` 自动退役；Grok 用户级副本进入 `RetiredTargets`，dry-run 确认为 4 个 `would remove retired managed target`。
- **MCP**：
  - 机器本地代理 env 从共享片段 `tool-configs/mcp/shared/local-webfetch.json` 移到未跟踪的 `tool-configs/mcp/private/local-webfetch.env.json`，由 `sync-mcp.ps1` 新增的 `Add-PrivateMcpEnv` 在同步时合并（覆盖 ownership 比较与合并内容两条路径）。
  - 修复 `Test-ClaudeManagedOwnership`：legacy 签名比较原先丢弃 `env`，导致已安装的 `cmd /c` 形态带 env 条目被判为 custom conflict 并阻断 Apply。修复后 dry-run 从 `conflict` 变为 `update`。
- **验收**：`render.ps1 -Check` / `check.ps1` / `check-skills.ps1` / `check-mcp.ps1` 全部通过；`sync-skills.ps1` dry-run 计划正确。

## 残留

- **私有 overlay 是隐性依赖**：`tool-configs/mcp/private/local-webfetch.env.json` 未跟踪；若新机器缺该文件，下次 Apply 会写入**不带 env** 的 local-webfetch 条目，抓取将不再走代理。dry-run 会显示 `update mcpServers.local-webfetch`，但需人工判断该差异是否预期。
- **结构改动已做运行时验证**（2026-10-02 复查补做）：`grok inspect --json` 实测显示，`~/.grok/skills` 移开后四个 skill 全部仍由 `~/.agents/skills/` 发现（探针已复原）；因此退役 `~/.grok/skills` 不会让 Grok 丢 skill。
- 用户级 Apply 未执行：`sync.ps1 -Apply`、`sync-skills.ps1 -Apply`、`sync-mcp.ps1 -Apply` 都需要用户显式授权。执行后才会真正更新四个规则文件、退役 Grok skill 副本、并迁移 Claude 的 local-webfetch 条目形态。
- `docs/grok-build-surface.md` 的验证命令与「期望」段仍写 `~/.grok/skills`，尚未按新目标刷新；`docs/ai-config-design.md` 的分目标描述也未完全刷新。
- 本机 Claude Code 版本 2.1.220，低于 2.1.277；升级后才可能讨论是否用 AGENTS.md 承载用户级规则（当前不需要，`CLAUDE.md` 语义更合适）。
- 历史任务卡与 `docs/archive/` 中仍有 `codex-legacy` / `skills/grok` 的记载，属于历史记录，不作为事实源改写。

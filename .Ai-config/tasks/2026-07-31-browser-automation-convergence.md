# 工作任务：浏览器自动化能力收敛

任务 ID：2026-07-31-browser-automation-convergence
创建时间：2026-07-31
更新时间：2026-07-31
状态：已完成
当前活动：否

## 目标

退役 Playwright MCP，将日常浏览器自动化迁移到官方 Playwright CLI + skill；保留 Chrome DevTools MCP 作为专项调试能力，并把 local-webfetch 收窄为 Claude Code 专用。

## 已确认决策

- 不新增另一套 browser agent runtime。
- 不在 Hub 复制官方 Playwright CLI skill。
- OpenCode managed MCP 只保留 context-thread。
- 旧 Playwright/local-webfetch 只在 ownership 匹配时清理，同名自定义配置必须保留。

## 实施结果

- active manifest、profiles、rendered 片段和 browser runtime 已收敛；`@playwright/mcp` 已从 runtime 删除。
- ownership/retirement 迁移、相关测试、架构文档和 ADR 已更新。
- 用户级 `@playwright/cli@0.1.17` 及官方 `claude`/`agents` skills 已安装。
- Chrome-only runtime、Grok `core` 和 OpenCode `code-intel` 已 Apply；OpenCode 只保留 context-thread managed MCP。

## 验证

- `scripts/check-all.ps1` 通过：context-thread 37/37、local-webfetch 20/20、browser runtime 3/3、同步安全/profile/doctor 测试全部通过。
- Chrome DevTools Smoke 29/29，source/install hash 一致。
- Playwright CLI 已成功打开、快照并关闭 `https://example.com`。
- post-Apply dry-run：Claude/Codex/Grok `core` unchanged，OpenCode `code-intel` 无待执行 action。

## 关闭依据

计划内仓库实现、用户级安装、MCP/runtime Apply 和 post-Apply 验证均已完成。备份位于 `~/.ai-config-hub/backups/runtime-browser-mcp/20260731-121314-295-1521fcc7be9d426ab17676e572075a38/`、`~/.ai-config-hub/backups/mcp/20260731-121601-774-31c81b3086cd4ea48fc275524e8dc981/` 和 `~/.ai-config-hub/backups/mcp-opencode/20260731-121842-531-ae7ee8bb9211406689264ee943eacb41/`。

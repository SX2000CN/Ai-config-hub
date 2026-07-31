# OpenCode skill 通用路径收敛

状态：已完成
更新时间：2026-07-31

## 目标

让 Codex 和 OpenCode 共用官方支持的 `~/.agents/skills`，停止维护 `skills/opencode`、`skills/rendered/opencode` 与 `~/.config/opencode/skills` 中的重复 Hub skill 副本。

## 已确认事实

- Codex 默认目标已经是 `~/.agents/skills`。
- OpenCode 官方会发现用户级和项目级 `.agents/skills`。
- Codex 的四个 Hub SKILL 入口只使用 `name`、`description` 与正文，OpenCode 可以直接读取。
- 真实用户目录中的四个 OpenCode 原生副本均带对应 `ai-config-hub-managed` marker。
- OpenCode 还会扫描 `.claude/skills`，因此移除原生副本后仍可能对 Claude/Codex 同名安装给出 duplicate warning；本任务只移除 Hub 自己额外制造的第三份副本。

## 已完成

- 从 managed manifest 移除 OpenCode skill target，登记旧用户目标与 rendered root 的安全退役策略。
- 删除四个 `skills/opencode` 专属入口源和整个 `skills/rendered/opencode` 生成树。
- `sync-skills.ps1` 仅删除 marker 匹配的退役目录，无 marker 的同名用户目录会保留。
- 项目级 skill 工作流改为 `.agents/skills` 同时服务 Codex 和 OpenCode。
- README、架构、同步流程、OpenCode surface、skills registry 和 rendered 规则/skills 已同步更新。

## 验证

- `scripts/check-skills.ps1`：通过。
- `scripts/tests/sync-safety.ps1`：通过，覆盖托管副本删除和用户自有副本保留。
- `scripts/check-all.ps1`：通过；37/37 context-thread、20/20 local-webfetch、3/3 browser runtime 测试通过。
- `scripts/sync-skills.ps1` 真实用户目录 dry-run：计划移除四个 OpenCode 托管副本，并更新 Claude/Codex/Grok 的 `project-ai-config-hub` 包，无 ownership 冲突。

## 下一步

无。

## 完成依据

- `scripts/sync.ps1 -Apply` 已更新 `~/.config/opencode/AGENTS.md`；规则备份位于 `~/.ai-config-hub/backups/rules/20260731-125753-600-02dbf1802bf44e029fd7e6bab8d65bcc/`。
- `scripts/sync-skills.ps1 -Apply` 已更新 Claude/Codex/Grok 的 `project-ai-config-hub`，并退役四个 OpenCode 原生托管副本；skills 备份位于 `~/.ai-config-hub/backups/skills/20260731-130025-707-ce33e9da6385482c8c7d8fe3e1fb997a/`。
- post-Apply dry-run：规则和全部 active skill targets 均为 unchanged，四个 OpenCode 原生退役目标均为 absent。
- OpenCode CLI `1.16.2` 新进程执行 `debug skill`：6 个 skills 初始化成功，四个 Hub skills 和 Playwright CLI 的最终 location 均位于 `~/.agents/skills`，没有 `~/.config/opencode/skills` 来源。
- `.claude/skills` 与 `.agents/skills` 的同名 warning 仍存在，这是 OpenCode 官方同时扫描两套兼容目录的结果，不再包含 Hub 原生第三副本。

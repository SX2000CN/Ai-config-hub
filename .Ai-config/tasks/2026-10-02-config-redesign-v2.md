# 工作任务：配置理念重构与强制层落地

任务 ID：2026-10-02-config-redesign
创建时间：2026-10-02
更新时间：2026-10-15
状态：暂停
当前活动：否

## 2026-10-15 状态转交

本卡保留 2026-10-02 配置与部署工作的原始背景、已完成结果和未决验证。新的活动任务是 [可移植 Agent 配置本体优先重构](2026-10-15-portable-agent-config-source.md)，它调整本仓库的长期方向：完整 Skill 包和共享规则是内容本体，用户级同步、MCP 与 runtime 是可选集成。此状态转交不代表旧任务中 A/B 实验或 guard 端到端验证已完成。

## 目标

按"规则只承载禁止项、事故坑与不可推导事实；世界由现场提供"的理念，把这套配置从
"行为手册"改成"协作契约 + 强制层 + 可验证"，并补齐理念里缺失的过期轴与世界 brief。

## 现场

**意图**：让规则长期有效而不腐烂，让"每次都要强调"这件事消失。

**观察到的情况**：用户先前在开发上遇到瓶颈并停摆了一段时间；模型在这两个月又前进了一代；
用户记得 Anthropic 说过"删掉你的规则"，并担心多 agent 接力会带偏注意力。

**约束**：四个工具目标（Claude Code / Codex / OpenCode / Grok）都要继续可用；
Grok 的 hooks 不托管是既有 ADR 决策；不能破坏现有的 staging / 备份 / 回滚事务。

**未知项**：

- 已知未知：`permissions.deny` 与 PreToolUse hook 在本机 Claude Code 2.1.220 上的实际行为
  （已选择 hook 路径，因为其语义可单测）。
- 未知未知（blindspot pass）：合并 `~/.claude/settings.json` 是否会与 Claude Code 自身
  写入的键冲突；hook 是否会在 sync 脚本自身的 Apply 过程中拦截自己。

**已拍板的决策（含理由，不要重复问）**：

- 用 PreToolUse hook 而非 `permissions.deny`：边界语义是"先取得用户确认"，`ask` 精确对应。
- 只做 Claude Code 的强制层：Grok 不托管 hooks 是 ADR 决策，不在本次推翻。
- 世界 brief 并进任务卡模板，不另开文件：少一次跳转。
- 完整 30 对 A/B 实验不替用户跑（消耗其额度），只交付跑道与 smoke。

## 最近结论

- 规则层已单源化：四个工具收到逐字节相同的规则，工具事实移入按需 reference。

## 已确认事实

- Claude Code 2.1.220 < 2.1.277，AGENTS.md 支持不可用；官方文档明确不读 `.agents/`。
- Grok 官方文档确认扫描每一层的 `.agents/skills`，因此退役 `~/.grok/skills` 是安全的（已用
  `grok inspect --json` 探针实测：移开后四个 skill 仍被发现，来源切到 `~/.agents/skills`）。
- 实测中每一条单独有益的规则都是否定式约束，每一条单独有害的都是正向指令
  （Guardrails Beat Guidance）。
- 指令遵循随规则数量下降；上下文压缩会静默抹掉约束。

## 已尝试 / 已排除

- 排除 `permissions.deny`：语义无法在本会话验证，装一个可能不生效的边界比没有更糟。
- 排除记忆系统（mem0 / Zep / Letta）：基准全是对话 QA，且会变成第二份规则文件。

## 当前卡点

无。

## 下一步最小动作

1. 用户级 Apply：规则、skills、MCP、guard 部署。
2. 用一次真实长任务验证"世界 brief"是否真的省掉重复描述。

## 验证状态

- `check-all.ps1` 通过（含新增的 rules hygiene、guard 单测、guard 同步 dry-run）。
- guard 单测 24/24 通过，含反向用例（malformed 输入必须落向 `ask`）。

## 残留风险

- `tool-configs/mcp/private/local-webfetch.env.json` 是隐性依赖；缺失时 Apply 会写入不带 env 的条目。
- guard 的端到端拦截需在真实 Claude Code 会话里验证一次（本会话只能验证决策逻辑）。
- 工作区混有用户早期未提交改动与本次改动，提交时需分开。

## 相关文件

- `rules/shared/core.md`：协作契约（单源）。
- `rules/shared/core-rationale.md`：依据表，不渲染。
- `hooks/claude/guard.mjs`：强制层。
- `scripts/sync-claude-guard.ps1`：guard 部署与 settings 合并。
- `skills/shared/project-ai-config-hub/references/tool-surfaces.md`：工具事实。

## 不要重复

- 不要把工具事实写回常驻规则；它们在 tool-surfaces reference 里。
- 不要给规则加内容；方向是删和搬。

## 关闭依据 / 最终结果

待 Apply 与一次真实任务验证后填写。

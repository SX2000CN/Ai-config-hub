# 工作任务：可移植 Agent 配置本体优先重构

任务 ID：2026-10-15-portable-agent-config-source
创建时间：2026-10-15
更新时间：2026-10-15
状态：进行中
当前活动：是

## 目标

把 ai-config-hub 的长期维护中心转为可移植的共享规则与完整 Agent Skill 包。客户端发现路径作为 adapter；MCP、runtime 和用户级同步作为可选集成；`.Ai-config/` 仅承载项目状态与索引。

## 背景和当前上下文

本轮实施源于对 `.agents`、Agent Skills、客户端发现行为和现有事实源分裂的审查。旧的 `.Ai-config/skills` 内容源模型已由仓库约定的完整 `.agents/skills` 包取代；本仓库自身的完整包源目录仍为 `skills/shared/<name>/`。

## 已确认事实

- Agent Skills 规定包结构和 `SKILL.md` 字段，不规定客户端自动发现路径。
- `.agents/skills/` 是部分客户端支持的发现路径，不是万能配置标准。
- 本仓库以 `skills/shared/<name>/` 为每个 Skill 的唯一完整内容源，renderer 将同一包导出到 Claude 和 `.agents/` 对应路径。
- `.Ai-config/` 保存状态、任务卡、registry 与结构索引；Skill 内容不放在 `.Ai-config/skills/`。
- 旧入口和历史 rendered 路径保留为候选，不由普通渲染自动删除。

## 已完成

- [x] 将四个当前 Skill 内容迁为完整标准包源，并移除共享 `when_to_use` 自定义字段。
- [x] 改写主 README、架构、设计、skills 路线图和同步边界说明。
- [x] 修正项目级 AI config Skill 的 workflow、迁移参考与生成模板，避免继续生成薄包或将状态层当内容源。
- [x] 将 Grok 描述改为本机版本验证的可选 adapter，并为 Grok ADR 补充当前方向说明。
- [x] 让 Skill renderer 只消费唯一 `Names` 清单、限制输出到 `skills/rendered/` 并保留历史输出候选。

## 下一步最小动作

1. [x] 重新生成 `skills/rendered/` 中当前 Claude 与 `.agents/` 包。
2. [x] 运行 `scripts/check-skills.ps1`、规则检查和 `git diff --check`；MCP 导出检查仍报告本轮未修改的既有 Claude/OpenCode rendered 差异。
3. [x] 检查最终 diff、旧路径残留和 `.Ai-config/CURRENT.md` 状态。

## 验证状态

- 通过：`render-skills.ps1 -Check`、`check-skills.ps1`、`render.ps1 -Check`、`check.ps1`、`check-rules-hygiene.ps1`、`git diff --check`。
- 未完全通过：`check-all.ps1` 在 `check-mcp.ps1` 阶段报告 Claude/OpenCode rendered MCP 文件过期；本轮未修改 MCP source 或 rendered 文件，因此未刷新或扩大到 MCP 管线。
- 本轮不执行用户级 Apply、提交或推送。

## 残留风险

- `skills/claude-code/` 与 `skills/codex/` 仍有旧入口内容，保留为迁移 / 清理候选；清理需后续独立决定。
- 用户级 skill 与 MCP 目录可能仍保留旧导出；本任务不读取、改写或追平它们。
- Grok 对 `.agents/skills/` 的支持是本机版本证据，升级客户端后需复核；OpenCode `1.18.11` 同时扫描 `.agents/skills` 与 `.claude/skills`，双导出时需关闭 Claude Skills 兼容扫描或隔离发现根。

## 相关文件

- `skills/shared/`：完整 Skill 包源。
- `scripts/render-skills.ps1`、`scripts/check-skills.ps1`：包导出与验证。
- `docs/architecture.md`、`docs/ai-config-design.md`：当前架构边界。
- `skills/shared/project-ai-config-hub/references/official-paths.md`：客户端发现路径核验。

## 不要重复

- 不要把 `.agents/` 描述成 Agent Skills 万能标准或所有客户端自动发现路径。
- 不要恢复 `.Ai-config/skills/` 作为 Skill 内容源。
- 不要通过增加客户端目标、MCP profile 或 runtime 来表达共享内容。
- 不要执行用户级 Apply、提交或推送。

## 关闭依据 / 最终结果

仓库内规则与 Skill 只读验证已完成；`check-all.ps1` 仍因既有 Claude/OpenCode MCP rendered 差异未全绿。待用户审核本轮架构方向，并单独决定是否开启 MCP 导出修复或清理旧入口。

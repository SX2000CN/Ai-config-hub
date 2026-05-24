# 工作任务：优化 project-ai-config-hub 自身更新语义

任务 ID：2026-05-14-project-ai-config-hub-self-update
创建时间：2026-05-14
更新时间：2026-05-14
状态：已关闭
当前活动：否

## 目标

补充 `project-ai-config-hub` 在 `ai-config-hub` 本仓库中处理“更新项目 AI 配置 / 让项目配置和全局配置匹配”请求时的默认行为，避免先抛出不匹配的通用澄清选项。

## 背景和当前上下文

用户指出：刚才要求更新项目配置时，agent 已经读取了 `project-ai-config-hub`，但仍要求确认任务类型，而且选项中没有“本机全局配置已同步，现在追平项目 AI 配置状态”这一正确语义。分析结论是 skill 通用流程没有覆盖 `ai-config-hub` 自身项目的特殊语义，agent 也过度澄清。

## 最近结论

- `project-ai-config-hub` 需要明确区分目标项目是普通业务项目，还是 `ai-config-hub` 本仓库。
- 在本仓库中，“更新项目 AI 配置”默认应先按低风险只读审计 + 项目状态追平处理。
- 只有发现真实分叉且会写入不同事实源、覆盖全局目录或迁移/删除入口时，才询问用户取舍。

## 已确认事实

- 本仓库是 AI 配置中枢本身，维护全局规则、全局 skills、rendered 产物和本机同步流程。
- `project-ai-config-hub` 的事实源位于 `skills/shared/project-ai-config-hub/`。
- Claude Code / Codex 入口源分别位于 `skills/claude-code/project-ai-config-hub/SKILL.md` 和 `skills/codex/project-ai-config-hub/SKILL.md`。

## 已尝试 / 已排除

- 已排除只靠通用 `update/audit/repair` 分类处理该语义；这会导致错误澄清。
- 已排除把所有更新都自动同步到全局目录；写入用户级全局目录仍需确认。

## 当前卡点

无。

## 下一步最小动作

无。本任务已关闭；后续如需继续调整 `project-ai-config-hub` 的触发语义，应新建或重开任务卡。

## 验证状态

- `scripts/render-skills.ps1`：通过，已刷新 `project-ai-config-hub` 的 Claude Code / Codex / codex-legacy rendered 包。
- `scripts/check-skills.ps1`：通过，输出 `Skill check passed`。
- `scripts/sync-skills.ps1` dry-run：`project-ai-config-hub` 的 Claude Code / Codex 全局目标显示 `would update managed target`，其他默认全局 skill 为 `unchanged`。
- `scripts/sync-skills.ps1 -Apply`：已同步默认 Claude Code / Codex 全局 skill 目录，并为三个默认 skill 创建备份。
- 同步后 `scripts/sync-skills.ps1` dry-run：所有默认全局 skill 目标均为 `unchanged`。
- `git diff --check`：无 whitespace error，仅有 Windows LF/CRLF 提示。

## 残留风险

- 当前会话已加载的全局 skill 文本不会自动变更；新会话或重新加载 skill 后会使用已同步版本。

## 相关文件

- `skills/shared/project-ai-config-hub/workflow.md`：主流程规则。
- `skills/shared/project-ai-config-hub/README.md`：使用场景说明。
- `skills/claude-code/project-ai-config-hub/SKILL.md`：Claude Code 入口源。
- `skills/codex/project-ai-config-hub/SKILL.md`：Codex 入口源。

## 不要重复

- 不要在低风险只读审计前要求用户从通用更新类型中选择。
- 不要把反向覆盖项目源或写入全局目录作为无需确认的默认动作。

## 关闭依据 / 最终结果

已补充 `project-ai-config-hub` 在 `ai-config-hub` 本仓库中处理“更新项目 AI 配置 / 让项目配置和全局配置匹配”的默认语义，并同步到本机 Claude Code / Codex 全局 skill 目录；同步后 dry-run 全部为 `unchanged`，任务关闭。

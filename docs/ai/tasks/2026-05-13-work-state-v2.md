# 工作任务：多任务智能工作状态机制 v2

任务 ID：2026-05-13-work-state-v2
创建时间：2026-05-13
更新时间：2026-05-13
状态：待用户确认
当前活动：否

## 目标

把当前单槽位 `docs/ai/CURRENT.md` 工作状态机制升级为“接手入口 + 多任务状态总览 + 任务无损接手卡”，并同步全局规则与 `project-ai-config-hub` 分身 skill。

## 背景和当前上下文

用户指出 v1 机制要求每次完成都手动归档，且不支持功能 A 中途插入功能或 bug B 的多任务场景。项目本身是 AI 配置中枢，不能把主 `README.md` 写成固定 agent 接手入口；接手入口应位于 `docs/ai/CURRENT.md`，并按任务类型导航到真实事实源。

## 最近结论

- `docs/ai/CURRENT.md` 应是接手入口和状态总览。
- `docs/ai/tasks/*.md` 应是任务事实源和无损接手卡。
- 全局规则只写通用行为约束，具体模板和迁移流程由项目文档与 `project-ai-config-hub` 分身 skill 承担。
- 本轮已修复审计发现的关闭规则歧义、状态流转缺口、v1 迁移状态覆盖不足、缺失 `checklists.md.tpl`、入口触发条件不完整和检查脚本覆盖不足问题。

## 已确认事实

- 主 `README.md` 只作为项目概览补充，不作为固定 agent 接手入口。
- `project-ai-config-hub` 分身 skill 需要支持目标项目 v2 初始化、v1 迁移、审计和修复。
- 不引入数据库、JSON 状态机、hook 或复杂自动化。

## 已尝试 / 已排除

- 排除了继续使用单槽位 `CURRENT.md` 承载完整任务上下文。
- 排除了把主 `README.md` 作为所有 agent 固定第一入口。
- 排除了过宽的自动关闭规则，改为默认 `待用户确认`。

## 当前卡点

等待用户审核本轮修复后的完整 diff。

## 下一步最小动作

1. 用户审核修复后的 diff。
2. 如用户确认通过，可将本任务标为 `已关闭`。
3. 如用户要求调整，继续修改对应文档、模板、入口或检查脚本。

## 验证状态

- `./scripts/render.ps1`：已生成 `rules/rendered/CLAUDE.md` 和 `rules/rendered/AGENTS.md`。
- `./scripts/render-skills.ps1`：已生成三套 `skills/rendered/` 包。
- `./scripts/check.ps1`：通过。
- `./scripts/check-skills.ps1`：通过；新增检查覆盖 `checklists.md.tpl` 存在性、shared/rendered payload 一致性和典型 v1 状态机制禁用短语。
- `./scripts/sync.ps1`：dry-run 曾显示全局规则目标 would update；随后已执行 `./scripts/sync.ps1 -Apply`，并创建 `C:\Users\sx200\.claude\CLAUDE.md.20260513-185611.bak` 与 `C:\Users\sx200\.codex\AGENTS.md.20260513-185611.bak`。
- `./scripts/sync-skills.ps1`：dry-run 曾显示 Claude Code / Codex skill 目标 would update managed target；随后已执行 `./scripts/sync-skills.ps1 -Apply`，并创建 `C:\Users\sx200\.claude\skills\project-ai-config-hub.20260513-185629.bak` 与 `C:\Users\sx200\.agents\skills\project-ai-config-hub.20260513-185629.bak`。
- `./scripts/sync-skills.ps1 -IncludeCodexLegacy`：dry-run 显示 legacy Codex 目标 missing target，未应用。
- `git diff --check`：无空白错误；输出包含 Windows LF/CRLF 提示。
- `git status --short`、`git diff --stat`：已查看当前变更范围。
- 同步后 `./scripts/sync.ps1` dry-run：全局规则目标均为 unchanged。
- 同步后 `./scripts/sync-skills.ps1` dry-run：默认 Claude Code / Codex skill 目标均为 unchanged。

## 残留风险

- 真实全局规则和默认 Claude Code / Codex skill 目录已同步到本机；历史 `.codex/skills` 兼容目标仍未创建或应用。
- 用户尚未审核修复后的 diff，因此本任务保持 `待用户确认`。
- Windows Git 输出 LF/CRLF 提示；当前未作为错误处理。

## 相关文件

- `docs/work-state-design.md`：v2 机制设计。
- `docs/ai/CURRENT.md`：当前状态总览。
- `rules/shared/core.md`：全局通用行为约束。
- `skills/shared/project-ai-config-hub/`：分身 skill 事实源。

## 不要重复

- 不要把主 `README.md` 写成固定 agent 接手入口。
- 不要把未确认或未验证任务直接标为已关闭。

## 关闭依据 / 最终结果

已完成 v2 实现、审计问题修复和本机默认同步，并通过本地检查与同步后 dry-run 校验；等待用户确认后关闭。

# 当前工作状态

更新时间：2026-05-13
当前活动任务：无

## 接手导航

1. 先读本文件，判断是否有当前活动任务和任务卡。
2. 再按需读 `docs/ai/README.md`，理解本项目 AI 协作中枢边界。
3. 如果任务涉及全局规则，读 `rules/shared/core.md`、`rules/tools/` 和 `templates/`。
4. 如果任务涉及 `project-ai-config-hub` skill，读 `skills/shared/project-ai-config-hub/` 和 `skills/claude-code/`、`skills/codex/` 下的入口源。
5. 如果任务涉及渲染、检查或同步，读 `scripts/render*.ps1`、`scripts/check*.ps1`、`scripts/sync*.ps1` 和 `docs/sync-workflow.md`。
6. 需要理解整体数据流时，读 `docs/architecture.md`。
7. `README.md` 只作为项目概览补充，不是固定的 agent 接手入口。

## 当前活动任务

- 无。

## 待用户确认

- `docs/ai/tasks/2026-05-13-work-state-v2.md`：多任务智能工作状态机制 v2 已完成实现和审计问题修复，文档、规则、模板、入口、检查脚本和 rendered 产物已更新，等待用户审核。
- `docs/ai/tasks/2026-05-13-global-frontend-design.md`：`global-frontend-design` 已达到本机全局 skill 完全体，Claude Code / Codex 用户级目录已同步且 dry-run 为 unchanged，等待用户实际触发确认。

## 暂停 / 阻塞

- 暂无。

## 最近关闭

- 初始化项目 AI 配置中枢：已由用户确认完成，归档见 `docs/ai/archive/2026-05-09-init-ai-config-hub.md`。

## 接手规则

- 开始非简单任务前，先判断是否需要创建或更新 `docs/ai/tasks/*.md` 任务卡。
- 切换任务前，先保存当前任务状态，不要覆盖旧任务卡。
- 未确认、未验证或有残留风险的任务不要直接关闭，应保持为待用户确认、等待验证、暂停或阻塞。
- 任务关闭时应记录结果、验证情况、残留风险和关闭依据。

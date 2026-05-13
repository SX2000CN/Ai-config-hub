# 项目级 AI 配置中枢

本目录记录当前项目的 AI 协作状态、项目级 skills 清单和维护约定。

## 目录

- `CURRENT.md`：AI 接手入口和当前工作状态总览。
- `tasks/`：多任务工作状态卡，保存单个任务的无损接手信息。
- `archive/`：可选长期整理目录，只在用户明确要求整理或归档长期摘要时使用。
- `skills-registry.md`：项目级 skills 清单、事实源、入口和状态。
- `skills/`：面向项目自身的项目级 skill 事实源目录。

## 当前工作状态

开始非简单任务前，先读取 `docs/ai/CURRENT.md`，判断是否有当前活动任务和对应任务卡。若存在 `docs/ai/tasks/*.md`，应按 `CURRENT.md` 指引读取对应任务卡。

`CURRENT.md` 是接手入口和状态总览，不替代 README、CHANGELOG、issue、PR 或 git log；具体任务事实保存在 `docs/ai/tasks/*.md`。

切换任务前应保存旧任务状态，不能直接覆盖。完成一轮工作但用户尚未确认时，应保持为待用户确认或等价状态，并记录验证情况、残留风险和下一步。日常关闭任务不要求移动到 `archive/`，但必须记录关闭依据。

## Skills 约定

- `docs/ai/skills/<skill-name>/` 默认作为项目级 skill 的事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 项目入口。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 项目入口。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 工具入口只做薄入口，不复制完整项目规则。

## 本仓库说明

本仓库同时维护全局规则和可同步到用户级目录的 `project-ai-config-hub` skill。该 skill 的长期事实源仍位于 `skills/shared/project-ai-config-hub/`，并通过 `scripts/render-skills.ps1` 生成 rendered 包；`docs/ai/` 只承担当前仓库的 AI 协作中枢职责。

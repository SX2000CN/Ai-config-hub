# 项目级 AI 配置中枢

本目录记录当前项目的 AI 协作状态、项目级 skills 清单和维护约定。

## 目录

- `CURRENT.md`：当前未归档工作的 AI 协作交接状态。
- `archive/`：用户确认归档后的历史状态摘要。
- `skills-registry.md`：项目级 skills 清单、事实源、入口和状态。
- `skills/`：面向项目自身的项目级 skill 事实源目录。

## 当前工作状态

开始非简单任务前，先读取 `docs/ai/CURRENT.md`，用于恢复当前工作现场。当目标、关键结论、已尝试或已排除方向、卡点、下一步发生明显变化时，应刷新该文件。

`CURRENT.md` 只保存当前未归档工作的交接状态，不替代 README、CHANGELOG、issue、PR 或 git log。

AI 不得自行归档当前状态；只有用户明确确认通过、没问题、任务结束或要求归档时，才可归档。若 AI 认为一轮工作已完成但用户尚未确认，应把状态保持为待用户审核。

## Skills 约定

- `docs/ai/skills/<skill-name>/` 默认作为项目级 skill 的事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 项目入口。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 项目入口。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 工具入口只做薄入口，不复制完整项目规则。

## 本仓库说明

本仓库同时维护全局规则和可同步到用户级目录的 `project-ai-config-hub` skill。该 skill 的长期事实源仍位于 `skills/shared/project-ai-config-hub/`，并通过 `scripts/render-skills.ps1` 生成 rendered 包；`docs/ai/` 只承担当前仓库的 AI 协作中枢职责。

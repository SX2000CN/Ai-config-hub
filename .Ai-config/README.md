# 项目级 AI 配置中枢

本目录记录当前项目的 AI 协作状态、项目级 skills 清单和维护约定。它是项目状态层，不是整套 AI 配置设计的全部。

整套配置的设计目标、问题域和分层实现见：[../docs/ai-config-design.md](../docs/ai-config-design.md)。

## 目录

- `CURRENT.md`：AI 接手入口和当前工作状态总览。
- `tasks/`：多任务工作状态卡，保存单个任务的无损接手信息。
- `archive/`：可选长期整理目录，只在用户明确要求整理或归档长期摘要时使用。
- `skills-registry.md`：项目级 skills 清单、事实源、入口和状态。
- `skills/`：面向项目自身的项目级 skill 事实源目录。

## 与 docs/ 的边界

- 长期设计文档放在 `docs/`，例如 `docs/ai-config-design.md`、`docs/context-thread/`、`docs/work-state-design.md`。
- `.Ai-config/` 只保存当前项目 AI 接手所需状态、任务事实和项目级 skill 登记。
- 任务卡可以链接长期文档，但不要把长期设计说明复制进任务卡。

本仓库自己作为全局配置源时的特殊语义（例如"更新项目配置"在这里的含义），记录在仓库根目录的 `CLAUDE.md`，不在本文件展开。

## 当前工作状态

任务有接手价值、可能跨会话、涉及多任务切换或属于高风险修改时，先读取 `.Ai-config/CURRENT.md`，判断是否有当前活动任务和对应任务卡。简单问答、一次性命令和一轮内完成的小修复，不需要启动完整状态流程。若存在当前活动任务，应按 `CURRENT.md` 指引读取对应任务卡。

`CURRENT.md` 是接手入口和状态总览，不替代 README、CHANGELOG、issue、PR 或 git log；具体任务事实保存在 `.Ai-config/tasks/*.md`。

切换任务前应保存旧任务状态，不能直接覆盖。完成一轮工作但用户尚未确认，且涉及文件修改、配置修改、同步风险、验证缺失或残留风险时，应保持为待用户确认或等价状态，并记录验证情况、残留风险和下一步。日常关闭任务不要求移动到 `archive/`，但必须记录关闭依据。

## Skills 约定

- 普通目标项目中，`.Ai-config/skills/<skill-name>/` 是项目级 skill 的 canonical 事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 项目入口，不承载长期规则。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 项目入口，不承载长期规则。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 工具入口只做薄入口，不复制完整项目规则。

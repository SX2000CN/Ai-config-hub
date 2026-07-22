# 项目级 AI 配置中枢

本目录记录当前项目的 AI 规则、工作状态、项目级 skills、工具入口和维护约定。

## 目录

- `CURRENT.md`：AI 接手入口和当前工作状态总览。
- `tasks/`：多任务工作状态卡，保存单个任务的无损接手信息。
- `archive/`：可选长期整理目录，保留用户确认后的历史摘要。
- `skills-registry.md`：项目级 skills 清单。
- `skills/`：项目级 skill 事实源。

## 当前工作状态

如果存在 `.Ai-config/CURRENT.md`，在任务有接手价值、可能跨会话、涉及多任务切换或属于高风险修改时先读取它，判断是否有当前活动任务和对应任务卡。简单问答、一次性命令和一轮内完成的小修复，不需要启动完整状态流程。

`CURRENT.md` 是接手入口和状态总览，不替代 README、CHANGELOG、issue、PR 或 git log；具体任务事实保存在 `.Ai-config/tasks/*.md`。

切换任务前应保存旧任务状态，不能直接覆盖。完成一轮工作但用户尚未确认，且涉及文件修改、配置修改、同步风险、验证缺失或残留风险时，应保持为待用户确认或等价状态，并记录验证情况、残留风险和下一步。日常关闭任务不要求移动到 `archive/`，但必须记录关闭依据。

## 约定

- `.Ai-config/CURRENT.md` 应提供当前项目自己的接手导航，不强制把主 README 作为固定第一入口。
- `.Ai-config/tasks/*.md` 用于保存跨会话、被打断、等待确认、阻塞或有残留风险任务的目标、上下文、已尝试/已排除、验证、风险和下一步。
- `.Ai-config/skills/<skill-name>/` 是具体项目级 skill 的 canonical 事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 工具入口，不承载长期规则。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 工具入口，不承载长期规则。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 工具入口只做薄入口，不复制完整业务规则。

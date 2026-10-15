# 项目级 AI 配置中枢

本目录记录当前项目的 AI 工作状态、任务事实、Skill registry 和结构索引。它不是规则或 Skill 内容的事实源。

## 目录

- `CURRENT.md`：AI 接手入口和当前工作状态总览。
- `tasks/`：多任务工作状态卡，保存单个任务的无损接手信息。
- `archive/`：可选长期整理目录，保留用户确认后的历史摘要。
- `skills-registry.md`：项目级 skills 清单。
- `context-thread/`：可选的项目结构索引数据。

## 内容位置

- 项目规则放在 `AGENTS.md`、`CLAUDE.md` 或相应客户端的规则入口。
- 可移植的 Skill 内容放在完整 Agent Skill 包中，例如项目约定的 `.agents/skills/<name>/`。
- `.Ai-config/skills-registry.md` 只登记包位置、客户端 adapter 和状态。
- OpenCode 也扫描 `.claude/skills/` 兼容目录；若同一个包同时导出到 `.agents/skills/` 和 `.claude/skills/`，需在 OpenCode 进程环境关闭 Claude Skills 兼容扫描。

## 当前工作状态

如果存在 `.Ai-config/CURRENT.md`，在任务有接手价值、可能跨会话、涉及多任务切换或属于高风险修改时先读取它，判断是否有当前活动任务和对应任务卡。简单问答、一次性命令和一轮内完成的小修复，不需要启动完整状态流程。

`CURRENT.md` 是接手入口和状态总览，不替代 README、CHANGELOG、issue、PR 或 git log；具体任务事实保存在 `.Ai-config/tasks/*.md`。

切换任务前应保存旧任务状态，不能直接覆盖。完成一轮工作但用户尚未确认，且涉及文件修改、配置修改、同步风险、验证缺失或残留风险时，应保持为待用户确认或等价状态，并记录验证情况、残留风险和下一步。日常关闭任务不要求移动到 `archive/`，但必须记录关闭依据。

## 约定

- `.Ai-config/CURRENT.md` 应提供当前项目自己的接手导航，不强制把主 README 作为固定第一入口。
- `.Ai-config/tasks/*.md` 用于保存跨会话、被打断、等待确认、阻塞或有残留风险任务的目标、上下文、已尝试/已排除、验证、风险和下一步。
- `.agents/skills/<skill-name>/` 是具体项目级 skill 的 canonical 事实源。
- `.agents/skills/<skill-name>/` 保存完整包，Codex / OpenCode 可从该目录发现；它不是 Agent Skills 规范指定的发现位置。
- `.claude/skills/<skill-name>/` 是需要 Claude Code 时从同一完整包导出的 adapter。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 多个客户端发现目录应包含同一完整包，不维护不同的业务规则副本。

# 项目级 AI 配置中枢

本目录记录当前项目的 AI 协作状态、项目级 skills 清单和维护约定。它是项目状态层，不是整套 AI 配置设计的全部。

整套配置的设计目标、问题域和分层实现见：[../docs/ai-config-design.md](../docs/ai-config-design.md)。

## 目录

- `CURRENT.md`：AI 接手入口和当前工作状态总览。
- `tasks/`：多任务工作状态卡，保存单个任务的无损接手信息。
- `archive/`：可选长期整理目录，只在用户明确要求整理或归档长期摘要时使用。
- `skills-registry.md`：项目级 skills 清单、事实源、入口和状态。
- `skills/`：仅保留历史入口说明，不保存 Skill 包、评测或导出。本仓库完整包源位于 `.agents/skills/<name>/`，评测位于 `skills/evals/`。

## 与 docs/ 的边界

- 长期设计文档放在 `docs/`，例如 `docs/ai-config-design.md`、`docs/context-thread/`、`docs/work-state-design.md`。
- `.Ai-config/` 只保存当前项目 AI 接手所需状态、任务事实、路径 registry 和项目结构索引；不保存通用规则或完整 Skill 内容。
- 任务卡可以链接长期文档，但不要把长期设计说明复制进任务卡。

本仓库自己作为全局配置源时的特殊语义（例如"更新项目配置"在这里的含义），记录在仓库根目录的 `CLAUDE.md`，不在本文件展开。

## 当前工作状态

任务有接手价值、可能跨会话、涉及多任务切换或属于高风险修改时，先读取 `.Ai-config/CURRENT.md`，判断是否有当前活动任务和对应任务卡。简单问答、一次性命令和一轮内完成的小修复，不需要启动完整状态流程。若存在当前活动任务，应按 `CURRENT.md` 指引读取对应任务卡。

`CURRENT.md` 是接手入口和状态总览，不替代 README、CHANGELOG、issue、PR 或 git log；具体任务事实保存在 `.Ai-config/tasks/*.md`。

切换任务前应保存旧任务状态，不能直接覆盖。只有被打断、等待确认、验证缺失或有残留风险的跨会话任务才持续记录状态；普通仓库内可逆修改通过相关验证后可结束。仍需独立处理的问题应保留事实与下一步，不能写成已通过。日常关闭任务不要求移动到 `archive/`，但必须记录关闭依据。

## Skills 约定

`.Ai-config/skills-registry.md` 只登记包位置和客户端 adapter。本仓库自身的完整包源位于 `.agents/skills/<skill-name>/`；`.agents/skills/` 同时是本项目首选的发现路径，但不是 Agent Skills 规范规定的唯一发现路径。Claude Code 需要 `.claude/skills/<skill-name>/` adapter 才能发现包；本仓库当前暂停该导出。不要把 `.Ai-config/` 当作规则或 Skill 内容事实源。

---
name: global-context-thread
description: 在调用链、影响面、模块关系或复杂工作流关系确实需要结构化事实源时使用 context-thread、.Ai-config 任务卡等工具，同时保持 F0/F1 小任务轻量。
when_to_use: 用户询问调用链、影响面、模块关系、复杂配置关系、跨文档工作流、任务依赖、多人或多 AI 接手，或任务需要减少大范围 grep/read 探索时使用；简单问答、小修小补、一次性命令、明确局部文件任务、纯 Markdown/任务卡状态分析不使用。
---

# 全局脉络

<!-- ai-config-hub-managed: global-context-thread -->

当任务涉及复杂代码关系、配置关系、调用链、影响面、跨文档工作流、任务依赖或多人 / 多 AI 接手，并且结构化事实源能明显减少搜索成本时，使用本 skill。明确局部文件任务、纯文档状态判断或一次搜索能解决的问题，不进入本流程。

行动前按需读取：

1. `workflow.md`
2. `references/context-thread-tools.md`
3. `references/workflow-relation-index.md`

关键规则：

- 默认轻量：F0/F1 小任务不自动初始化 context-thread，不创建任务卡，不强迫走图谱流程。
- 反触发：明确文件的小修、纯 Markdown / 任务卡状态分析、一次精准搜索能解决的问题，不使用本 skill。
- 级联边界：本 skill 不自动拉起 `project-ai-config-hub`、思维伙伴或任务卡更新流程；只在主任务路由确认需要时切换或叠加。
- context-thread 只负责代码结构关系；产品需求、用户当前说明、真实文件和验证结果优先级更高。
- 没有可用索引或 MCP 工具时，直接回退到 `rg` / 文件读取，不把缺工具变成阻塞。
- 非代码复杂工作流用 `.Ai-config/CURRENT.md` 和任务卡的关系索引承接，不引入新的数据库或图谱系统。
- 修改后不要盲信旧索引；关键事实以当前文件、运行结果和必要验证为准。

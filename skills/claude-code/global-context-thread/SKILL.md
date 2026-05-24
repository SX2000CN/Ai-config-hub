---
name: global-context-thread
description: 在代码关系、配置关系或非代码工作流关系复杂时，优先使用 context-thread、.Ai-config 任务卡等结构化事实源建立上下文，同时保持 L0/L1 小任务轻量。
when_to_use: 用户询问调用链、影响面、模块关系、配置关系、项目结构、跨文档工作流、任务依赖、多人或多 AI 接手，或任务需要减少大范围 grep/read 探索时使用；简单问答、小修小补、一次性命令和明确局部文件任务不使用。
---

# 全局脉络

<!-- ai-config-hub-managed: global-context-thread -->

当任务涉及复杂代码关系、配置关系、调用链、影响面、跨文档工作流、任务依赖或多人 / 多 AI 接手时，使用本 skill。目标是先找当前可查询的结构化事实源，再决定是否读取文件或更新文档，减少靠长文档和大范围搜索硬猜。

行动前按需读取：

1. `workflow.md`
2. `references/context-thread-tools.md`
3. `references/workflow-relation-index.md`

关键规则：

- 默认轻量：L0/L1 小任务不自动初始化 context-thread，不创建任务卡，不强迫走图谱流程。
- context-thread 只负责代码结构关系；产品需求、用户当前说明、真实文件和验证结果优先级更高。
- 没有可用索引或 MCP 工具时，直接回退到 `rg` / 文件读取，不把缺工具变成阻塞。
- 非代码复杂工作流用 `.Ai-config/CURRENT.md` 和任务卡的关系索引承接，不引入新的数据库或图谱系统。
- 修改后不要盲信旧索引；关键事实以当前文件、运行结果和必要验证为准。

# global-context-thread

`global-context-thread` 是“脉络”全局 skill。它把 context-thread 的核心思路抽象为一条通用工作流：关系复杂时，先找可查询、可同步的事实源，再读取必要文件或更新必要文档。

## 定位

- context-thread 是代码结构 provider，负责符号、调用、影响面和文件关系。
- `.Ai-config/CURRENT.md` 与任务卡是非代码工作流 provider，负责任务依赖、状态、证据和下一步。
- 本 skill 是路由层，不是新的项目管理流程。
- 小任务不触发图谱仪式；没有可用工具时正常回退。
- context-thread 索引是项目级事实源，不是全局共享数据库；每个目标项目按需初始化自己的 `.Ai-config/context-thread/context-thread.db`。
- 索引自动同步只在 MCP server 正在运行且 watcher 可用时成立；否则使用目标项目 wrapper，或用 `node` 加用户级 runtime 完整路径执行 `sync`，也可以回到当前文件确认。不要假设 `context-thread` 是全局命令。

## 文件说明

- `workflow.md`：核心触发、路由和退出规则。
- `references/workflow-relation-index.md`：非代码任务关系索引格式。

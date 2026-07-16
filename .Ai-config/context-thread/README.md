# Context-thread 索引目录

本目录是当前项目的脉络索引位置。

脉络的长期设计和技术实现文档位于 `docs/context-thread/`。本文件只记录当前项目索引目录的使用约定和当前状态。

约定：

- 索引数据库位置：`.Ai-config/context-thread/context-thread.db`
- 错误日志位置：`.Ai-config/context-thread/errors.log`
- 是否初始化索引由实际关系复杂度触发，不作为简单问答和普通局部任务的默认动作。
- 新索引默认使用 `structure` 内容策略，并默认在目录 `.gitignore` 中忽略 `context-thread.db`。
- 当前仓库显式选择跟踪数据库，作为项目级结构化事实源；初始化其他项目时必须使用 `--track-db` 才会允许跟踪。
- `rich` 会额外持久化 docstring、signature、decorators、type parameters、edge metadata 和 unresolved candidates，只应在明确接受该内容边界时启用。
- SQLite 运行时临时文件、日志、锁文件和缓存不提交到仓库。

当前项目已初始化 context-thread 索引。最近一次索引结果：

- 文件：105
- 节点：1,677
- 边：4,713
- 数据库大小：约 2.21 MiB
- 内容策略：`structure`
- Git 状态：tracked
- Journal：`wal`
- Pending changes：0
- Schema：5
- Structure guards：6
- Rich payload rows：0

代码结构发生变化后，按需运行 `.\scripts\context-thread.ps1 sync .` 更新索引；如果需要重建索引，可重新执行 `.\scripts\context-thread.ps1 init . --index`。

如果 MCP server 正在运行且 watcher 可用，受支持源码变更会自动触发增量同步；否则索引不会自己更新。复杂关系任务前可先看 `context_thread_status` 或运行 `.\scripts\context-thread.ps1 status .`，若出现 pending changes，再手动 sync 或读取当前文件确认关键事实。

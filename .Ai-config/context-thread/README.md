# Context-thread 索引目录

本目录是当前项目的脉络索引位置。

约定：

- 索引数据库位置：`.Ai-config/context-thread/context-thread.db`
- 错误日志位置：`.Ai-config/context-thread/errors.log`
- 是否初始化索引由实际任务触发，不作为 L0/L1 小任务默认动作。
- `context-thread.db` 可以提交到仓库，作为项目级结构化事实源。
- SQLite 运行时临时文件、日志、锁文件和缓存不提交到仓库。

当前项目已初始化 context-thread 索引。最近一次索引结果：

- 文件：84
- 节点：1,410
- 边：4,083
- 数据库大小：约 4.36 MB

代码结构发生变化后，按需运行 `.\scripts\context-thread.ps1 sync .` 更新索引；如果需要重建索引，可重新执行 `.\scripts\context-thread.ps1 init . --index`。

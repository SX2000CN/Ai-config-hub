# context-thread 工具选择

context-thread 是代码结构 provider。它适合回答“代码如何连接”，不适合替代需求判断、测试或最新文件确认。

## 工具映射

| 问题 | 优先工具 |
|---|---|
| 这个功能 / 区域怎么工作 | `context_thread_context` |
| 找符号、类、函数、接口 | `context_thread_search` |
| 谁调用了这个符号 | `context_thread_callers` |
| 这个符号调用了什么 | `context_thread_callees` |
| 改这里会影响什么 | `context_thread_impact` |
| 看单个符号签名、docstring 或必要源码 | `context_thread_node` |
| 一次看多个相关符号源码 | `context_thread_explore` |
| 看索引文件树 | `context_thread_files` |
| 看索引健康和是否初始化 | `context_thread_status` |

## 反模式

- 不要为找符号先大范围 grep；先 `context_thread_search`。
- 不要用 `search + node` 代替 `context`；需要任务上下文时直接 `context_thread_context`。
- 不要循环很多次 `context_thread_node`；需要多个相关源码时用一次 `context_thread_explore`。
- 不要把索引结果当成修改后的最终事实；编辑后用当前文件和验证兜底。
- 不要因为 context-thread 不可用就阻塞小任务；直接回退到普通读文件流程。

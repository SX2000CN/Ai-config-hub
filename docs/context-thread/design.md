# 脉络设计说明

脉络是 `ai-config-hub` 的结构化事实层。它的目标是让 AI 在面对复杂代码关系、配置关系和跨会话工作流时，先使用可查询、可同步、低噪音的事实源缩小理解范围，再读取必要文件和运行验证。

它解决的是“关系理解成本”和“AI 幻觉来源”问题，不是要把每个任务都变成图谱流程。

## 设计动机

普通 AI 编码流程在复杂项目里容易遇到几类问题：

- 需要理解调用链、影响面、模块依赖时，靠大范围 `rg` 和多次文件读取成本高。
- 长文档很容易过期，AI 如果只相信总结，会把旧状态当事实。
- 代码结构关系和产品/流程关系混在一起时，文档容易变成流水账。
- 多 AI 或跨会话接手时，任务状态、证据、下一步和代码关系常常分散在对话里。

脉络把这些问题拆成两类：

- 代码结构关系：用项目本地索引和 MCP 工具查询。
- 非代码工作流关系：用 `.Ai-config` 任务卡的关系索引记录。

两者共同服务同一个目标：让 AI 先抓住关系，再读真实文件确认。

## 核心原则

- 默认轻量：L0/L1 小任务不初始化索引、不创建任务卡、不强制使用 MCP。
- 项目级事实源：每个项目自己的索引在 `.Ai-config/context-thread/context-thread.db`，不是全局共享数据库。
- 工具入口全局可用：全局 MCP 和 skill 可以默认安装，但不代表每个项目都已经初始化索引。
- 结构化事实只缩小范围：最终判断仍以当前文件、当前文档、用户说明和验证结果为准。
- 代码关系和工作流关系分开：代码结构进 context-thread DB，非代码流程进任务卡关系索引。
- 同步状态显性化：`context_thread_status` 必须暴露 pending changes，避免陈旧索引被误认为最新事实。
- 无索引不阻塞：没有索引、MCP 不可用或 runtime 缺失时，小任务直接回退到 `rg` / 文件读取。

## 在 AI 配置中的位置

```text
rules/shared/core.md
        ↓
global-context-thread skill
        ↓
代码关系 provider：context-thread MCP + .Ai-config/context-thread/context-thread.db
非代码关系 provider：.Ai-config/CURRENT.md + .Ai-config/tasks/*.md 关系索引
        ↓
当前文件 / 当前文档 / 用户说明 / 验证结果
```

各层职责：

- `rules/shared/core.md`：只放短规则，告诉 AI 在复杂关系任务中优先使用结构化事实源。
- `global-context-thread`：决定何时触发、先用哪个工具、什么时候回退。
- `context-thread` MCP：把代码图谱查询暴露给 AI。
- `.Ai-config/tasks/*.md`：记录非代码复杂关系，例如任务依赖、状态、证据和下一步。
- 真实文件和验证：负责最终事实确认。

## 触发边界

适合使用脉络：

- 需要理解调用链、影响面、模块关系、配置关系。
- 任务跨多个模块，直接读文件会很散。
- 用户问“这个功能怎么工作”“改这里会影响哪里”“谁调用了它”。
- 项目已有索引，且任务是 L2/L3 或有持续接手价值。
- 非代码流程有多个对象、依赖、状态和证据，需要在任务卡里保留关系。

不适合使用脉络：

- L0 问答、翻译、小文案、简单解释。
- L1 局部改动且附近文件足够说明问题。
- 没有索引的小任务。
- 产品需求、用户偏好、视觉判断、发布决策等非代码判断。
- 刚修改代码后还没有同步索引，却想把图谱结果当最终事实。

## 使用生命周期

### 1. 全局准备

本仓库维护 MCP 配置和用户级 runtime：

```text
tools/context-thread-engine/
        ↓
scripts/sync-context-thread-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\context-thread\
```

这一步只让工具入口可用，不会自动给每个项目创建索引。

### 2. 项目初始化

只有复杂代码关系任务、长期项目理解或用户明确要求时，才初始化项目索引：

```powershell
.\scripts\context-thread.ps1 init . --index
```

初始化会创建：

```text
.Ai-config/context-thread/context-thread.db
.Ai-config/context-thread/.gitignore
```

`context-thread.db` 可以作为项目级结构化事实源提交；WAL、SHM、日志、锁和缓存不提交。

### 3. 查询

AI 通过 MCP 查询结构关系：

- `context_thread_status`：看索引是否存在、是否陈旧、数据库状态。
- `context_thread_context`：综合构建任务上下文。
- `context_thread_search`：查符号位置。
- `context_thread_callers` / `context_thread_callees`：查调用方向。
- `context_thread_impact`：查影响面。
- `context_thread_node` / `context_thread_explore`：查看符号细节或相关源码。
- `context_thread_files`：查看索引中的文件结构。

查询后只读取必要文件确认细节。

### 4. 同步

索引更新有两条路：

- MCP server 正在运行，watcher 可用时，受支持源码变更会在 debounce 后自动 sync。
- MCP 没运行、watcher 禁用或平台不支持时，手动运行 `context-thread sync`。

复杂任务前先看 `context_thread_status`。如果有 pending changes，要么 sync，要么读取当前文件确认关键事实。

### 5. 回退

任何时候如果结构化事实源不可用：

- L0/L1：直接回到普通 `rg` / 文件读取。
- L2/L3：说明索引缺失或陈旧，再决定是否初始化或同步。

缺工具不是失败状态，误把缺工具变成阻塞才是问题。

## 与任务卡关系索引的边界

context-thread DB 只存代码结构关系：文件、符号、调用、引用、导入、继承、实现和影响面。

任务卡关系索引存非代码关系：

- 任务对象。
- 依赖和阻塞。
- 当前状态。
- 证据。
- 下一步。

例如“发布流程依赖哪些配置、谁还没确认、哪个验证还缺失”不进入代码图谱，而写入 `.Ai-config/tasks/*.md` 的 `关系索引`。

## 设计取舍

- 不默认初始化所有项目：避免小任务和小项目被拖重。
- 不用全局数据库：避免不同项目之间事实污染。
- 不把任务流程写进 DB：非代码关系用 Markdown 更透明、更容易审阅。
- 不让图谱替代读文件：索引可能陈旧，文件和验证永远优先。
- 不要求 npm 全局安装：本仓库源码构建后分发到用户级 runtime，MCP 直接用 `node` 启动。

## 迭代方向

优先级从高到低：

1. 可靠性：pending changes、watcher 边界、锁、WAL、跨项目缓存和错误提示。
2. 轻量性：减少小项目和小任务的上下文负担。
3. 查询质量：提升 callers/callees/impact/explore 的准确率和输出密度。
4. 同步体验：减少用户手动 sync 的频率，但不把自动化变成隐形负担。
5. 文档整洁：设计、实现、场景、任务卡各自归位。

任何优化都要保留一个底线：脉络是辅助理解的事实层，不是 AI 工作流的新仪式。

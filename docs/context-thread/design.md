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

- 默认轻量：简单问答和普通局部任务不初始化索引、不创建任务卡、不强制使用 MCP。
- 项目级事实源：每个项目自己的索引在 `.Ai-config/context-thread/context-thread.db`，不是全局共享数据库。
- 工具入口全局可用：全局 MCP 和 skill 可以默认安装，但不代表每个项目都已经初始化索引。
- 结构化事实只缩小范围：最终判断仍以当前文件、当前文档、用户说明和验证结果为准。
- 代码关系和工作流关系分开：代码结构进 context-thread DB，非代码流程进任务卡关系索引。
- 同步状态显性化：`context_thread_status` 必须暴露 pending changes，避免陈旧索引被误认为最新事实。
- Git 状态可追踪：索引记录完成时的 HEAD 和脏源码路径；切换提交、提交工作树改动或撤销脏文件时不能因为当前 `git status` 为空而漏同步。
- 查询可只读：只需要检索事实时可以只读打开数据库；只读实例不得迁移 schema、修改 PRAGMA、启动 watcher 或执行索引写操作。
- 隐私默认收敛：新索引默认使用 `structure`，只持久化符号、位置和关系；数据库默认忽略，只有显式 `--track-db` 才允许纳入 Git。
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
- 项目已有索引，且任务涉及跨模块关系、影响面或有持续接手价值。
- 非代码流程有多个对象、依赖、状态和证据，需要在任务卡里保留关系。

不适合使用脉络：

- 问答、翻译、小文案和简单解释。
- 局部改动且附近文件足够说明问题。
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

全局 runtime 使用 Node.js `>=22.19.0 <25.0.0`。低于 22.19 或进入 25.x 时明确阻断，避免 SQLite 与 tree-sitter 能力在声明支持后才运行时失败。

### 2. 项目初始化

只有复杂代码关系任务、长期项目理解或用户明确要求时，才初始化项目索引：

```powershell
.\scripts\context-thread.ps1 init . --index
# 明确需要富文本检索或跟踪数据库时再选择：
.\scripts\context-thread.ps1 init . --index --content-mode rich --track-db
```

初始化会创建：

```text
.Ai-config/context-thread/context-thread.db
.Ai-config/context-thread/.gitignore
```

新数据库默认使用 `structure`，不持久化 docstring、signature、decorator、type parameter、edge metadata 和 unresolved candidates；目录 `.gitignore` 默认忽略 `context-thread.db`。只有项目明确把数据库作为可审阅事实源时才使用 `--track-db`，WAL、SHM、日志、锁和缓存始终不提交。

旧数据库没有内容策略元数据时显示为 `legacy-rich`，不会在只读打开或普通同步时被静默改写。通过 `privacy --content-mode structure` 可以清理富字段、重建 FTS 并压缩数据库；从 `structure` 切回 `rich` 会完整重建索引。

### 3. 查询

AI 通过 MCP 查询结构关系：

- `context_thread_status`：看索引是否存在、是否陈旧、内容模式、Git 跟踪状态和数据库状态。
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
- MCP 没运行、watcher 禁用或平台不支持时，使用项目 wrapper，或用 `node` 加用户级 runtime 完整路径手动执行 `sync`。

每轮成功索引会更新 `git_state_v1` 元数据。HEAD 变化、旧数据库缺少该元数据时执行完整哈希扫描；普通增量同步会合并本轮和上轮的脏源码路径，覆盖已撤销修改、删除未跟踪文件和提交后干净工作树等边界。

复杂任务前先看 `context_thread_status`。如果有 pending changes，要么 sync，要么读取当前文件确认关键事实。

### 5. 回退

任何时候如果结构化事实源不可用：

- 简单问答和局部任务：直接回到普通 `rg` / 文件读取。
- 跨模块关系和长期理解任务：说明索引缺失或陈旧，再决定是否初始化或同步。

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
- 不默认提交数据库：结构索引也可能暴露项目形状，是否进入 Git 必须由项目显式选择。

## 迭代方向

优先级从高到低：

1. 可靠性：pending changes、watcher 边界、锁、WAL、跨项目缓存和错误提示。
2. 轻量性：减少小项目和小任务的上下文负担。
3. 查询质量：提升 callers/callees/impact/explore 的准确率和输出密度。
4. 同步体验：减少用户手动 sync 的频率，但不把自动化变成隐形负担。
5. 文档整洁：设计、实现、场景、任务卡各自归位。

任何优化都要保留一个底线：脉络是辅助理解的事实层，不是 AI 工作流的新仪式。

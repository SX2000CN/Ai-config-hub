# 脉络技术实现

本文说明 `ai-config-hub` 中脉络功能的技术结构，方便后续优化、调试和迭代。

设计说明见 [design.md](design.md)，真实使用场景见 [scenarios.md](scenarios.md)。

## 总体结构

```text
skills/shared/global-context-thread/
        ↓
AI 使用规则和工具选择

tool-configs/mcp/shared/context-thread.json
        ↓
MCP server 配置源

scripts/sync-context-thread-runtime.ps1 -Apply
        ↓
C:\Users\sx200\.ai-config-hub\mcp\context-thread\
        ↓
node dist/bin/context-thread.js serve --mcp
        ↓
tools/context-thread-engine/src/mcp/
        ↓
tools/context-thread-engine/src/index.ts
        ↓
.Ai-config/context-thread/context-thread.db
```

实现分成四层：

- CLI / runtime 层：负责 `init`、`index`、`sync`、`status`、`serve --mcp` 等命令。
- MCP 层：把查询能力暴露给 AI 工具。
- 引擎层：扫描文件、解析符号、解析引用、写入数据库、构建上下文。
- 项目索引层：每个项目自己的 `.Ai-config/context-thread/context-thread.db`。

## 入口文件

| 入口 | 职责 |
| --- | --- |
| `tools/context-thread-engine/src/bin/context-thread.ts` | CLI 入口，定义 init/index/sync/status/context/callers/callees/impact/serve 等命令 |
| `tools/context-thread-engine/src/index.ts` | `ContextThread` 主类，封装初始化、打开、索引、同步、watch、查询和关闭 |
| `tools/context-thread-engine/src/mcp/index.ts` | MCP server，处理 initialize、tools/list、tools/call、roots、watcher 和生命周期 |
| `tools/context-thread-engine/src/mcp/tools.ts` | MCP 工具定义和 ToolHandler 实现 |
| `tools/context-thread-engine/src/extraction/index.ts` | 扫描、解析、索引、增量同步、依赖方强制重解析 |
| `tools/context-thread-engine/src/db/schema.sql` | SQLite 表结构和索引 |
| `tools/context-thread-engine/src/sync/watcher.ts` | 文件 watcher 和 debounce sync |
| `tools/context-thread-engine/src/sync/watch-policy.ts` | watcher 启停策略，例如 WSL2 `/mnt/*` 自动禁用 |
| `tools/context-thread-engine/src/directory.ts` | `.Ai-config/context-thread/` 路径、初始化判断和 `.gitignore` |

## 项目目录和数据库

每个项目的默认索引目录：

```text
.Ai-config/context-thread/
  context-thread.db
  .gitignore
  errors.log          # 不提交
  context-thread.lock # 不提交
  *.db-wal            # 不提交
  *.db-shm            # 不提交
```

初始化判断要求目录和 `context-thread.db` 同时存在。只有 `.Ai-config/context-thread/` 目录但没有数据库，不算已初始化。

数据库由 `DatabaseConnection.initialize()` 创建，默认启用：

- `busy_timeout = 5000`
- `foreign_keys = ON`
- `journal_mode = WAL`
- `synchronous = NORMAL`
- `cache_size = -64000`
- `temp_store = MEMORY`
- `mmap_size = 268435456`

`context_thread_status` 会显示有效 journal mode。`wal` 表示并发读安全；非 WAL 模式需要警惕读写锁竞争。

## 数据模型

核心表：

- `nodes`：代码符号，例如 file、function、method、class、interface、type、variable 等。
- `edges`：符号关系，例如 contains、imports、calls、references、extends、implements 等。
- `files`：已索引文件、内容哈希、语言、大小、mtime、索引时间和错误。
- `unresolved_refs`：抽取阶段暂时无法解析的引用，后续由 resolver 建边。
- `nodes_fts`：FTS5 全文索引，用于符号名、qualified name、docstring、signature 搜索。
- `project_metadata`：项目级元数据。

重要约束：

- `edges.source` 和 `edges.target` 都引用 `nodes.id`。
- 删除文件会删除对应节点，节点删除会级联删除相关边和 unresolved refs。
- FTS 通过触发器跟随 `nodes` insert/update/delete。

## 索引流程

### 全量索引

入口：

```powershell
context-thread init . --index
context-thread index .
```

主要流程：

1. `ContextThread.init/open` 准备目录、数据库和查询对象。
2. `ExtractionOrchestrator.indexAll()` 扫描源码文件。
3. git 项目优先用 `git ls-files`，尊重 `.gitignore`，并处理子模块和嵌套 repo。
4. 非 git 项目回退到文件系统遍历和 `.gitignore` matcher。
5. 根据扩展名和内容检测语言，只索引支持的源码文件。
6. 通过 tree-sitter / framework extractor 抽取节点、边和 unresolved refs。
7. 写入 `files`、`nodes`、`edges`、`unresolved_refs`。
8. `ReferenceResolver` 批量解析 unresolved refs，补充调用、引用、导入等跨文件边。
9. 执行 `PRAGMA optimize` 和 WAL checkpoint。

### 单文件索引

`indexFile()` 会：

- 校验路径必须在项目根内。
- 跳过超过 1 MB 的文件。
- 检测语言，不支持则跳过。
- 抽取并写入数据库。
- 如果内容哈希未变化且未强制重建，则不重复写入。

### 增量同步

入口：

```powershell
context-thread sync .
```

主要流程：

1. 优先用 `git status --porcelain --no-renames --untracked-files=all` 找变更。
2. git 不可用时回退全量扫描并和 `files` 表比较。
3. 对新增、修改、删除文件分别处理。
4. 删除或修改文件前，先记录当前关系依赖方。
5. 变动文件索引完成后，把依赖方也强制重解析，减少符号移动、重命名、删除后的旧边残留。
6. 清空 resolver 缓存后解析 changed files 相关 unresolved refs。
7. 有写入时运行轻量数据库维护。

这也是最近补强的重点：只重建变动文件会留下旧调用边，因此现在会把当前依赖方纳入同一轮重解析。

## Watcher 和自动同步

MCP server 成功打开项目索引后会尝试启动 watcher：

```text
MCPServer.startWatching()
        ↓
ContextThread.watch()
        ↓
FileWatcher.start()
        ↓
fs.watch(projectRoot, { recursive: true })
```

watcher 特性：

- 默认 debounce：2000 ms。
- 只响应支持的源码文件。
- 忽略 `.Ai-config/context-thread/` 目录自身变化。
- 同步期间如果又收到变更，会在当前同步后再排一轮。
- 同步结果和错误写到 stderr，供 MCP 宿主诊断。

watcher 禁用条件：

- `CONTEXT_THREAD_NO_WATCH=1`
- WSL2 且项目位于 `/mnt/<drive>/`
- 平台或 Node 对 recursive `fs.watch` 支持不足

`CONTEXT_THREAD_FORCE_WATCH=1` 可以覆盖 WSL2 `/mnt/*` 自动禁用判断，但要自行承担性能风险。

## MCP server 生命周期

MCP 入口：

```powershell
context-thread serve --mcp
```

本仓库同步后的真实配置会启动用户级 runtime：

```text
node C:\Users\sx200\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js serve --mcp
```

生命周期：

1. CLI 启动 `MCPServer`。
2. `StdioTransport` 监听 JSON-RPC。
3. 收到 `initialize` 后先快速返回协议能力和 server instructions。
4. 如果客户端提供 `rootUri` 或 `workspaceFolders`，后台尝试打开项目索引。
5. 如果没有明确项目路径，首次 tool call 时通过 `roots/list` 或 cwd 推断项目。
6. 找到最近的 `.Ai-config/context-thread/context-thread.db` 后打开 `ContextThread` 实例。
7. 打开成功后启动 watcher。
8. `tools/list` 返回 `context_thread_*` 工具。
9. `tools/call` 交给 `ToolHandler` 执行。
10. stdin 关闭、SIGINT/SIGTERM 或父进程退出时关闭 watcher、数据库和缓存项目连接。

设计重点：

- 初始化延迟到握手之后，避免慢文件系统导致 MCP host 超时。
- 支持跨项目查询：工具参数可传 `projectPath`。
- 支持父进程 watchdog，避免 MCP host 异常退出后留下孤儿进程。

## MCP 工具

当前工具：

| 工具 | 用途 |
| --- | --- |
| `context_thread_status` | 查看索引统计、数据库状态、pending changes |
| `context_thread_context` | 综合搜索、关系扩展和关键代码，作为复杂任务首选入口 |
| `context_thread_search` | 快速搜索符号位置，不返回代码 |
| `context_thread_callers` | 查谁调用某个符号 |
| `context_thread_callees` | 查某符号调用什么 |
| `context_thread_impact` | 查修改某符号的影响半径 |
| `context_thread_node` | 查单个符号详情，可选择包含代码 |
| `context_thread_explore` | 一次返回多个相关符号的源码和关系图 |
| `context_thread_files` | 查看索引中的项目文件树 |

输出控制：

- 工具默认限制输出长度，避免拖重 AI 上下文。
- `context_thread_node` 对 class/interface/enum 等容器节点默认返回结构轮廓，不直接展开所有方法体。
- `context_thread_explore` 会按项目规模调整文件数、输出字符数、关系展示和行号策略。
- 所有工具都支持 `projectPath`，用于查询其他已初始化项目。

## CLI 命令

常用命令：

```powershell
.\scripts\context-thread.ps1 init . --index
.\scripts\context-thread.ps1 status .
.\scripts\context-thread.ps1 sync .
.\scripts\context-thread.ps1 context "分析某个功能如何工作" --path .
.\scripts\context-thread.ps1 callers SomeSymbol --path .
.\scripts\context-thread.ps1 callees SomeSymbol --path .
.\scripts\context-thread.ps1 impact SomeSymbol --path .
```

`scripts/context-thread.ps1` 默认调用用户级 runtime。若 runtime 不存在，先运行：

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

## 本仓库分发路线

源码事实源：

```text
tools/context-thread-engine/
```

同步到用户级 runtime：

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

MCP 配置事实源：

```text
tool-configs/mcp/shared/context-thread.json
```

渲染和同步 MCP 配置：

```powershell
.\scripts\render-mcp.ps1
.\scripts\check-mcp.ps1
.\scripts\sync-mcp.ps1 -Apply
```

## 测试和验证

引擎相关修改优先运行：

```powershell
Push-Location tools/context-thread-engine
npm test
Pop-Location
```

当前测试覆盖：

- `__tests__/mcp-tools.test.ts`：MCP 工具行为和缓存关闭。
- `__tests__/server-instructions.test.ts`：server instructions 中 watcher 延迟说明。
- `__tests__/sync-dependents.test.ts`：增量 sync 强制重解析依赖方，避免旧调用边残留。

项目整体检查：

```powershell
.\scripts\check-all.ps1
git diff --check
```

索引状态验证：

```powershell
.\scripts\context-thread.ps1 status .
```

或者在 AI 工具中调用 `context_thread_status`。

## 可靠性边界

- 索引可能陈旧：必须看 pending changes，关键事实仍读当前文件。
- watcher 不是永远可用：MCP 未启动、WSL2 `/mnt/*`、平台不支持或用户禁用时不会自动同步。
- 数据库可以提交，但需要随源码同步；sidecar 文件不提交。
- 跨项目缓存要正确关闭，否则会留下 SQLite 连接和 watcher。
- Node 版本会影响 tree-sitter WASM；CLI 已对过旧或不安全版本做提示/阻断。
- 大文件、生成文件、vendored 文件可能被跳过，不能把索引当作完整文件列表。

## 优化入口

后续优化可以按模块进入：

- 查询质量：`src/mcp/tools.ts`、`src/context/`、`src/graph/`。
- 索引准确性：`src/extraction/`、`src/resolution/`。
- 增量同步：`src/extraction/index.ts`、`src/sync/`。
- 数据库性能：`src/db/schema.sql`、`src/db/queries.ts`、`src/db/index.ts`。
- MCP 稳定性：`src/mcp/index.ts`、`src/mcp/transport.ts`。
- 本机分发：`scripts/sync-context-thread-runtime.ps1`、`tool-configs/mcp/shared/context-thread.json`。

每次优化都应同时更新对应测试和本文档中相关边界。

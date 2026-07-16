# 脉络技术实现

本文说明 `ai-config-hub` 中脉络功能的技术结构，方便后续优化、调试和迭代。

设计说明见 [design.md](design.md)，真实使用场景见 [scenarios.md](scenarios.md)。

运行时统一支持 Node.js `>=22.19.0 <25.0.0`。CLI、runtime 同步脚本和 package `engines` 使用同一边界，按完整 semver 判断；22.18 及更早版本拒绝，22.19-24.x 允许，25.x 默认阻断。

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
| `tools/context-thread-engine/src/bin/node-version-check.ts` | 按完整 semver 执行 Node.js 支持范围检查 |
| `tools/context-thread-engine/src/package-info.ts` | package 版本和 Node 支持范围的共享来源，供 CLI 与 MCP 使用 |
| `tools/context-thread-engine/src/index.ts` | `ContextThread` 主类，封装初始化、打开、索引、同步、watch、查询和关闭 |
| `tools/context-thread-engine/src/mcp/index.ts` | MCP server，处理 initialize、tools/list、tools/call、roots、watcher 和生命周期 |
| `tools/context-thread-engine/src/mcp/tools.ts` | MCP 工具定义和 ToolHandler 实现 |
| `tools/context-thread-engine/src/extraction/index.ts` | 扫描、解析、索引、增量同步、依赖方强制重解析 |
| `tools/context-thread-engine/src/db/sqlite-adapter.ts` | SQLite 连接、读写模式、PRAGMA 和 schema 初始化边界 |
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

新项目的 `.gitignore` 默认包含 `context-thread.db`；只有 `init --track-db` 或 `privacy --track-db` 会移除这条忽略规则。当前仓库是显式跟踪结构模式数据库的例外。`privacy --ignore-db` 可以恢复默认忽略策略；这些命令只改变可跟踪性，不会自动执行 `git add`。

数据库由 `DatabaseConnection.initialize()` 创建。普通读写连接会初始化 schema 并启用：

- `busy_timeout = 5000`
- `foreign_keys = ON`
- `journal_mode = WAL`
- `synchronous = NORMAL`
- `cache_size = -64000`
- `temp_store = MEMORY`
- `mmap_size = 268435456`

`context_thread_status` 会显示有效 journal mode。`wal` 表示并发读安全；非 WAL 模式需要警惕读写锁竞争。

`ContextThread.open(projectRoot, { readOnly: true })` 和 `openSync` 的同名选项会以 immutable 只读 SQLite URI 打开已存在数据库，跳过 schema 迁移和写 PRAGMA，也不会修复 `.gitignore`、创建 sidecar、启动索引或 watcher 写流程。只读实例可以执行 search/context/callers/callees/impact/node/files/status 等查询；`index`、`indexFile`、`sync`、`watch`、模式切换和跟踪策略修改等写入口统一抛出 `CONFIG_ERROR`。为避免 immutable 模式忽略尚未合并到主数据库的提交，只读打开在发现非空 WAL 或 rollback journal 时明确拒绝；写入方完成 checkpoint 且 sidecar 清空后才能建立零写入快照。

## 内容持久化策略

`project_metadata.content_mode_v1` 记录当前策略：

- `structure`：默认模式。保留符号身份、文件、位置、可见性、关系种类和关系位置；写入边界统一清空 docstring、signature、decorators、type parameters、edge metadata 和 unresolved candidates。
- `rich`：显式选择后保留上述富字段，用于需要富文本搜索的项目。
- `legacy-rich`：旧数据库缺少策略元数据时的显示状态，行为继续按 rich 处理，但不自动补写元数据。

schema v5 为 `structure` 安装 6 个持久化条件触发器，分别覆盖 nodes、edges 和 unresolved refs 的 insert/update。即使旧版或不了解内容策略的客户端尝试写入富字段，数据库边界也会把 nodes 的 docstring/signature/decorators/type parameters、edge metadata 和 unresolved candidates 改写为 `NULL`，并保持 FTS 不含这些内容；`rich` 和 `legacy-rich` 不触发这层保护。

模式切换通过 `privacy` 命令完成：

```powershell
.\scripts\context-thread.ps1 privacy .
.\scripts\context-thread.ps1 privacy . --content-mode structure
.\scripts\context-thread.ps1 privacy . --content-mode rich
.\scripts\context-thread.ps1 privacy . --track-db
```

`rich` / `legacy-rich` 切到 `structure` 时，引擎先确认 WAL 可完整 checkpoint，再切到独占 rollback-journal 模式，在系统临时目录创建可恢复备份；随后在事务中清空富字段并重建 FTS，执行 `VACUUM`，确认没有非空 sidecar 后恢复常规 WAL 连接。成功和可恢复失败都会清理临时备份；只有自动恢复本身失败时才保留备份路径供人工处理。`structure` 切到 `rich` 时先在系统临时目录完整构建 staging 数据库，只有全量索引成功后才用单个事务替换原图；构建失败或取消时原 structure 索引保持不变。

## 数据模型

核心表：

- `nodes`：代码符号，例如 file、function、method、class、interface、type、variable 等。
- `edges`：符号关系，例如 contains、imports、calls、references、extends、implements 等。
- `files`：已索引文件、内容哈希、语言、大小、mtime、索引时间和错误。
- `unresolved_refs`：抽取阶段暂时无法解析的引用，后续由 resolver 建边。
- `nodes_fts`：FTS5 全文索引，用于符号名、qualified name、docstring、signature 搜索。
- `project_metadata`：项目级元数据。

`project_metadata.git_state_v1` 保存最近一次成功索引或同步时的 Git 状态，JSON shape 为 `{ "head": string, "dirtyPaths": string[] }`。旧数据库没有该键或内容解析失败时无需迁移 schema，下一次同步会执行完整哈希扫描并写入有效元数据。

重要约束：

- `edges.source` 和 `edges.target` 都引用 `nodes.id`。
- 删除文件会删除对应节点，节点删除会级联删除相关边和 unresolved refs。
- FTS 通过触发器跟随 `nodes` insert/update/delete。

## 索引流程

### 全量索引

入口：

```powershell
.\scripts\context-thread.ps1 init . --index
.\scripts\context-thread.ps1 index .
```

主要流程：

1. `ContextThread.init/open` 准备目录、数据库和查询对象。
2. `ExtractionOrchestrator.indexAll()` 扫描源码文件。
3. git 项目优先用 `git ls-files`，尊重 `.gitignore`，并处理子模块和嵌套 repo。
4. 非 git 项目回退到文件系统遍历和 `.gitignore` matcher。
5. 根据扩展名和内容检测语言，只索引支持的源码文件。
6. 通过 tree-sitter / framework extractor 抽取节点、边和 unresolved refs。
7. 按当前内容策略写入 `files`、`nodes`、`edges`、`unresolved_refs`；`structure` 在所有写入口裁剪富字段。
8. `ReferenceResolver` 批量解析 unresolved refs，补充调用、引用、导入等跨文件边。
9. 执行 `PRAGMA optimize` 和 WAL checkpoint。
10. 成功完成后写入当前 `git_state_v1`。

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
.\scripts\context-thread.ps1 sync .
```

主要流程：

1. 读取当前 HEAD、当前 `git status --porcelain --no-renames --untracked-files=all` 和上次 `git_state_v1`；变化探测本身只读，不提前回写元数据。
2. 元数据缺失、解析失败或 HEAD 变化时执行完整源码哈希扫描；这覆盖干净分支切换和提交后干净工作树。
3. HEAD 未变化时，把本轮和上轮脏源码路径取并集，再和 `files` 表比较；这覆盖撤销修改和删除未跟踪源码。
4. git 不可用时回退全量扫描并和 `files` 表比较。
5. 对新增、修改、删除文件分别处理；删除或修改前先记录当前关系依赖方。
6. 变动文件索引完成后，把依赖方也强制重解析，减少符号移动、重命名、删除后的旧边残留。
7. 清空 resolver 缓存后解析 changed files 相关 unresolved refs。
8. 有写入时运行轻量数据库维护，成功后更新 `git_state_v1`。

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
node "$env:USERPROFILE\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js" serve --mcp
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
- MCP server 对外版本直接读取 `tools/context-thread-engine/package.json`，避免实现版本和包版本分开维护。

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
- 查询字符串中的 `kind:` / `lang:` 过滤条件会和 `SearchOptions` 中的同名过滤器取交集；交集为空时直接返回空结果，不会让一侧静默覆盖另一侧。

## CLI 命令

常用命令：

```powershell
.\scripts\context-thread.ps1 init . --index
.\scripts\context-thread.ps1 init . --index --content-mode structure --track-db
.\scripts\context-thread.ps1 status .
.\scripts\context-thread.ps1 privacy .
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

- `__tests__/git-state-sync.test.ts`：干净分支切换、提交后干净工作树、脏文件撤销、未跟踪文件删除和旧数据库元数据回填。
- `__tests__/readonly.test.ts`：异步/同步只读打开、查询可用、所有公开写操作和 watch 拒绝，以及缺失 `.gitignore`、非空 WAL/journal 和大数据库指纹场景下的零写入语义。
- `__tests__/search-filters.test.ts`：查询字符串与 `SearchOptions` 的 kind/lang 过滤交集。
- `__tests__/versioning.test.ts`：Node 完整版本边界，以及 CLI/MCP 从 package 元数据取版本。
- `__tests__/mcp-tools.test.ts`：MCP 缓存连接关闭和未初始化项目的真实 CLI 路径提示。
- `__tests__/sync-dependents.test.ts`：增量 sync 强制重解析依赖方，避免旧调用边残留。
- `__tests__/traversal.test.ts`：深链遍历、容器影响半径和多跳路径。
- `__tests__/server-instructions.test.ts`：server instructions 中 watcher 延迟说明。
- `__tests__/content-mode.test.ts`：structure/rich/legacy-rich 写边界、模式迁移、FTS 清理、完整重建和 VACUUM 后字节清除。
- `__tests__/privacy-cli.test.ts`：init/initSync 默认策略、`--content-mode`、`--track-db`、privacy/status 输出和真实 Git 跟踪状态。

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
- 数据库默认忽略；显式跟踪后需要随源码同步，sidecar 文件始终不提交。
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

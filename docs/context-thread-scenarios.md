# 脉络真实使用场景推演

本文记录 `ai-config-hub` 引入脉络后的真实使用边界。目标不是让每个任务都走图谱，而是让复杂关系任务有一层可查询、可同步、低负担的结构化事实源。

## 总体判断

当前方案是可用的，但不是所有场景都完全无感。

- 全局规则和 skill 默认可用：AI 先读规则，复杂关系任务会触发 `global-context-thread`。
- MCP runtime 是本机用户级服务：由本仓库构建并分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`。
- 项目索引是项目级事实源：每个目标项目需要自己的 `.Ai-config/context-thread/context-thread.db`。
- MCP 可以在已初始化项目中自动 watch 并同步源码变更，但前提是 MCP server 正在运行、watcher 可用、文件类型受支持。
- 没有索引、runtime 缺失或 watcher 不可用时，正确行为是回退到 `rg` / 读取文件，而不是阻塞小任务。

## 场景矩阵

| 场景 | 预期流程 | 当前能力 | 风险 | 应对 |
|---|---|---|---|---|
| L0 问答 / 翻译 / 小文案 | 直接回答 | 已支持 | 误触发 `.Ai-config` 或脉络流程 | 规则已要求 L0 不初始化、不建任务卡 |
| L1 局部代码小修 | 读近邻文件，最小验证 | 已支持 | 为了“用脉络”反而变重 | skill 已要求无索引就回退 |
| L2 复杂代码影响面 | 先 `context_thread_status`，再 `context_thread_context/search/impact`，最后读关键文件确认 | 已支持 | 索引陈旧导致判断偏差 | `status` 显示 pending changes；修改后仍以当前文件和验证为准 |
| 新项目从 0 接入 | 先按需创建 `.Ai-config/CURRENT.md`，复杂代码任务再初始化索引 | 部分支持 | 用户以为安装全局 MCP 后所有项目都有索引 | 文档明确每个项目索引独立 |
| 已有项目开始使用 | 识别 `AGENTS.md`、旧 `docs/ai/`、已有 `.Ai-config/`，再迁移或补轻量层 | 已支持 | 非空状态被覆盖，旧入口和新入口断层 | `project-ai-config-hub` 要求迁移前读旧状态并保留任务卡 |
| 旧项目已有 `docs/ai/` | 把旧目录作为迁移来源，新事实源落到 `.Ai-config/` | 已支持 | 历史链接仍指向旧路径 | 迁移后保留兼容提示，删除需单独确认 |
| MCP runtime 缺失 | `check-mcp` warning，真实 MCP 无法启动 | 已支持 warning | 用户重启后看不到工具 | 运行 `.\scripts\sync-context-thread-runtime.ps1 -Apply` 后重启工具 |
| 索引文件被提交 | clone 后可直接查已有结构 | 已支持 | DB 与源码版本漂移 | 修改源码后跑 `context-thread sync` 或依赖 watcher |
| 源码结构变动且 MCP 正在运行 | watcher 约 1-2 秒后自动 sync | 已支持 | watcher 被禁用或平台不支持 | `context_thread_status` 看 pending changes，必要时手动 sync |
| 源码结构变动但 MCP 没运行 | 不会自动更新 | 当前如此 | 用户以为 DB 会自己变 | 文档必须说明：需要 MCP watcher 或手动 `sync` |
| Windows 本机项目 | `fs.watch` 递归 watcher 通常可用 | 已支持 | 大项目 watch 成本 | L2/L3 才初始化索引，小任务回退 |
| WSL2 `/mnt/*` 项目 | watcher 自动禁用 | 已支持 | 索引容易陈旧 | 手动 `context-thread sync`，git hooks 目前不作为默认路线 |
| 非代码复杂工作流 | 用 `.Ai-config/CURRENT.md` + 任务卡 `关系索引` | 已支持 | 把非代码流程塞进代码图谱 | 明确由任务卡承接，不进 DB |
| 多 AI / 多人接手 | 任务卡保留状态、证据、下一步 | 已支持 | `CURRENT.md` 膨胀成项目管理文档 | 只保留薄入口，细节进任务卡 |
| 修改引擎源码 | 构建并同步用户级 runtime | 已支持 | MCP 仍跑旧 runtime | 改 `tools/context-thread-engine/` 后执行 `sync-context-thread-runtime.ps1 -Apply` |
| 修改 skill / 规则 | render、check、sync 到本机 | 已支持 | 源文件和本机全局配置漂移 | 使用 `check-all.ps1` 和对应 `sync-*.ps1 -Apply` |

## 错误预测与纠正

### 误解 1：装了全局 MCP，任何项目都自动有脉络

纠正：全局 MCP 只是工具入口，项目索引仍是每个项目自己的 `.Ai-config/context-thread/context-thread.db`。没有索引时，L0/L1 直接回退普通文件读取；L2/L3 才建议初始化。

### 误解 2：索引会永远和项目自动同步

纠正：只有 MCP server 已打开并且 watcher 可用时，文件修改才会自动触发增量同步。MCP 没运行、watcher 被禁用、平台不支持递归 watch、或发生未覆盖的文件类型变更时，需要手动运行：

```powershell
.\scripts\context-thread.ps1 sync .
```

在其他项目中使用用户级 runtime 时，可通过目标项目自己的包装脚本或直接调用：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.ai-config-hub\mcp\context-thread\context-thread.ps1" sync .
```

### 误解 3：脉络结果可以替代读文件和测试

纠正：脉络只负责缩小理解范围和关系判断。涉及当前修改、配置细节、测试行为、用户需求和最终结论时，仍以真实文件、运行结果和用户说明为准。

### 误解 4：为了完整，所有项目都应该初始化 `.Ai-config`

纠正：小项目可以只有项目规则，长期项目再加 `.Ai-config/CURRENT.md`，复杂接手任务再加任务卡，复杂代码关系任务再加 context-thread 索引。

### 误解 5：任务卡关系索引等于项目管理系统

纠正：关系索引只记录接手必需的对象、状态、依赖、证据和下一步。临时讨论和一次性任务不创建。

## 建议完善路线

优先级从高到低：

1. 保持 `context_thread_status` 暴露 pending changes，让 AI 在复杂任务前知道索引是否陈旧。
2. 在 `global-context-thread` workflow 中明确“watcher 自动同步只在 MCP 运行且 watcher 可用时成立”。
3. 在 `project-ai-config-hub` workflow 中补一段“目标项目启用脉络”的分层流程：先 `.Ai-config`，后按需索引。
4. 给 `.Ai-config/context-thread/README.md` 保留项目级命令和 sidecar 提交边界。
5. 后续如果真实使用中发现手动 sync 高频，再考虑新增一个目标项目通用 wrapper 或项目级任务命令，不急着把它变成默认负担。

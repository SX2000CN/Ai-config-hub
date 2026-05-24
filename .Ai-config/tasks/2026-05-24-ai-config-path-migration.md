# 工作任务：迁移项目 AI 配置中枢到 .Ai-config

任务 ID：2026-05-24-ai-config-path-migration
创建时间：2026-05-24 06:28
更新时间：2026-05-24 06:45
状态：待用户确认
当前活动：是

## 目标

把本仓库的项目级 AI 配置中枢从旧版 `docs/ai/` 迁移到根目录 `.Ai-config/`，让后续“更新项目 AI 配置”自然维护 `.Ai-config/CURRENT.md`、`.Ai-config/tasks/`、`.Ai-config/skills-registry.md` 和 `.Ai-config/context-thread/`。

## 背景和当前上下文

用户此前明确希望 `ai-config-hub` 项目内的 AI 配置不要继续放在 `docs/ai/`，而是用根目录 `.Ai-config/` 承载项目级 AI 配置；脉络索引目录应位于 `.Ai-config/context-thread/context-thread.db`。本机全局规则、skills、MCP 和用户级 context-thread runtime 已同步后，用户要求“更新项目AI配置”。

## 最近结论

- 旧版 `docs/ai/` 已作为迁移来源复制到 `.Ai-config/`。
- 新的主接手入口是 `.Ai-config/CURRENT.md`。
- 旧版 `docs/ai/` 不再作为主事实源，只保留兼容提示和迁移说明。
- `.Ai-config/context-thread/` 是项目索引目录，当前项目已按用户要求初始化 `context-thread.db`，并保留 README / `.gitignore` 说明提交边界。

## 已确认事实

- `project-ai-config-hub` 的当前流程要求新配置统一写入 `.Ai-config/`。
- `global-context-thread` 使用 `.Ai-config` 任务卡关系索引承接非代码复杂工作流。
- context-thread CLI / MCP 的项目索引目录已经改为 `.Ai-config/context-thread/`。

## 已尝试 / 已排除

- 已排除继续把 `docs/ai/` 当作主配置中枢。
- 不在本任务中删除旧版 `docs/ai/` 的历史信息；先用兼容入口避免旧链接直接失效。
- 不把 `.Ai-config/context-thread/` 索引初始化写成所有项目的默认动作；本仓库这次是按用户明确要求初始化。

## 当前卡点

等待本轮验证和用户确认是否可以进一步清理旧版 `docs/ai/` 历史副本。

## 关系索引

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| `.Ai-config/` | 新主事实源 | 影响项目 AI 接手入口、任务卡和 registry | `.Ai-config/CURRENT.md` | 验证后等待用户确认 |
| `docs/ai/` | 旧版兼容入口 | 影响旧链接和历史任务引用 | `docs/ai/README.md` | 暂不删除，后续按用户确认清理 |
| `.Ai-config/context-thread/` | 已初始化，`context-thread.db` 可跟踪；运行时 sidecar / 日志 / 锁文件不跟踪 | 影响脉络索引和 MCP 查询 | `.Ai-config/context-thread/context-thread.db` / `.Ai-config/context-thread/.gitignore` | 代码结构变化后按需 `sync` 或重建索引 |

## 下一步最小动作

1. 等待用户确认 `.Ai-config/` 作为新主入口的使用体验。
2. 后续如需删除旧版 `docs/ai/` 历史副本，再做一次引用扫描和单独清理。

## 验证状态

- 已运行 `scripts/check-all.ps1`，结果 `All render, check, and dry-run steps passed`。
- `check-all` 中 `check.ps1` 输出 `Check passed`。
- `check-all` 中 `check-skills.ps1` 输出 `Skill check passed`。
- `check-all` 中 `check-mcp.ps1` 输出 `MCP check passed`。
- 已运行 `scripts/sync-context-thread-runtime.ps1 -Apply`，用户级 context-thread runtime 已刷新。
- 已运行 `scripts/context-thread.ps1 init . --index`，生成 `.Ai-config/context-thread/context-thread.db`。
- 已运行 `scripts/context-thread.ps1 status .`，当前索引为 84 files / 1,410 nodes / 4,083 edges，数据库约 4.36 MB，状态为 up to date。
- 已通过 MCP `context_thread_status` 读取同一索引状态。

## 残留风险

- 旧任务卡和历史设计文档中可能仍出现 `docs/ai/`，其中一部分是历史事实，一部分可能是旧链接；本轮只修当前有效入口和会影响后续行为的说明。
- 若后续直接删除 `docs/ai/`，需要再做一次引用扫描。
- `context-thread.db` 现在可提交到仓库，后续代码变更后需要按需重新索引，避免结构化事实层陈旧。
- SQLite sidecar、日志和锁文件仍应保持忽略，避免提交运行时噪音。

## 相关文件

- `.Ai-config/CURRENT.md`：新的项目 AI 接手入口。
- `.Ai-config/README.md`：新的项目 AI 配置中枢说明。
- `.Ai-config/tasks/`：新的任务卡目录。
- `.Ai-config/skills-registry.md`：新的项目 skills 清单。
- `docs/ai/README.md`：旧路径兼容说明。

## 不要重复

- 不要把 `.Ai-config/context-thread/` 初始化写成所有项目的默认动作；本次只代表当前仓库已按需初始化。
- 不要继续把 `docs/ai/` 当作当前主事实源。

## 关闭依据 / 最终结果

暂无。

# 工作任务：{{title}}

任务 ID：{{task_id}}
创建时间：{{created_at}}
更新时间：{{updated_at}}
状态：进行中 / 暂停 / 阻塞 / 等待验证 / 待用户确认 / 已关闭 / 已废弃 / 已合并
当前活动：是 / 否

> 状态转换：进行中/暂停/阻塞/等待验证/待用户确认可以互相转换，反映任务推进中的真实状态。已关闭/已废弃/已合并是终态，不可逆——如果关闭后发现问题需要继续，开一张新任务卡并在"相关文件"或"背景"中引用旧卡，不要把旧卡状态改回进行中。"待用户确认"超过 30 天无人跟进时，可转为"已关闭（未跟进关闭）"，见 `.Ai-config/CURRENT.md` 的形态约束。

## 目标

{{goal}}

## 背景和当前上下文

{{context}}

## 最近结论

- {{latest_conclusion}}

## 已确认事实

- {{confirmed_fact_1}}

## 已尝试 / 已排除

- {{attempt_or_exclusion_1}}

## 当前卡点

{{blocker}}

## 关系索引

> 可选。仅当任务存在复杂对象、状态、依赖、证据或跨 AI 接手关系时保留；简单任务删除本节。用于非代码复杂工作流（例如多个配置管线、多个 skill、多阶段迁移之间的依赖关系）；代码内的调用/依赖关系交给 context-thread 索引，不在这里重复记录。

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| `{{relation_object_1}}` | {{relation_status_1}} | {{relation_dependency_1}} | {{relation_evidence_1}} | {{relation_next_step_1}} |

示例（来自一次真实的迁移任务，仅供参考格式，不要照抄内容）：

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| `.Ai-config/context-thread/` | 已初始化，`context-thread.db` 可跟踪 | 影响脉络索引和 MCP 查询工具的可用性 | `context-thread.ps1 status .` 输出 87 files / 1423 nodes / pending 0 | 代码结构变化后按需 `sync` 或重建索引 |
| `global-context-thread` skill | 仓库源、rendered 与本机用户级目录已同步 | 影响 Claude Code / Codex 是否能发现这个 skill | `sync-skills.ps1` dry-run 显示 unchanged | 无，已完成 |

## 下一步最小动作

1. {{next_step_1}}

## 验证状态

- {{verification_1}}

## 残留风险

- {{risk_1}}

## 相关文件

- `{{path_1}}`：{{path_note_1}}

## 不要重复

- {{do_not_repeat_1}}

## 关闭依据 / 最终结果

{{closing_basis}}

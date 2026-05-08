# 项目级 Skills 清单

最后更新时间：2026-05-09 00:40:54 +08:00

| Skill | 状态 | 事实源 | Claude Code 入口 | Codex 入口 | 备注 |
|---|---|---|---|---|---|
| project-ai-config-hub | active | `skills/shared/project-ai-config-hub/` | `skills/claude-code/project-ai-config-hub/SKILL.md` | `skills/codex/project-ai-config-hub/SKILL.md` | 本仓库维护并渲染到用户级目录的全局 skill；不是 `docs/ai/skills/` 下的新项目入口。 |

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：已启用。
- `partial`：部分可用。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

## 维护约定

新增项目级 skill 时，默认把事实源放在 `docs/ai/skills/<skill-name>/`，并在这里记录双端入口和状态。若事实源沿用项目既有目录，必须在表格中明确写出真实路径，避免出现多个互相冲突的事实源。

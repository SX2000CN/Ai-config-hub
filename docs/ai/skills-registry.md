# 项目级 Skills 清单

最后更新时间：2026-05-14

| Skill | 状态 | 事实源 | Claude Code 入口 | Codex 入口 | 备注 |
|---|---|---|---|---|---|
| project-ai-config-hub | active | `skills/shared/project-ai-config-hub/` | `skills/claude-code/project-ai-config-hub/SKILL.md` | `skills/codex/project-ai-config-hub/SKILL.md` | 本仓库维护并渲染到用户级目录的全局 skill；不是 `docs/ai/skills/` 下的新项目入口。 |
| global-frontend-design | active | `skills/shared/global-frontend-design/` | `skills/claude-code/global-frontend-design/SKILL.md` | `skills/codex/global-frontend-design/SKILL.md` | 本仓库维护并渲染到用户级目录的全局前端设计 skill；来源归档见 `docs/ai/archive/global-frontend-design-sources/`。 |
| global-thinking-partner | active | `skills/shared/global-thinking-partner/` | `skills/claude-code/global-thinking-partner/SKILL.md` | `skills/codex/global-thinking-partner/SKILL.md` | 本仓库维护并渲染到用户级目录的低副作用思维扩展 skill；默认只读、手动触发优先。 |

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：已启用。
- `partial`：部分可用。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

## 维护约定

新增项目级 skill 时，默认把事实源放在 `docs/ai/skills/<skill-name>/`，并在这里记录双端入口和状态。若事实源沿用项目既有目录，必须在表格中明确写出真实路径，避免出现多个互相冲突的事实源。

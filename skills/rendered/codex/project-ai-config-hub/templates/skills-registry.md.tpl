# 项目级 Skills 清单

最后更新时间：{{updated_at}}

| Skill | 状态 | Canonical 事实源 | Claude Code 入口 | Codex / OpenCode 共用入口 | Grok 入口 | 备注 |
|---|---|---|---|---|---|---|
| {{skill_name}} | {{status}} | `.Ai-config/skills/{{skill_name}}/` | `.claude/skills/{{skill_name}}/SKILL.md` | `.agents/skills/{{skill_name}}/SKILL.md` | `.grok/skills/{{skill_name}}/SKILL.md` | {{note}} |

## Canonical 事实源约束

- 普通目标项目的项目级 skill，事实源列必须指向 `.Ai-config/skills/<skill-name>/`。
- `.claude/skills/<skill-name>/SKILL.md`、`.agents/skills/<skill-name>/SKILL.md`、`.grok/skills/<skill-name>/SKILL.md` 和可选 `.codex/skills/<skill-name>/SKILL.md` 只作为工具入口或兼容入口。
- README、docs、脚本说明、旧版 `docs/ai/` 或工具入口中的完整规则只能作为迁移来源、支持性引用或兼容记录，不登记为长期事实源。
- 如果当前 skill 仍处在迁移中，应在备注中写清迁移来源和下一步，不要把非 canonical 路径伪装为已稳定事实源。

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：已启用，canonical 事实源和工具入口都可用。
- `partial`：部分可用，仍有事实源收敛、入口修复或验证缺口。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

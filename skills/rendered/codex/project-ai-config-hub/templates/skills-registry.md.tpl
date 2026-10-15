# 项目级 Skills 清单

最后更新时间：{{updated_at}}

| Skill | 状态 | 完整包 | Claude 导出 | 其他 adapter | 备注 |
|---|---|---|---|---|---|
| {{skill_name}} | {{status}} | `.agents/skills/{{skill_name}}/` | `.claude/skills/{{skill_name}}/` | {{adapters}} | {{note}} |

## Canonical 事实源约束

- 普通目标项目的项目级 skill，完整包列指向 `.agents/skills/<skill-name>/`；这是项目约定，不是规范指定的发现路径。
- Claude 和其他客户端目录应导出或链接同一完整包；不要把不同正文登记为多个入口版本。
- README、docs、脚本说明、旧版 `docs/ai/` 或工具入口中的完整规则只能作为迁移来源、支持性引用或兼容记录，不登记为长期事实源。
- 如果当前 skill 仍处在迁移中，应在备注中写清迁移来源和下一步，不要把非 canonical 路径伪装为已稳定事实源。

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：完整包已启用；实际客户端是否发现取决于 adapter 和配置。
- `partial`：部分可用，仍有事实源收敛、入口修复或验证缺口。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

# {{skill_name}} 检查清单

## 使用前检查

- 已确认 `.Ai-config/skills/{{skill_name}}/` 存在，并且是本 skill 的 canonical 事实源。
- 仅当任务有接手价值、可能跨会话、已有活动任务、影响多个模块或涉及高风险写入时，才读取 `.Ai-config/CURRENT.md`。
- 已读取 `.Ai-config/skills-registry.md`，确认本 skill 的 canonical 事实源、入口和状态。
- 已读取 `.Ai-config/skills/{{skill_name}}/README.md`，并按需读取同目录下的 `workflow.md`、`checklists.md`、`references/` 或 `templates/`。
- 如果存在相关活动任务卡，已读取 `.Ai-config/tasks/*.md` 中对应文件。

## 事实源检查

- durable 规则、触发、workflow、checklist、references 和 templates 只维护在 `.Ai-config/skills/{{skill_name}}/` 下。
- `.claude/skills/{{skill_name}}/SKILL.md`、`.agents/skills/{{skill_name}}/SKILL.md` 和可选 `.codex/skills/{{skill_name}}/SKILL.md` 只是工具入口，不承载完整规则。
- 如果发现完整规则散落在 README、docs、脚本说明、旧版 `docs/ai/` 或工具入口中，已标记为迁移来源或支持性引用，并计划收敛到 canonical 目录。
- `.Ai-config/skills-registry.md` 的事实源列指向 `.Ai-config/skills/{{skill_name}}/`；非 canonical 路径只写在备注中说明迁移、兼容或支持关系。

## 修改检查

- 修改规则前，先修改 `.Ai-config/skills/{{skill_name}}/` 下的事实源。
- 工具入口只保留薄入口，不复制完整流程。
- 修改后检查 `.claude/skills/{{skill_name}}/SKILL.md` 和 `.agents/skills/{{skill_name}}/SKILL.md` 是否仍指向同一 canonical 事实源。
- 只有历史兼容或用户明确要求时，才维护 `.codex/skills/{{skill_name}}/SKILL.md`。

## 工作状态检查

- 简单问答、一次性命令和一轮内完成的小任务不创建任务卡。
- 等待确认、验证缺失、残留风险、被打断或有跨会话价值时创建或更新任务卡。
- 跨模块、高风险写入或有明确接手价值的任务应创建或更新 `.Ai-config/tasks/*.md` 任务卡。
- 切换任务前，应先保存旧任务状态。
- 完成一轮工作但用户尚未确认时，应把任务保持为 `待用户确认` 或等价状态。
- 未确认、未验证或有残留风险的任务不得直接标为 `已关闭`。

## 安全检查

- 不写入真实 token、密钥、密码、私钥、生产凭证或私有服务地址。
- 覆盖、迁移、删除、写入全局目录、写入历史 `.codex/skills` 或触及生产/部署/权限前，应先给计划并等待确认。

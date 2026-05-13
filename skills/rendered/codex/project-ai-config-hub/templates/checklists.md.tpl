# {{skill_name}} 检查清单

## 使用前检查

- 已读取 `docs/ai/CURRENT.md`，确认当前是否有活动任务、暂停任务、阻塞任务或待用户确认任务。
- 已读取 `docs/ai/skills-registry.md`，确认本 skill 的事实源、入口和状态。
- 已读取 `docs/ai/skills/{{skill_name}}/README.md` 和 `workflow.md`。
- 如果存在相关任务卡，已读取 `docs/ai/tasks/*.md` 中对应文件。

## 修改检查

- 优先修改 `docs/ai/skills/{{skill_name}}/` 下的事实源。
- 工具入口只保留薄入口，不复制完整流程。
- 修改后检查 `.claude/skills/{{skill_name}}/SKILL.md` 和 `.agents/skills/{{skill_name}}/SKILL.md` 是否仍指向同一事实源。
- 只有历史兼容或用户明确要求时，才维护 `.codex/skills/{{skill_name}}/SKILL.md`。

## 工作状态检查

- 非简单任务应创建或更新 `docs/ai/tasks/*.md` 任务卡。
- 切换任务前，应先保存旧任务状态。
- 完成一轮工作但用户尚未确认时，应把任务保持为 `待用户确认` 或等价状态。
- 未确认、未验证或有残留风险的任务不得直接标为 `已关闭`。

## 安全检查

- 不写入真实 token、密钥、密码、私钥、生产凭证或私有服务地址。
- 覆盖、迁移、删除、写入全局目录、写入历史 `.codex/skills` 或触及生产/部署/权限前，应先给计划并等待确认。

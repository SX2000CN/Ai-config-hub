# 项目级 Skill 事实源

本目录用于保存当前项目自己的项目级 skill 事实源。

约定：

- 每个项目级 skill 使用独立目录：`.Ai-config/skills/<skill-name>/`。
- 这里是普通目标项目项目级 skill 的 canonical 事实源；durable 规则、workflow、checklists、references 和 templates 应收敛到这里。
- `.claude/skills`、`.agents/skills` 和 `.codex/skills` 只保留工具入口或兼容入口，指向这里的事实源。
- 新增、迁移或废弃 skill 后，同步更新 `.Ai-config/skills-registry.md`。

当前没有放在本目录下的项目级 skill。`project-ai-config-hub` 等全局 managed skills 的事实源仍在 `skills/shared/<skill-name>/`，因为它们由本仓库维护、渲染并同步到用户级目录；不要把这个全局分发管线当作普通目标项目的事实源范式。

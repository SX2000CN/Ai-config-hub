# 项目级 Skill 事实源

本目录用于保存当前项目自己的项目级 skill 事实源。

约定：

- 每个 skill 使用独立目录：`docs/ai/skills/<skill-name>/`。
- 工具入口只保留薄入口，指向这里的事实源。
- 新增、迁移或废弃 skill 后，同步更新 `docs/ai/skills-registry.md`。

当前没有放在本目录下的项目级 skill。`project-ai-config-hub` 的事实源仍在 `skills/shared/project-ai-config-hub/`，因为它是本仓库维护并同步到用户级目录的全局 skill。

# 设计检查清单

## 创建前

- 已读取项目级 `AGENTS.md`、`CLAUDE.md`、`README.md` 或相关 docs。
- 已判断工作模式是 `init`、`create`、`update`、`migrate`、`audit` 还是 `repair`。
- 已确认 skill 名称、触发场景和适用范围。
- 修改已有项目级 skill 时，已先定位事实源，再决定修改位置。
- 已确认这次修改是原地 `update`、入口修复，还是 `migrate`，不会把两者混在一起。
- 已确认是否需要兼容 `.codex/skills`。
- 已确认是否涉及发布、部署、生产数据、凭证或共享状态。
- 已检查目标路径是否已有同名 skill。

## 目录设计

- 项目级 AI 配置中枢位于 `docs/ai/`。
- 项目级 skill 清单位于 `docs/ai/skills-registry.md`。
- 共享事实源位于 `docs/ai/skills/<skill-name>/` 或项目已有等价目录。
- `.claude/skills/<skill-name>/SKILL.md` 只是 Claude Code 工具入口。
- `.agents/skills/<skill-name>/SKILL.md` 只是 Codex 工具入口。
- `.codex/skills/<skill-name>/SKILL.md` 只在需要兼容时存在。
- 工具入口明确列出共享事实源路径和必读文件。

## 内容质量

- 文档描述真实状态，明确区分已完成、计划中、暂时方案和推断。
- 不复制大段业务流程到多个工具入口。
- 不写入真实 token、密钥、密码、生产凭证。
- 高风险操作有确认要求。
- 项目已有文档被引用，而不是被重复粘贴。

## 实施后

- frontmatter 有稳定 `name` 和清晰 `description`。
- 工具入口指向的文件真实存在。
- 不存在多个互相冲突的事实源。
- `docs/ai/skills-registry.md` 已记录项目 skill 的事实源、入口和状态。
- 修改已有项目级 skill 后，双端入口和 registry 仍指向同一事实源。
- 项目文档索引已按需更新。
- 已运行最小相关验证。

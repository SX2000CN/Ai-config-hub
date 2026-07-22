# 设计检查清单

## 创建前

- 已按任务风险读取足够上下文；小任务不做全量文档巡检。
- 已读取或检查 `.Ai-config/`，确认是否已有 AI 配置中枢；若没有，已检查旧版 `docs/ai/` 是否是迁移来源，并判断是否真的需要创建。
- 已判断工作模式是 `init`、`create`、`update`、`migrate`、`audit` 还是 `repair`。
- 已确认是创建/升级工作状态机制，还是创建/修改项目级 skill。
- 已确认 skill 名称、触发场景和适用范围。
- 修改已有项目级 skill 时，已先定位事实源，再决定修改位置。
- 已确认这次修改是原地 `update`、入口修复、旧版 `docs/ai/` 迁移、v1 状态迁移，还是 skill 迁移，不会把几类操作混在一起。
- 已确认是否需要兼容 `.codex/skills`。
- 已确认是否涉及发布、部署、生产数据、凭证或共享状态。
- 已检查目标路径是否已有同名 skill 或已有 `.Ai-config/CURRENT.md`。

## 目录设计

- 项目级 AI 配置按需分层：小项目可只保留项目规则；需要接手状态时才创建 `.Ai-config/CURRENT.md`；需要跨会话任务时才创建 `.Ai-config/tasks/`。
- 项目级 AI 配置中枢位于 `.Ai-config/`。
- 旧版 `docs/ai/` 只作为迁移来源和兼容事实源；新配置统一写入 `.Ai-config/`。
- AI 接手入口和多任务状态总览位于 `.Ai-config/CURRENT.md`。
- 任务卡目录位于 `.Ai-config/tasks/`，任务说明位于 `.Ai-config/tasks/README.md`，但不是所有项目的必需文件。
- `.Ai-config/archive/` 仅作为可选长期整理目录，不是日常关闭任务的必需步骤。
- 项目级 skill 清单位于 `.Ai-config/skills-registry.md`，只在存在项目级 skill 或用户要求登记时创建。
- 项目级 skill 的 canonical 事实源位于 `.Ai-config/skills/<skill-name>/`，只在确有可复用项目工作流时创建。
- 项目已有目录、README、docs、脚本说明、旧版 `docs/ai/` 或工具入口只能作为迁移来源、支持性引用或兼容入口，不得作为长期 skill 事实源。
- `.claude/skills/<skill-name>/SKILL.md` 只是 Claude Code 工具入口。
- `.agents/skills/<skill-name>/SKILL.md` 只是 Codex 工具入口。
- `.grok/skills/<skill-name>/SKILL.md` 只是 Grok Build 工具入口。
- `.codex/skills/<skill-name>/SKILL.md` 只在需要兼容时存在。
- 工具入口明确列出 `.Ai-config/skills/<skill-name>/` canonical 事实源路径和必读文件。

## 工作状态质量

- `.Ai-config/CURRENT.md` 是接手入口和状态总览，不承载完整任务日志。
- `.Ai-config/CURRENT.md` 提供目标项目自己的接手导航，不把主 README 强行写成固定第一入口。
- 同一时刻只有一个当前活动任务。
- 多任务、跨天任务和有接手价值的任务通过 `.Ai-config/tasks/*.md` 任务卡保留上下文。
- 简单问答、一次性命令、一轮内完成且无残留风险的小修复，没有被强行写成任务卡。
- v1 `CURRENT.md` 只有明确空闲时才可直接升级；不能确认为空闲的旧状态已迁移到任务卡，没有直接覆盖。
- 未确认、未验证或有残留风险的任务没有被直接标为已关闭。
- 已关闭、已废弃或已合并的任务记录了关闭依据、废弃原因或合并目标。
- 任务卡包含目标、背景、最近结论、已确认事实、已尝试/已排除、卡点、下一步、验证、风险和相关文件。

## 工作状态腐化检查（audit / repair 必查）

- `.Ai-config/CURRENT.md` 没有长出模板设计之外的常驻小节（例如静态项目结构表、模块速查表、其他文档规则的整段复述）；如果发现，应改成一行链接引用，不整段照抄。
- "当前待确认"表里没有超过 30 天未更新且无人跟进的条目；发现时先确认是否已经过期失效，过期的移到"最近关闭"并注明未跟进关闭。
- 已在 `.Ai-config/tasks/*.md` 标记为已关闭/已废弃/已合并的任务，`CURRENT.md` 的"当前待确认"或"暂停 / 阻塞"里不应再保留对应行；发现不一致要同步移除。
- `CURRENT.md` 的"更新时间"字段与文件内实际最新事项的时间大致一致，不存在更新时间早于文件内某条记录时间的情况。

## 内容质量

- 文档描述真实状态，明确区分已完成、计划中、暂时方案和推断。
- durable 的项目级 skill 规则、触发、workflow、checklist、references 和 templates 已收敛到 `.Ai-config/skills/<skill-name>/`。
- 支持性项目 docs 由 `.Ai-config/skills/<skill-name>/` 内的主文件索引，不反过来让工具入口直接引用一堆散落文档。
- 不复制大段业务流程到多个工具入口。
- 不写入真实 token、密钥、密码、生产凭证。
- 高风险操作有确认要求。
- 项目已有文档被引用，而不是被重复粘贴。

## 实施后

- frontmatter 有稳定 `name` 和清晰 `description`。
- 工具入口指向的 `.Ai-config/skills/<skill-name>/` canonical 事实源真实存在。
- 不存在多个互相冲突的事实源；非 canonical 完整规则已标记为迁移来源、支持性引用或兼容入口。
- `.Ai-config/skills-registry.md` 的事实源列指向 `.Ai-config/skills/<skill-name>/`；普通目标项目不得把 README、docs、`.claude/skills`、`.agents/skills`、`.grok/skills` 或 `.codex/skills` 登记为长期事实源。
- `.Ai-config/CURRENT.md` 已按需创建或刷新；若没有创建，原因是任务没有持续接手价值。
- `.Ai-config/tasks/README.md` 已按需创建。
- `.Ai-config/tasks/*.md` 已按需创建或迁移，且可让后续 AI 无损接手。
- `.Ai-config/skills-registry.md` 已按需记录项目 skill 的事实源、入口和状态。
- 修改已有项目级 skill 后，双端入口和 registry 仍指向同一事实源。
- 项目文档索引已按需更新。
- 已运行最小相关验证。

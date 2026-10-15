# 旧配置迁移

只有目标项目存在旧版 `docs/ai/`、v1 单槽位 `.Ai-config/CURRENT.md`，或 durable 规则散落在工具目录时才需要本文。新项目和已完成迁移的项目不用读。

## docs/ai/ 迁移到 .Ai-config/

目标项目存在旧版 `docs/ai/` 且 `.Ai-config/` 不存在时，把 `docs/ai/` 视为旧配置事实源。迁移时保留 `CURRENT.md`、`tasks/`、`archive/`、`skills-registry.md` 和有价值说明文件的语义，新路径统一落到 `.Ai-config/`。迁移完成前不要删除旧信息。

## v1 CURRENT.md 升级到 v2 总览

目标项目已有单槽位 `.Ai-config/CURRENT.md`，或旧版 `docs/ai/CURRENT.md` 需要迁入时：

1. 不要直接覆盖。
2. 先读取旧 `CURRENT.md`，判断状态是否为空闲。
3. 只有旧状态明确为空闲、无当前任务且无接手价值时，才可把 `CURRENT.md` 升级为 v2 总览，并保留旧「已确认/接手提示」中仍有价值的信息。
4. 不能确认为空闲的旧状态都应迁移为 `.Ai-config/tasks/YYYY-MM-DD-<topic>.md` 任务卡，包括 `进行中`、`暂停`、`阻塞`、`等待验证`、`待用户审核`、`待用户确认` 或自定义等价状态。
5. 新 `CURRENT.md` 指向迁移出的任务卡，并在总览中保留原状态。
6. 用户未确认前，不得删除旧信息。
7. 覆盖、迁移或删除旧状态前，先给计划并等待确认。

## 事实源收敛

修改已有项目级 skill 时，先确认 canonical 事实源位置：

1. 已在 `.agents/skills/<skill-name>/`：直接修改，再同步入口和 registry。
2. Skill 内容还在 `.claude/skills/`、`.grok/skills/`、`.opencode/skills/`、`.codex/skills/`、项目 README、docs、脚本说明或旧版 `docs/ai/`：这些位置视为迁移来源；迁入 `.agents/skills/<skill-name>/` 完整包前，先保留来源并核实迁移不会丢失文件或语义。
3. 已有 `.agents/skills/<skill-name>/` 时直接维护该完整包。其他发现目录应导出同一完整包；不要把 `.agents/skills/` 本身降格为薄入口。
4. 项目级通用规则仍放在 `AGENTS.md`、`CLAUDE.md` 或目标客户端规则入口，不因 Skill 单源化而搬进 Skill 包。
5. 迁移会覆盖、删除、改名或改变非空旧事实源时，先给计划并等待确认。

迁移后只保留一个完整包；需要多个发现目录时导出同一包。不要把项目规则复制成不同的工具专属版本，也不要把目标项目主 README 写成固定 agent 接手入口。

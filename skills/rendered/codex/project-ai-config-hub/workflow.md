# 项目级 AI 配置中枢流程

本 skill 是 `ai-config-hub` 的项目级分身。它不保存具体业务项目的长期规则，而是在目标项目里创建、升级、审计和修复轻量的 `.Ai-config/` 中枢、工作状态机制、项目级 skill 事实源和 Claude Code / Codex 双端入口。

用户不需要显式点名本 skill。只要请求涉及新增、修改、迁移、审计、修复或同步项目级 skill，或者涉及 `.Ai-config/`、旧版 `docs/ai/`、`.Ai-config/CURRENT.md`、`.Ai-config/tasks/`、`.claude/skills`、`.agents/skills`、`.codex/skills`，就按本流程工作。

## 0. 轻量化原则

项目级 AI 配置应按项目风险和接手价值渐进启用，不把完整中枢无差别铺到每个项目。

- 最小可用层：`AGENTS.md` 或 `CLAUDE.md` 加一段项目规则，适合小脚本、demo、一次性工具。
- 接手状态层：`.Ai-config/CURRENT.md`，适合长期项目或经常跨会话继续的项目。
- 任务卡层：`.Ai-config/tasks/`，只在任务会跨天、中断、多 AI 接手、等待确认、阻塞或有残留风险时使用。
- Skill 层：`.Ai-config/skills/` 与 `.claude/skills` / `.agents/skills` 入口，只在项目确实有可复用专门工作流时创建。

默认先建立足够轻的机制。只有用户要求、项目复杂度需要，或已有状态必须保留时，才升级到下一层。

## 1. 识别当前项目

先快速读取和检索最相关入口，不要求每次全量读取：

- `AGENTS.md`
- `AGENTS.override.md`
- `CLAUDE.md`
- `README.md`
- `docs/`
- `.Ai-config/`
- `docs/ai/`（旧版路径，仅作为迁移来源和兼容事实源；新配置写入 `.Ai-config/`）
- `CHANGELOG.md`
- `.github/instructions/`
- `.claude/skills/`
- `.agents/skills/`
- `.codex/skills/`
- `.claude-plugin/`
- `.codex-plugin/`

再按项目类型补充查看工程入口，例如 `package.json`、`pyproject.toml`、`Cargo.toml`、`go.mod`、`Makefile`、`docker-compose.yml`。

小项目或只读审计只需确认事实源和风险边界；不要为了“完整”读取无关目录。

## 2. 判断工作模式

先判断用户意图属于哪一种：

- `init`：初始化项目级 AI 配置中枢。
- `create`：创建新的项目级 skill。
- `update`：修改已有项目级 skill 或工作状态模板。
- `migrate`：迁移已有 `.codex/skills`、`.agents/skills`、`.claude/skills`、旧版 `docs/ai/` 或 v1 单槽位 `.Ai-config/CURRENT.md` 到 `.Ai-config/` 接手入口和任务卡。
- `audit`：审计事实源、入口、敏感信息、工作状态和文档一致性。
- `repair`：修复入口指向、registry、工作状态、过期路径和轻量不一致。

如果目标项目就是 `ai-config-hub` 本仓库，且用户说“更新项目 AI 配置”“更新项目配置”“让项目 AI 配置和全局配置匹配”“全局已同步，现在更新项目配置”等，默认按 `audit` + `repair` 处理，不要先让用户在通用更新类型中选择。先做低风险只读判断：优先读取 `.Ai-config/CURRENT.md`、`.Ai-config/skills-registry.md`、相关任务卡；如果 `.Ai-config/` 还不存在但存在旧版 `docs/ai/`，把 `docs/ai/` 当作迁移来源读取，再迁移到 `.Ai-config/`。同时对比 `rules/rendered/*` 与用户级全局规则文件、`skills/rendered/*` 与用户级全局 skill 目录。若 rendered/global 已一致，只刷新项目内 AI 状态文档；若不一致，先报告差异，再询问以项目源为准同步全局，还是以本机全局为准反向整理项目源。

## 3. 明确需求

归纳或确认：

- 任务是初始化中枢、升级工作状态机制，还是新增/修改项目级 skill。
- skill 名称和触发场景。
- 适用范围是当前项目、某个模块，还是可跨项目复用。
- 是否涉及发布、部署、生产数据、凭证、权限或共享状态。
- 是否需要 `references/`、`templates/`、`scripts/` 或检查清单。
- 是否需要兼容历史 `.codex/skills`。
- 是否需要把旧版 `docs/ai/` 或 v1 `.Ai-config/CURRENT.md` 迁移到 `.Ai-config/` 总览加任务卡。
- 是否需要后续做成 plugin 分发。

不要在低风险只读审计前要求用户选择更新类型。只有出现多个真实可行且会写入不同事实源、覆盖全局目录、迁移旧状态或删除入口的路径时，才询问用户取舍；询问选项必须包含当前项目语义下最可能的正确选项。

如果用户只是要求初始化中枢，先判断需要哪一层。默认不要直接创建完整目录树。

轻量初始化可只创建：

```text
.Ai-config/CURRENT.md
```

当项目需要多任务接手、项目级 skills 或长期归档时，再补充：

```text
.Ai-config/README.md
.Ai-config/tasks/README.md
.Ai-config/archive/
.Ai-config/skills-registry.md
```

不要强行创建具体业务 skill；没有项目级 skill 时，`skills-registry.md` 可以暂不创建。

如果用户要求修改已有项目级 skill，应先定位事实源：

1. 查 `.Ai-config/skills-registry.md`。
2. 查 `.Ai-config/skills/<skill-name>/`。
3. 查 `.claude/skills/<skill-name>/SKILL.md`。
4. 查 `.agents/skills/<skill-name>/SKILL.md`。
5. 必要时查历史 `.codex/skills/<skill-name>/SKILL.md`。

确认事实源后，优先修改事实源，再同步检查工具入口。

修改已有 skill 时，默认先做原地更新，不要先迁移：

1. 如果事实源已经在 `.Ai-config/skills/<skill-name>/`，直接修改事实源，再同步入口和 registry。
2. 如果完整规则还在 `.claude/skills/`、`.agents/skills` 或 `.codex/skills/`，先判断它是不是唯一事实源；只有用户明确要求迁移，或者必须先收敛到 `.Ai-config/` 才能继续时，才进入 `migrate`。
3. 如果只改入口、说明或状态，优先修入口和 registry，不改事实源结构。

## 4. 选择事实源和状态文件

完整形态的默认事实源和状态文件：

```text
.Ai-config/
.Ai-config/CURRENT.md
.Ai-config/tasks/
.Ai-config/tasks/README.md
.Ai-config/archive/
.Ai-config/skills-registry.md
.Ai-config/skills/<skill-name>/
```

`.Ai-config/CURRENT.md` 是 AI 接手入口和多任务状态总览；具体任务事实保存在 `.Ai-config/tasks/*.md`。它不是完整日志、日报或完成记录。

轻量项目可以只有 `.Ai-config/CURRENT.md`。任务卡、archive 和 registry 都是按需层，不是健康项目的硬性标志。

如果已有某个工具目录承载完整规则，应先识别真实事实源，再迁移到共享目录。迁移后，工具目录中的 `SKILL.md` 只保留薄入口。

不要把项目规则散落复制到多个工具目录。不要把目标项目主 README 强行写成固定 agent 接手入口；主 README 只作为项目概览，接手入口应在 `.Ai-config/CURRENT.md`。

## 5. 旧状态迁移

如果目标项目存在旧版 `docs/ai/` 且 `.Ai-config/` 不存在，应把 `docs/ai/` 视为旧配置事实源。迁移时保留 `CURRENT.md`、`tasks/`、`archive/`、`skills-registry.md` 和有价值的说明文件语义，把新路径统一落到 `.Ai-config/`；迁移完成前不要删除旧信息。

如果目标项目已有单槽位 `.Ai-config/CURRENT.md`，或旧版 `docs/ai/CURRENT.md` 需要迁入 `.Ai-config/CURRENT.md`：

1. 不要直接覆盖。
2. 先读取旧 `CURRENT.md`，判断状态是否为空闲。
3. 只有旧状态明确为空闲、无当前任务且无接手价值时，才可把 `CURRENT.md` 升级为 v2 总览，并保留旧“已确认/接手提示”中仍有价值的信息。
4. 不能确认为空闲的旧状态都应迁移为 `.Ai-config/tasks/YYYY-MM-DD-<topic>.md` 任务卡，包括 `进行中`、`暂停`、`阻塞`、`等待验证`、`待用户审核`、`待用户确认` 或自定义等价状态。
5. 新 `CURRENT.md` 指向迁移出的任务卡，并在总览中保留原状态。
6. 用户未确认前，不得删除旧信息。
7. 覆盖、迁移或删除旧状态前，应先给计划并等待确认。

## 6. 生成工具入口

默认生成：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
```

可选兼容：

```text
.codex/skills/<skill-name>/SKILL.md
```

工具入口应包含：

- frontmatter。
- 简短触发说明。
- 明确的共享事实源路径。
- 必读文件顺序。
- 安全边界和确认条件。

## 7. 计划和确认

只读审计可以直接执行。对 `ai-config-hub` 本仓库执行 rendered/global 一致性对比、刷新 `.Ai-config/CURRENT.md` 和任务卡状态这类低风险项目状态追平，也可以直接执行；如果要把本机全局内容反向覆盖项目源文件，或要执行 `sync.ps1 -Apply`、`sync-skills.ps1 -Apply` 写入用户级目录，则必须先确认。

以下情况必须先输出计划并等待用户确认：

- 覆盖已有 `SKILL.md`。
- 从旧目录迁移事实源。
- 覆盖或迁移非空闲的 `.Ai-config/CURRENT.md` 或旧版 `docs/ai/CURRENT.md`。
- 删除、停用或改名旧入口。
- 写入用户级全局目录。
- 写入历史兼容目录 `.codex/skills`。
- 涉及发布、部署、生产数据库、凭证、权限放宽或强制推送。

计划按风险裁剪。轻量修复可以只说明修改文件、验证方式和风险；迁移、覆盖或高风险操作才需要完整计划。完整计划至少列出：

- 新增文件。
- 修改文件。
- 保留文件。
- 明确不删除的旧路径，包括迁移中的旧版 `docs/ai/`。
- 文档索引是否更新。
- 是否创建或刷新 `.Ai-config/CURRENT.md`。
- 是否创建或迁移 `.Ai-config/tasks/*.md`。
- 验证方式。
- 风险和注意事项。

## 8. 实施和验证

实施后按实际层级检查：

- 没有接手价值的小改动，不强制创建 `.Ai-config/` 或任务卡。
- 只有 `CURRENT.md` 的轻量项目，应能说明当前活动任务、是否需要任务卡、后续应读哪里。
- 完整中枢项目再检查任务卡、archive、registry 和多端入口。

完整检查包括：

- frontmatter 是否完整。
- `.Ai-config/CURRENT.md` 是否是接手入口和多任务状态总览。
- `.Ai-config/tasks/` 是否按需创建，任务卡是否保留目标、上下文、已尝试/排除、验证、风险和下一步。
- 是否把未确认、未验证或有残留风险的任务直接关闭；这类任务应保持 `待用户确认`、`等待验证`、`阻塞` 或 `暂停`。
- 工具入口指向的共享文件是否存在。
- 是否存在多个互相冲突的事实源。
- `.Ai-config/skills-registry.md` 是否记录了新增或迁移的项目 skill。
- 修改已有项目级 skill 后，双端入口和 registry 仍指向同一事实源。
- 是否把计划中能力误写为已完成。
- 是否把主 README 误写成固定 agent 接手入口。
- 是否包含明显敏感信息。
- Claude Code / Codex 当前官方路径是否都覆盖。
- 历史 `.codex/skills` 是否仅作为兼容入口。

根据项目已有习惯运行最小相关验证，例如 `git diff --check`、lint、typecheck、测试、脚本 dry-run 或自检命令。

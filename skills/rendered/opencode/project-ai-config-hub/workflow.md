# 项目级 AI 配置中枢流程

本 skill 是 `ai-config-hub` 的项目级分身。它不保存具体业务项目的长期规则，而是在目标项目里创建、升级、审计和修复轻量的 `.Ai-config/` 中枢、工作状态机制、项目级 skill canonical 事实源和多工具薄入口。

用户不需要显式点名本 skill，但只有在请求明确涉及新增、修改、迁移、审计、修复或同步项目级 AI 配置中枢 / 项目级 skill 时，才按本流程工作。只是读取 `.Ai-config` 状态、普通业务任务恰好提到任务卡路径、一次性问答或局部修复，不进入完整 audit / repair 流程。

## 0. 轻量化原则

项目级 AI 配置应按项目风险和接手价值渐进启用，不把完整中枢无差别铺到每个项目。

- 最小可用层：`AGENTS.md` 或 `CLAUDE.md` 加一段项目规则，适合小脚本、demo、一次性工具。
- 接手状态层：`.Ai-config/CURRENT.md`，适合长期项目或经常跨会话继续的项目。
- 任务卡层：`.Ai-config/tasks/`，只在任务会跨天、中断、多 AI 接手、等待确认、阻塞或有残留风险时使用。
- Skill 层：项目级 skill 的 canonical 事实源统一放在 `.Ai-config/skills/<skill-name>/`；`.claude/skills` / `.agents/skills` / `.grok/skills` / `.opencode/skills` 只放工具发现薄入口，只在项目确实有可复用专门工作流时创建。

默认先建立足够轻的机制。只有用户要求、项目复杂度需要，或已有状态必须保留时，才升级到下一层。不要因为目标项目已经存在 `.Ai-config/`、任务卡或 skill 目录，就把普通业务任务升级成中枢审计；本 skill 也不自动拉起脉络、思维伙伴或同步流程，确需跨域时回到主任务路由判断主次。

项目级 skill 事实源必须收敛：普通目标项目中，durable 的 skill 规则、触发、workflow、checklist、references 和 templates 都应归入 `.Ai-config/skills/<skill-name>/`。项目 README、docs、脚本说明、旧版 `docs/ai/`、`.claude/skills`、`.agents/skills`、`.opencode/skills` 和 `.codex/skills` 可以作为迁移来源、支持性引用或工具入口，但不得作为长期主事实源。

## 1. 识别当前项目

先快速读取和检索最相关入口，不要求每次全量读取：

- `AGENTS.md` / `AGENTS.override.md` / `CLAUDE.md` / `opencode.json`
- `README.md`、`docs/`、`CHANGELOG.md`
- `.Ai-config/`
- 工具 skill 目录（`.claude/skills/`、`.agents/skills/`、`.grok/skills/`、`.opencode/skills/`）：工具入口或迁移来源，不作为长期事实源

再按项目类型补充查看工程入口，例如 `package.json`、`pyproject.toml`、`Cargo.toml`、`go.mod`、`Makefile`。

遇到旧版 `docs/ai/`、`.codex/skills/`、plugin 目录或 v1 单槽位 `CURRENT.md` 时，读 `references/migration.md`。

小项目或只读审计只需确认事实源和风险边界；不要为了「完整」读取无关目录。

## 2. 判断工作模式

先判断用户意图属于哪一种：

- `init`：初始化项目级 AI 配置中枢。
- `create`：创建新的项目级 skill。
- `update`：修改已有项目级 skill 或工作状态模板。
- `migrate`：迁移已有工具 skill 目录、旧版 `docs/ai/` 或 v1 单槽位 `CURRENT.md`，详见 `references/migration.md`。
- `audit`：审计事实源、入口、敏感信息、工作状态和文档一致性。
- `repair`：修复入口指向、registry、工作状态、过期路径、CURRENT hygiene 和已退役能力残留。

**默认聚合意图**：用户说「更新项目 AI 配置」「修复项目 AI 配置」「让项目 AI 配置和全局匹配」「全局已同步，现在更新项目配置」等时，默认按 **`audit` + `repair`** 执行，不要先让用户在通用更新类型里选择题。只有存在多个会写入不同事实源、覆盖全局目录、迁移或删除的真实分叉时才询问。

本 skill 是面向任意目标项目的通用流程，不识别「当前项目是不是 ai-config-hub 自己」。如果目标项目根目录 `CLAUDE.md` 或 `AGENTS.md` 有更具体的项目专属指引，先读那份文件，它优先于本 skill 的通用判断。

### audit + repair 必做清单（更新项目配置）

1. 读 `.Ai-config/CURRENT.md` 与活动任务卡；按 `references/current-hygiene.md` 做 CURRENT 健康检查并修复膨胀/禁区/双写不一致。
2. 检查项目级 skill 事实源是否收敛到 `.Ai-config/skills/`，薄入口是否仍指向 canonical。
3. 检查并清理已退役全局能力残留：如项目内 `pencil-design-workflow` 入口、registry 中的 pencil 行、过时 Pencil 说明；不要删除用户业务设计稿文件，除非用户明确要求。
4. 检查 registry、任务卡状态与 CURRENT 三区是否一致。
5. 低风险修复直接做；覆盖、删除非空事实源、写全局目录前先确认。
6. 汇报：修了什么、CURRENT 是否仍超限、残留风险、是否需要用户确认关闭的老任务。

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

启用脉络时也按需分层：

1. 全局 MCP / skill 可默认存在，但这只代表工具入口可用。
2. 目标项目只有在复杂代码关系、影响面、长期理解或用户明确要求时，才初始化 `.Ai-config/context-thread/context-thread.db`。
3. 项目初始化索引前应说明这是项目本地结构化事实源，数据库可按项目策略跟踪或忽略。
4. 索引自动更新只在 MCP server 正在运行且 watcher 可用时成立；否则需要手动 sync 或回退到读取当前文件。
5. 非代码复杂流程不要写入 context-thread DB，用 `.Ai-config/tasks/*.md` 的 `关系索引` 承接。

如果用户要求修改已有项目级 skill，先按 `references/migration.md` 的「事实源收敛」确认 canonical 位置，再做实质修改。

## 4. 选择事实源和状态文件

完整形态的默认状态文件和 canonical 事实源：

```text
.Ai-config/
.Ai-config/CURRENT.md
.Ai-config/tasks/
.Ai-config/tasks/README.md
.Ai-config/archive/
.Ai-config/skills-registry.md
.Ai-config/skills/<skill-name>/
```

其中 `.Ai-config/skills/<skill-name>/` 是普通目标项目中项目级 skill 的 canonical 事实源。其他项目文档可以被引用为证据或背景，但不能作为 registry 中的长期事实源路径。

`.Ai-config/CURRENT.md` 是 AI 接手入口和多任务状态总览；具体任务事实保存在 `.Ai-config/tasks/*.md`。它不是完整日志、日报或完成记录。

轻量项目可以只有 `.Ai-config/CURRENT.md`。任务卡、archive 和 registry 都是按需层，不是健康项目的硬性标志。

## 5. 生成工具入口

默认生成：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
.grok/skills/<skill-name>/SKILL.md
.opencode/skills/<skill-name>/SKILL.md
```

工具入口应包含 frontmatter、简短触发说明、canonical 事实源路径（`.Ai-config/skills/<skill-name>/`）、必读文件顺序、安全边界和确认条件。

工具入口不承载 durable 规则、workflow、checklist、references 或 templates。OpenCode 原生入口 `.opencode/skills/` 和历史兼容目录 `.codex/skills/` 都按需生成，见 `references/migration.md`。

## 6. 计划和确认

只读审计可以直接执行，包括刷新 `.Ai-config/CURRENT.md` 和任务卡状态这类低风险项目状态追平。目标项目自己的 `CLAUDE.md` / `AGENTS.md` 若定义了更具体的免确认边界，以那份文件为准。

以下情况必须先输出计划并等待用户确认：

- 覆盖已有 `SKILL.md`，或从旧目录迁移事实源。
- 覆盖或迁移非空闲的 `CURRENT.md`。
- 删除、停用或改名旧入口。
- 写入用户级全局目录（例如 `sync.ps1 -Apply`、`sync-skills.ps1 -Apply`）。
- 涉及发布、部署、生产数据库、凭证、权限放宽或强制推送。

计划按风险裁剪。轻量修复只说明修改文件、验证方式和风险；迁移、覆盖或高风险操作才列完整计划（新增/修改/保留文件、明确不删除的旧路径、文档索引、状态文件变化、验证方式、风险）。

## 7. 实施和验证

实施后按实际层级检查：

- 没有接手价值的小改动，不强制创建 `.Ai-config/` 或任务卡。
- 只有 `CURRENT.md` 的轻量项目，应能说明当前活动任务、是否需要任务卡、后续应读哪里。
- 完整中枢项目再检查任务卡、archive、registry 和多端入口。

完整检查清单以 `references/design-checklist.md` 为唯一权威，重点关注「实施后」和「工作状态腐化检查」两节。

根据项目已有习惯运行最小相关验证，例如 `git diff --check`、lint、typecheck、测试、脚本 dry-run 或自检命令。

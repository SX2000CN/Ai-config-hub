# 项目级 AI 配置中枢流程

本 skill 是 `ai-config-hub` 的项目级分身。它不保存具体业务项目的长期规则，而是在目标项目里创建和维护 `docs/ai/` 中枢、项目级 skill 事实源和 Claude Code / Codex 双端入口。

用户不需要显式点名本 skill。只要请求涉及新增、修改、迁移、审计、修复或同步项目级 skill，或者涉及 `docs/ai/`、`.claude/skills`、`.agents/skills`、`.codex/skills`，就按本流程工作。

## 1. 识别当前项目

先快速读取和检索：

- `AGENTS.md`
- `AGENTS.override.md`
- `CLAUDE.md`
- `README.md`
- `docs/`
- `CHANGELOG.md`
- `.github/instructions/`
- `.claude/skills/`
- `.agents/skills/`
- `.codex/skills/`
- `.claude-plugin/`
- `.codex-plugin/`

再按项目类型补充查看工程入口，例如 `package.json`、`pyproject.toml`、`Cargo.toml`、`go.mod`、`Makefile`、`docker-compose.yml`。

## 2. 判断工作模式

先判断用户意图属于哪一种：

- `init`：初始化项目级 AI 配置中枢。
- `create`：创建新的项目级 skill。
- `update`：修改已有项目级 skill。
- `migrate`：迁移已有 `.codex/skills`、`.agents/skills` 或 `.claude/skills`。
- `audit`：审计事实源、入口、敏感信息和文档一致性。
- `repair`：修复入口指向、registry、过期路径和轻量不一致。

## 3. 明确 skill 需求

归纳或确认：

- skill 名称和触发场景。
- 适用范围是当前项目、某个模块，还是可跨项目复用。
- 是否涉及发布、部署、生产数据、凭证、权限或共享状态。
- 是否需要 `references/`、`templates/`、`scripts/` 或检查清单。
- 是否需要兼容历史 `.codex/skills`。
- 是否需要后续做成 plugin 分发。

如果用户只是要求初始化中枢，应先设计 `docs/ai/README.md` 和 `docs/ai/skills-registry.md`，不强行创建具体业务 skill。

如果用户要求修改已有项目级 skill，应先定位事实源：

1. 查 `docs/ai/skills-registry.md`。
2. 查 `docs/ai/skills/<skill-name>/`。
3. 查 `.claude/skills/<skill-name>/SKILL.md`。
4. 查 `.agents/skills/<skill-name>/SKILL.md`。
5. 必要时查历史 `.codex/skills/<skill-name>/SKILL.md`。

确认事实源后，优先修改事实源，再同步检查工具入口。

修改已有 skill 时，默认先做原地更新，不要先迁移：

1. 如果事实源已经在 `docs/ai/skills/<skill-name>/`，直接修改事实源，再同步入口和 registry。
2. 如果完整规则还在 `.claude/skills/`、`.agents/skills/` 或 `.codex/skills/`，先判断它是不是唯一事实源；只有用户明确要求迁移，或者必须先收敛到 `docs/ai/` 才能继续时，才进入 `migrate`。
3. 如果只改入口、说明或状态，优先修入口和 registry，不改事实源结构。

## 4. 选择事实源

默认事实源：

```text
docs/ai/
docs/ai/skills-registry.md
docs/ai/skills/<skill-name>/
```

如果已有某个工具目录承载完整规则，应先识别真实事实源，再迁移到共享目录。迁移后，工具目录中的 `SKILL.md` 只保留薄入口。

不要把项目规则散落复制到多个工具目录。

## 5. 生成工具入口

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

## 6. 计划和确认

只读审计可以直接执行。

以下情况必须先输出计划并等待用户确认：

- 覆盖已有 `SKILL.md`。
- 从旧目录迁移事实源。
- 删除、停用或改名旧入口。
- 写入用户级全局目录。
- 写入历史兼容目录 `.codex/skills`。
- 涉及发布、部署、生产数据库、凭证、权限放宽或强制推送。

计划至少列出：

- 新增文件。
- 修改文件。
- 保留文件。
- 明确不删除的旧路径。
- 文档索引是否更新。
- 验证方式。
- 风险和注意事项。

## 7. 实施和验证

实施后检查：

- frontmatter 是否完整。
- 工具入口指向的共享文件是否存在。
- 是否存在重复事实源。
- `docs/ai/skills-registry.md` 是否记录了新增或迁移的项目 skill。
- 是否把计划中能力误写为已完成。
- 是否包含明显敏感信息。
- Claude Code / Codex 当前官方路径是否都覆盖。
- 历史 `.codex/skills` 是否仅作为兼容入口。

根据项目已有习惯运行最小相关验证，例如 `git diff --check`、lint、typecheck、测试、脚本 dry-run 或自检命令。

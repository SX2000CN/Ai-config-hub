# project-ai-config-hub 计划

最后更新时间：2026-05-08

## 一句话定位

`project-ai-config-hub` 是 `ai-config-hub` 的项目级分身。

`ai-config-hub` 管全局规则、全局 skills 和本机同步流程；`project-ai-config-hub` 作为全局 skill 安装到 Claude Code 和 Codex 后，负责进入任意业务项目，创建和维护该项目自己的 AI 配置中枢。

## 为什么需要它

Claude Code 和 Codex 没有一个共同自动加载的项目级 skill 目录：

- Claude Code 项目级入口是 `.claude/skills/<skill-name>/SKILL.md`。
- Codex 项目级入口是 `.agents/skills/<skill-name>/SKILL.md`。
- `.codex/skills` 只作为历史或本机兼容路径处理。

因此项目级多端 skill 不能依赖一个“中立加载目录”。正确模型是：

- 中立目录做事实源。
- 工具官方目录做薄入口。
- 全局 skill 负责创建、迁移、审计和修复这套结构。

## 名称

推荐正式名称：

```text
project-ai-config-hub
```

理由：

- 和主项目 `ai-config-hub` 呼应，表达“项目级分身”。
- 覆盖 AI 规则、skills、入口、文档索引，不局限于“skill 管理器”。
- 比旧名“项目 skill 管理器”更适合长期扩展到项目级 AI 配置中枢。

## 形态

它本身由本仓库维护：

```text
ai-config-hub/
  skills/
    shared/project-ai-config-hub/
    claude-code/project-ai-config-hub/SKILL.md
    codex/project-ai-config-hub/SKILL.md
    rendered/
```

同步后安装到用户级全局目录：

```text
C:\Users\sx200\.claude\skills\project-ai-config-hub\
C:\Users\sx200\.agents\skills\project-ai-config-hub\
```

可选历史兼容目录：

```text
C:\Users\sx200\.codex\skills\project-ai-config-hub\
```

## 它在目标项目里创建什么

默认推荐结构：

```text
target-project/
  docs/
    ai/
      README.md
      skills-registry.md
      skills/
        <skill-name>/
          README.md
          workflow.md
          checklists.md
          references/
          templates/

  .claude/
    skills/
      <skill-name>/
        SKILL.md

  .agents/
    skills/
      <skill-name>/
        SKILL.md
```

只有在已有历史路径或用户明确要求兼容时，才追加：

```text
target-project/
  .codex/
    skills/
      <skill-name>/
        SKILL.md
```

含义：

- `docs/ai/` 是目标项目的 AI 配置中枢。
- `docs/ai/skills-registry.md` 记录项目级 skills 清单、事实源、入口和状态。
- `docs/ai/skills/<skill-name>/` 是具体项目 skill 的事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 薄入口。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 薄入口。

## 无感触发策略

用户不需要显式说“使用 `project-ai-config-hub`”。只要需求涉及项目级 skill 的新增、修改、迁移、审计、修复、同步、双端入口或 `docs/ai/` 事实源，就应自动触发本 skill。

注意：无感触发是 `project-ai-config-hub` 已同步安装到用户级 skill 目录后的目标行为。安装前，或工具没有自动匹配 description 时，用户仍可显式提到 `project-ai-config-hub`，或直接描述“项目级 skill / docs/ai / 双端入口”等需求来触发同一流程。

应该触发：

```text
给这个项目创建一个 release skill
```

```text
修改这个项目的 release skill，让 Claude Code 和 Codex 都能用
```

```text
把现有 .codex/skills/strobe-release 整理成双端项目 skill
```

```text
检查这个项目的 skills 有没有分叉
```

```text
修复 .claude/skills 和 .agents/skills 的入口不一致
```

也支持显式触发：

```text
用 project-ai-config-hub 初始化这个项目的 AI 配置中枢
```

自然语言触发也应支持：

- “给这个项目搭一个 AI 配置中枢”
- “给这个项目做多端 skill”
- “把这个项目的 Codex skill 迁移到 Claude Code 也能用”
- “检查这个项目的项目级 skills 有没有分叉”
- “修改项目级 skill”
- “同步 Claude Code 和 Codex 的项目 skill”
- “给项目 skill 加一个检查清单”

不应触发：

- 普通业务代码修改，且不涉及项目级 skill、AI 配置或工具入口。
- 一次性临时提示词实验，且用户明确不想沉淀为项目 skill。
- 全局规则或全局 skill 管理；这类仍由 `ai-config-hub` 主项目处理。

## 用户工作流

### 1. 初始化

用户进入某个业务项目后，只要说：

```text
初始化这个项目的 AI 配置
```

或：

```text
给这个项目搭一个 AI 配置中枢
```

AI 应先审计：

- 项目文档：`README.md`、`docs/`、`CHANGELOG.md`
- AI 规则：`AGENTS.md`、`AGENTS.override.md`、`CLAUDE.md`
- 已有 skill：`.claude/skills/`、`.agents/skills/`、`.codex/skills/`
- 插件目录：`.claude-plugin/`、`.codex-plugin/`
- 工程入口：`package.json`、`pyproject.toml`、`Cargo.toml`、`go.mod` 等

然后输出计划，说明是否创建：

- `docs/ai/README.md`
- `docs/ai/skills-registry.md`
- `docs/ai/skills/<skill-name>/`
- `.claude/skills/<skill-name>/SKILL.md`
- `.agents/skills/<skill-name>/SKILL.md`

用户确认后再实施。

### 2. 创建项目 skill

用户说：

```text
给这个项目创建一个 <skill-name> skill
```

或说：

```text
把 <skill-name> 这个项目级 skill 改一下
```

AI 应自动触发本 skill，并确认或归纳：

- skill 名称
- 触发场景
- 事实源内容
- 是否涉及发布、部署、生产数据、凭证或高风险操作
- 是否需要脚本、模板、检查清单
- 是否需要 `.codex/skills` 兼容

然后生成事实源和双端入口。

### 3. 迁移已有 skill

用户说：

```text
迁移这个项目已有的 skill
```

AI 应先识别哪个目录是真实事实源，再迁移到：

```text
docs/ai/skills/<skill-name>/
```

迁移后工具目录只保留薄入口，不再复制完整业务规则。

### 4. 修改、审计和修复

修改项目级 skill 时，应先识别该 skill 的事实源和入口，再修改事实源，并同步检查 `.claude/skills`、`.agents/skills` 和 registry 是否仍一致。

审计时只读执行即可。修复前如涉及覆盖、迁移、删除或写入新入口，必须先列计划并等待确认。

## 工作模式

建议在 skill 内明确六种模式：

- `init`：初始化项目级 AI 配置中枢。
- `create`：创建新的项目级 skill。
- `update`：修改已有项目级 skill。
- `migrate`：迁移已有 `.codex/skills`、`.agents/skills` 或 `.claude/skills`。
- `audit`：审计事实源、入口、敏感信息和文档一致性。
- `repair`：修复入口指向、registry、过期路径和轻量不一致。

## 职责边界

应该做：

- 把 `ai-config-hub` 的“源文件、渲染、检查、同步”思想带到项目级。
- 帮目标项目创建 `docs/ai/` 中枢和项目 skills registry。
- 为 Claude Code 和 Codex 生成官方路径下的薄入口。
- 审计和修复项目级 skills 的事实源一致性。
- 对高风险操作先给计划并等待确认。

不应该做：

- 把某个业务项目的发布、部署、数据库规则写进全局 skill。
- 绕过项目已有文档和配置。
- 静默覆盖已有 `SKILL.md`。
- 静默删除旧 `.codex/skills` 或其他历史入口。
- 把真实凭证写入 skill、模板或普通项目文档。

## v1 验证和同步策略

当前 v1 的本地验证顺序：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
.\scripts\sync-skills.ps1
```

上述 `sync-skills.ps1` 默认只做 dry-run，不写入真实全局目录。

用户确认后，才执行真实同步：

```powershell
.\scripts\sync-skills.ps1 -Apply
```

如需同时写入旧 Codex 兼容目录，再追加：

```powershell
.\scripts\sync-skills.ps1 -Apply -IncludeCodexLegacy
```

当前同步策略：

- 默认 dry-run。
- `-Apply` 才写入真实用户级 skill 目录。
- 如果目标目录已存在，必须先确认它是本仓库托管的 `project-ai-config-hub` skill。
- 对托管目标采用“整体目录替换”策略，替换前先备份目标目录。
- 如果目标目录存在但不是本仓库托管产物，脚本必须停止，不能覆盖。

## Strobe 试点验收标准

Strobe 是第一个建议试点项目，但 `project-ai-config-hub` 不应把 Strobe 的具体发布规则写入全局 skill。

试点验收标准：

1. 能识别 Strobe 已有 `.codex/skills/strobe-release`。
2. 能输出迁移计划，而不是直接迁移。
3. 推荐 `docs/ai/skills/strobe-release/` 作为项目内事实源。
4. 推荐 `.claude/skills/strobe-release/SKILL.md` 作为 Claude Code 项目入口。
5. 推荐 `.agents/skills/strobe-release/SKILL.md` 作为 Codex 当前官方项目入口。
6. 默认保留 `.codex/skills/strobe-release/SKILL.md` 作为历史兼容入口。
7. 不直接删除旧 `references/`。
8. 不执行发布、部署或生产写入操作。

## 后续实施计划

1. 继续完善 `init`、`create`、`update`、`migrate`、`audit`、`repair` 六种模式的模板。
2. 按 v1 验证顺序完成本地 dry-run 检查。
3. 在 Strobe 中试运行初始化和审计流程。
4. 用户确认后同步到真实全局 skill 目录。
5. 记录首次安装结果和后续维护方式。

# 全局项目级 AI 配置中枢 Skill 设计

最后核验时间：2026-05-08

本文设计 `ai-config-hub` 中的全局双端 skill：`project-ai-config-hub`。它是 `ai-config-hub` 的项目级分身，用来在 Claude Code 和 Codex 中进入任意目标项目，创建 `docs/ai/` 项目级 AI 配置中枢，并辅助创建、迁移、审计和修复项目级 skills。

## 背景和目标

`ai-config-hub` 是本机 AI 编程工具配置中枢，当前已管理 Claude Code 和 Codex 的全局规则，并为 skills 管理预留了目录。

本方案要解决的问题：

- Claude Code 和 Codex 的 skill 目录不同，不能假设存在天然共享入口。
- 项目级 skill 很容易在 `.claude/skills`、`.agents/skills`、历史 `.codex/skills` 之间分叉。
- 具体项目的发布、部署、安全、测试等规则应留在项目内，不能硬编码进全局个人 skill。
- 全局 skill 安装后不应依赖 `ai-config-hub` 仓库的相对路径，否则迁移、备份或单工具使用时容易失效。
- 主项目管全局配置，项目级分身负责把管理能力带进具体业务项目。

目标：

1. 在本仓库维护一个通用 `project-ai-config-hub`。
2. 支持生成 Claude Code 和 Codex 的项目级 薄入口。
3. 引导目标项目建立单一事实源，减少多端 skill 长期漂移。
4. 对旧路径、插件分发、symlink、敏感信息和覆盖行为给出明确边界。

非目标：

- 不为某个业务项目写具体发布、部署或生产规则。
- 不直接执行生产发布、数据库变更、凭证写入等高风险操作。
- 不承诺支持未经当前官方文档确认的读取路径。

## 官方路径和兼容边界

| 范围 | Claude Code | Codex | 说明 |
|---|---|---|---|
| 用户级 / 全局 skill | `~/.claude/skills/<skill-name>/SKILL.md` | `$HOME/.agents/skills/<skill-name>/SKILL.md` | 新增全局 skill 时优先使用官方当前路径。 |
| 项目级 skill | `.claude/skills/<skill-name>/SKILL.md` | `.agents/skills/<skill-name>/SKILL.md` | 新项目默认生成这两个入口。 |
| 插件内 skill | `<plugin>/skills/<skill-name>/SKILL.md` | `<plugin>/skills/<skill-name>/SKILL.md` | 可复用分发形态，适合 v2。 |
| Codex 历史 / 本机兼容路径 | 不支持 | `.codex/skills/<skill-name>/SKILL.md` | 仅在目标项目已有或用户明确需要兼容时保留；不作为新项目默认事实源。 |
| 任意共享源目录 | 未发现官方自动读取保证 | 未发现官方自动读取保证 | 可作为仓库内事实源，但需要 薄入口 或渲染产物指向它。 |
| symlink | 未作为双端默认方案 | 官方文档说明 Codex 支持 symlinked skill folders | 为了双端一致和 Windows 权限可控，v1 仍默认 materialize，而不是依赖 symlink。 |

结论：

- Claude Code 和 Codex 没有一个共同自动读取的裸 skill 目录。
- 新项目应以 `.claude/skills` 和 `.agents/skills` 为双端入口。
- `.codex/skills` 可以作为历史兼容路径处理，但文档和脚本必须标注它不是当前 Codex 官方作者路径。
- Codex reusable 分发应优先考虑 plugin；本仓库本机同步可以先走裸 skill 目录，后续再补 plugin 包。

参考资料：

- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
- Codex Agent Skills: https://developers.openai.com/codex/skills
- Codex build plugins: https://developers.openai.com/codex/plugins/build

## 推荐全局 skill 名称

推荐名称：`project-ai-config-hub`

用途：当用户新增、修改、迁移、审计、修复或同步项目级 skill 时无感触发，尤其是涉及 Claude Code 和 Codex 多端入口时使用。

建议 Codex frontmatter：

```yaml
---
name: project-ai-config-hub
description: ai-config-hub 的项目级分身；当用户新增、修改、迁移、审计、修复或同步项目级 skill 时自动使用，覆盖项目 AI 配置中枢 docs/ai、skills-registry、Claude Code .claude/skills、Codex .agents/skills、可选 .codex/skills 兼容入口和多端 skill 事实源。
---
```

建议 Claude Code frontmatter：

```yaml
---
name: project-ai-config-hub
description: ai-config-hub 的项目级分身；当用户新增、修改、迁移、审计、修复或同步项目级 skill 时自动使用，覆盖项目 AI 配置中枢 docs/ai、skills-registry、Claude Code .claude/skills、Codex .agents/skills、可选 .codex/skills 兼容入口和多端 skill 事实源。
---
```

## 本仓库结构

建议在本仓库中维护四类内容：

```text
skills/
  shared/
    project-ai-config-hub/
      README.md
      workflow.md
      references/
        official-paths.md
        design-checklist.md
      templates/
        project-readme.md.tpl
        claude-skill.md.tpl
        codex-skill.md.tpl
        codex-legacy-skill.md.tpl

  claude-code/
    project-ai-config-hub/
      SKILL.md

  codex/
    project-ai-config-hub/
      SKILL.md

  rendered/
    claude-code/
      project-ai-config-hub/
        SKILL.md
        references/...
        templates/...
    codex/
      project-ai-config-hub/
        SKILL.md
        references/...
        templates/...
    codex-legacy/
      project-ai-config-hub/
        SKILL.md
        references/...
        templates/...
```

### 共享源

`skills/shared/project-ai-config-hub/` 是本仓库内的唯一事实源，保存通用工作流、检查清单、路径说明和模板。这里可以记录双端共同规则，但不写某个业务项目的具体流程。

### 工具专属入口源

`skills/claude-code/project-ai-config-hub/SKILL.md` 和 `skills/codex/project-ai-config-hub/SKILL.md` 是工具专属入口源文件。它们只负责：

- 说明何时触发该 skill。
- 说明应优先读取同包内的 `workflow.md`、`references/` 和 `templates/`。
- 补充工具专属限制，例如 Claude Code frontmatter、Codex plugin / `.agents` 路径差异。

### 渲染结果

`skills/rendered/` 是同步到真实全局 skill 目录前的 materialized 包。渲染时应把共享文档复制进每个工具的 skill 包，避免安装后 薄入口 依赖本仓库路径。

默认安装目标：

```text
C:\Users\sx200\.claude\skills\project-ai-config-hub\
C:\Users\sx200\.agents\skills\project-ai-config-hub\
```

可选历史兼容目标：

```text
C:\Users\sx200\.codex\skills\project-ai-config-hub\
```

## 职责边界

应该做：

1. 审计当前项目是否已有 AI 配置和 skill 目录。
2. 识别现有事实源文档、自动化入口和工具专属 薄入口。
3. 设计项目级 skill 的共享权威目录。
4. 生成 Claude Code 和 Codex 双端 薄入口。
5. 在目标项目已有 `.codex/skills` 或用户明确要求时保留历史兼容入口。
6. 检查 frontmatter、薄入口 指向、敏感信息、重复事实源和路径一致性。
7. 对迁移、覆盖、全局写入和高风险操作先输出计划并等待确认。

不应该做：

1. 把某个业务项目的具体发布规则写入全局 skill。
2. 直接发布、部署或操作生产系统。
3. 自动删除旧 skill 目录。
4. 把真实凭证写入 skill、模板或普通项目文档。
5. 默认依赖 symlink 作为双端同步实现。
6. 静默覆盖目标项目已有 skill。
7. 把 `.codex/skills` 写成新项目的唯一入口。

## 目标项目推荐结构

当 `project-ai-config-hub` 在任意业务项目中创建项目级 skill 时，默认推荐：

```text
target-project/
  docs/
    ai/
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

仅在已有历史路径或明确兼容需求时追加：

```text
target-project/
  .codex/
    skills/
      <skill-name>/
        SKILL.md
```

规则：

- `docs/ai/` 是目标项目的 AI 配置中枢。
- `docs/ai/skills-registry.md` 记录项目级 skills 清单、事实源、入口和状态。
- `docs/ai/skills/<skill-name>/` 是项目级 skill 的权威来源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 项目入口。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 当前官方项目入口。
- `.codex/skills/<skill-name>/SKILL.md` 只作为历史兼容 薄入口。
- 薄入口 必须明确引用共享源文件路径，不能只写泛泛的“读取文档”。
- 如项目已有发布、部署或架构文档，skill 文档应引用它们，不重复粘贴大段内容。

## 工作流

### 1. 识别项目

检查当前项目：

- `README.md`
- `docs/`
- `CLAUDE.md`
- `AGENTS.md`
- `.claude/skills/`
- `.agents/skills/`
- `.codex/skills/`
- `.claude-plugin/`、`.codex-plugin/`
- 常见工程入口，例如 `package.json`、`pyproject.toml`、`Cargo.toml` 等。

### 2. 明确 skill 需求

确认或归纳：

- skill 名称。
- 触发场景。
- 适用项目范围。
- 是否涉及发布、部署、生产数据、凭证或高风险操作。
- 是否需要 scripts、references、templates、checklists。
- 是否需要 Codex 历史 `.codex/skills` 兼容。
- 是否需要作为 plugin 分发，而不只是本项目或本机使用。

### 3. 选择事实源策略

默认使用：

```text
docs/ai/skills/<skill-name>/
```

如果项目已有 `.codex/skills/<name>`、`.agents/skills/<name>` 或 `.claude/skills/<name>` 承载完整规则，应先识别真实事实源，再迁移到共享目录。迁移后，工具目录中的 `SKILL.md` 应变为薄入口。

### 4. 生成双端薄入口

默认生成：

```text
.claude/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
```

可选生成：

```text
.codex/skills/<skill-name>/SKILL.md
```

薄入口要求：

- frontmatter 必须包含清晰的 `description`。
- 如果工具支持 `name`，应显式写入稳定名称。
- 正文第一屏应明确列出共享源文件路径。
- 不复制完整业务流程，只负责把模型导向共享源和项目真实文档。

### 5. 计划和确认

只读审计可以直接执行并输出结果。

以下操作实施前必须列出计划并等待用户确认：

- 覆盖已有 `SKILL.md`。
- 从旧目录迁移事实源。
- 删除或停用旧入口。
- 写入用户级全局目录，例如 `~/.claude/skills` 或 `$HOME/.agents/skills`。
- 写入历史兼容目录 `.codex/skills`。
- 涉及发布、部署、生产数据库、凭证或权限放宽。

计划中应列出：

- 新增文件。
- 修改文件。
- 保留文件。
- 明确不删除的旧路径。
- 是否更新项目文档索引。
- 验证方式。
- 风险和注意事项。

### 6. 实施后检查

实施后检查：

- `SKILL.md` frontmatter 是否完整。
- 薄入口指向的共享文档是否存在。
- 是否存在重复事实源。
- 是否有明显敏感信息。
- Claude Code / Codex 当前官方路径是否都已覆盖。
- 历史兼容路径是否被清楚标注为兼容入口。
- 如果生成 plugin，manifest 和 plugin 根目录结构是否符合对应工具要求。

## 推荐脚本

新增独立脚本，而不是直接并入现有 `render.ps1` / `sync.ps1`：

```text
scripts/render-skills.ps1
scripts/check-skills.ps1
scripts/sync-skills.ps1
```

### render-skills.ps1

职责：

- 从 `skills/shared/` 和工具专属入口生成 `skills/rendered/`。
- 将共享 `references/`、`templates/`、`workflow.md` materialize 到 Claude Code 和 Codex skill 包内。
- 可选生成 `skills/rendered/codex-legacy/`。
- 不直接写入用户级全局目录。

### check-skills.ps1

职责：

- 检查 rendered skill 目录是否存在。
- 检查 `SKILL.md` frontmatter。
- 检查 `name`、`description`。
- 检查 薄入口 引用的 references、templates、workflow 文件是否存在。
- 检查模板占位符是否残留。
- 检查同一目标内是否存在重复 skill name。
- 扫描明显敏感信息模式。
- 检查 `.codex/skills` 是否只作为兼容目标出现。

### sync-skills.ps1

建议用法：

```powershell
.\scripts\sync-skills.ps1
.\scripts\sync-skills.ps1 -Apply
.\scripts\sync-skills.ps1 -Apply -IncludeCodexLegacy
```

同步目标：

```text
skills/rendered/claude-code/project-ai-config-hub/
  -> C:\Users\sx200\.claude\skills\project-ai-config-hub\

skills/rendered/codex/project-ai-config-hub/
  -> C:\Users\sx200\.agents\skills\project-ai-config-hub\

skills/rendered/codex-legacy/project-ai-config-hub/
  -> C:\Users\sx200\.codex\skills\project-ai-config-hub\
```

同步原则：

- 默认 dry-run。
- `-Apply` 才写入真实全局目录。
- 写入前备份目标。
- 对已确认由本仓库托管的目标目录，采用整体目录替换策略，替换前先备份目标目录。
- 如果目标已有同名 skill 且不是本仓库托管产物，必须停下并提示用户确认，不能覆盖。

## 与现有脚本的关系

当前：

```text
scripts/render.ps1      管理全局规则渲染
scripts/check.ps1       管理全局规则检查
scripts/sync.ps1        管理全局规则同步
```

建议新增 skill 专用脚本，暂不合并：

```text
scripts/render-skills.ps1
scripts/check-skills.ps1
scripts/sync-skills.ps1
```

理由：

- 规则同步是单文件。
- skill 同步是目录包。
- skill 未来可能有多个。
- 目录同步风险更高，应单独 dry-run 和 Apply。

后续成熟后可以再新增：

```text
scripts/sync-all.ps1
```

## Plugin 分发策略

v1 先实现本机裸 skill 同步：

- Claude Code: `~/.claude/skills/project-ai-config-hub/`
- Codex: `$HOME/.agents/skills/project-ai-config-hub/`

v2 再评估 plugin 包：

```text
plugins/
  claude-code/
    project-ai-config-hub/
      .claude-plugin/
        plugin.json
      skills/
        project-ai-config-hub/
          SKILL.md
          references/...
          templates/...

  codex/
    project-ai-config-hub/
      .codex-plugin/
        plugin.json
      skills/
        project-ai-config-hub/
          SKILL.md
          references/...
          templates/...
```

采用 plugin 的条件：

- 需要跨机器、跨仓库或团队分发。
- 需要把多个 skills、MCP、app mapping、hooks 或素材作为一个包管理。
- 需要避免用户级目录手工同步。

暂不在 v1 做 plugin 的原因：

- 当前需求主要是本机配置中枢管理。
- 本仓库已有 `render/check/sync` 风格，裸 skill 同步更容易验证。
- plugin 会引入 marketplace、manifest 和安装流程，适合在基础 skill 稳定后再做。

## v1 实施计划

当前状态：

- 已有本设计文档。
- 已新增 `docs/archive/project-ai-config-hub/plan.md` 记录用户视角计划。
- 已实现 skill 源码化、rendered 包、检查脚本和 dry-run 同步流程。

下一步：

1. 根据 `project-ai-config-hub` 新定位继续完善模板。
2. 在真实业务项目中试运行 `init`、`create`、`audit` 三种模式。
3. 用户确认后同步到真实全局 skill 目录。
4. 记录首次安装结果和后续维护方式。

## 风险和注意事项

- 官方未提供 Claude Code / Codex 共同自动读取目录。
- Codex 官方支持 symlinked skill folders，但 Claude Code 双端一致性和 Windows 权限仍需要谨慎处理。
- 薄入口 只能通过指令要求模型读取共享文档，不是文件系统级强制 include。
- 因此全局 skill 安装包应 materialize 共享 references、templates 和 workflow，而不是只引用本仓库路径。
- 项目级 skill 应避免把完整规则复制到多个工具目录。
- `.codex/skills` 只能作为历史兼容入口处理，不应作为新项目唯一入口。
- 涉及发布、部署、生产数据库、凭证、全局目录写入或覆盖已有 skill 时，必须先输出计划并等待用户确认。




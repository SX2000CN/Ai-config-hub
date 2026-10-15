# AI 配置设计

本项目真正维护的是可移植的协作规则和完整 Agent Skill 包。配置如何被 Claude Code、Codex、OpenCode 等客户端发现，是适配问题；MCP、hooks、settings、permissions、subagents、plugins 和本机 runtime 属于各客户端的集成面，不构成通用配置本体。

## 设计目标

- 让同一份规则和 Skill 内容在支持相同格式的客户端之间保持一致。
- 把内容格式与客户端发现路径分开；格式兼容不等于自动发现。
- 让 `.Ai-config/` 保持为项目状态、registry 和索引层。
- 仅在确有需要时维护客户端 adapter 和本机部署脚本。
- 通过对源包的结构检查和 adapter 导出检查发现内容分叉。
- 让普通规则或 Skill 修改可以在不依赖 MCP/runtime 或用户目录的情况下完成仓库内验证。

## 术语与所有权

### 可移植规则

规则是普通 Markdown 内容。`rules/shared/core.md` 维护跨工具协作约束；客户端入口可能是 `AGENTS.md`、`CLAUDE.md` 或工具自己的配置字段。没有一个文件名能让所有客户端以完全相同的优先级自动加载。

### Agent Skill 包

Agent Skills 是开放的包格式。每个包有 `SKILL.md`，可带 references、templates、scripts 或其他资源。规范定义包结构和 `SKILL.md` 元数据，不规定客户端发现路径。

本仓库将完整包放在 `skills/shared/<name>/`。标准字段放在 `SKILL.md` 的 frontmatter；工具触发条件写在 `description` 和正文中。`when_to_use` 不是规范字段，不能作为跨工具语义源。当前导出的包内容应逐文件与唯一源一致。

### 客户端 adapter

Adapter 负责把本体放入客户端识别的位置或语法中，不承载第二份长期规则。当前 Skills adapter 是：

| Adapter | 发现目录 | 说明 |
|---|---|---|
| Claude Code | `.claude/skills/` | Claude 专用发现目录；从相同完整包导出 |
| Codex | `.agents/skills/` | 客户端支持的发现目录 |
| OpenCode | `.agents/skills/` 和 `.claude/skills/` 兼容扫描 | 同名包会重复发现；让目标版本只暴露一个发现根。若版本提供关闭兼容扫描的开关，在 adapter 层核验后使用，不把人工环境变量当作跨版本标准 |

`.agents/skills/` 是路径约定，不是 Agent Skills 规范要求；Claude Code 不会因此自动读取该目录。其他规则、MCP 和 hooks 的发现/配置语法也需分别适配。

### `.Ai-config/` 状态与索引

`.Ai-config/` 保存当前任务状态、任务卡、配置 registry 和项目结构索引。`CURRENT.md` 是跨会话状态入口；任务卡是需要接手的工作事实；`skills-registry.md` 只指向包和 adapter。可复用 Skill 内容不放入 `.Ai-config/skills/`，也不把 `.Ai-config/` 当作通用内容源。

context-thread 数据库是项目代码结构的索引缓存。它帮助定位文件与关系，不决定协作规则，也不取代当前源文件或用户提供的现场。

### 可选工具集成

MCP servers、hooks、settings/permissions、subagents 和 plugins 是客户端或协议各自提供的集成能力。它们可能共享概念，但没有因此变成同一可移植配置 schema。把一份本地 MCP 配置包装成多个客户端格式，只能称为 adapter。

## 当前仓库结构

```text
rules/shared/core.md                 共享协作规则源
skills/shared/<name>/                完整 Agent Skill 包
skills/evals/                        路由与行为检查样例
.Ai-config/                          项目状态、registry、任务卡和索引
config/managed-assets.psd1           当前 adapter / 部署资产登记
rules/rendered/ skills/rendered/     仓库内生成的客户端导出
tool-configs/ tools/ scripts/        可选 MCP/runtime 与交付工具
```

`skills/claude-code/` 和 `skills/codex/` 是没有被新渲染流程消费的旧入口目录，暂保留为迁移/清理候选，不是 Skill 内容事实源。不要在其中维护内容。历史任务卡、归档文档和 rendered 文件保留其历史语义，不作为新事实源。

## 验证边界

普通规则或 Skill 修改先运行 `scripts/check-content.ps1`。该入口覆盖共享规则 render/check、规则 hygiene、Skill render/check、包结构与引用/export 一致性、必要的敏感内容检查和 `git diff --check`；它不要求 MCP/runtime、用户级配置、hooks、doctor 或用户目录同步。规则和 Skill 的用户级 Apply 只运行该内容 preflight；跨管线或部署集成才运行 `scripts/check-all.ps1`，并按其结果单独记录 runtime、MCP 和 dry-run 状态。

## 维护规则

- 一项长期规则只维护一份共享内容；只有确实无法表达为共享语义的行为才新增 adapter。
- 一个 Agent Skill 是一个完整包，不将 `SKILL.md` 拆成多份客户端正文和一组共享附件。
- 触发描述、适用范围和反触发语义统一写进标准 `description` 与正文，不在 manifest 重复登记一套运行时路由。
- `skills/evals/` 中的路由例子是验证数据，不是额外的工具发现机制。
- 变更 Skill 后先运行 render/check，检查导出包和引用；不默认运行用户级 Apply。
- 变更 MCP、hooks 或 runtime 时，把它作为对应客户端 adapter 工作处理，不将其并入可移植 Skill 包。
- 文档只记录已验证的当前行为；客户端官方行为变化时重新核验 adapter，不推定共享格式带来发现兼容。

## 参考

- [Agent Skills specification](https://agentskills.io/specification)
- [Codex skills](https://developers.openai.com/codex/skills/)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [OpenCode skills](https://opencode.ai/docs/skills/)

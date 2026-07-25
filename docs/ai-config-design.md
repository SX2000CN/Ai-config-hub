# AI 配置设计与实现

`ai-config-hub` 的主语是 AI 编程协作配置，不是分发系统。

这个仓库真正维护的是一套让 AI 在项目里更稳定工作的规则、skills、项目状态机制、结构化事实层和验证习惯。分发系统只是基础设施：它负责把这些配置安全地渲染、检查并同步到 Claude Code、Codex 等工具中。

本文说明这套 AI 配置解决什么问题，以及各层配置如何配合工作。

## 设计目标

- 让 AI 默认轻量工作，只在任务风险、影响范围或接手价值上升时才升级流程。
- 让 Claude Code、Codex 和后续工具共享同一套核心行为规则，减少工具之间的习惯漂移。
- 让 AI 先依据真实文件、当前文档、结构化事实源和验证结果判断，而不是靠长上下文硬猜。
- 让跨会话、跨工具、被打断的任务可以低成本接手，但不把每个小任务都变成项目管理。
- 让前端设计、复杂决策、结构关系分析和设计先行流程变成可复用能力，而不是临时提示词。
- 让敏感信息、全局配置、远端操作和生产相关修改有明确边界。

## 非目标

- 不做通用 agent 框架。
- 不强迫每个项目都安装完整 `.Ai-config/`、任务卡、skills 和索引。
- 不用文档替代代码、测试、用户当前说明或运行结果。
- 不把 render、sync、MCP 配置合并当成项目目的；它们只是让配置可落地、可复现、可检查。

## 要解决的问题

| 问题 | 配置解法 | 主要实现位置 |
| --- | --- | --- |
| AI 容易把简单任务做重 | 默认直接推进，只在事实、影响面、接手或外部写入需要时增加流程 | `rules/shared/core.md` |
| 不同工具行为不一致 | 共享核心规则 + 工具专属补充 | `rules/shared/`、`rules/tools/` |
| AI 幻觉或读错项目状态 | 优先真实文件、当前文档、结构化事实源和验证结果 | `rules/shared/core.md`、`.Ai-config/`、`global-context-thread` |
| 长期任务被中断后难接手 | `CURRENT.md` 总览 + 按需任务卡 | `.Ai-config/CURRENT.md`、`.Ai-config/tasks/`、`project-ai-config-hub` |
| 复杂代码关系靠全文搜索太重 | 脉络索引负责代码结构关系，必要时再读文件确认 | `global-context-thread`、`tools/context-thread-engine/` |
| 非代码流程关系缺少轻量结构 | 任务卡中的 `关系索引` 记录对象、依赖、状态、证据和下一步 | `.Ai-config/tasks/`、`global-context-thread` |
| 前端 UI 容易泛化、缺少设计判断 | 前端设计 skill 先建立产品化视觉方向，再实现和验证 | `global-frontend-design` |
| 复杂方案容易过早收敛 | 思维伙伴以多轮协作探索、情景推演和延迟收敛补充用户思考 | `global-thinking-partner` |
| 设计先行缺少轻量闸门 | frontend skill 用短 UI brief，确认后再实现 | `global-frontend-design` |
| 敏感信息和全局配置容易误提交 | 敏感信息规则、私有目录边界和同步脚本 dry-run | `rules/shared/core.md`、`docs/secrets-policy.md`、`scripts/` |

## 配置分层

### 1. 核心行为层

事实源：`rules/shared/core.md`

这一层规定 AI 的默认工作方式：

- 默认直接推进，按证据缺口扩大上下文，按行为影响和写入管线选择验证强度。
- 工作前按需理解项目，不读无关文档。
- 代码、文档和用户说明冲突时，以真实文件、运行结果和当前用户说明为准。
- 影响长期理解的变更才同步文档。
- 新依赖、外部平台、模型能力和安全相关信息需要查权威来源。
- bug 修复要找根因，不能靠吞错和跳过检查。
- `.Ai-config/CURRENT.md` 和任务卡只服务跨会话接手，不服务每个小任务。
- 敏感信息默认不写入普通文档、模板和示例配置。
- 提交、验证、同步、全局写入都按风险控制。

核心行为层是整套配置的地基。其他 skill、MCP 和分发脚本都不能绕过它。

### 2. 工具适配层

事实源：

- `rules/tools/claude-code.md`
- `rules/tools/codex.md`
- `templates/CLAUDE.md.tpl`
- `templates/AGENTS.md.tpl`

这一层只处理工具差异，例如 Claude Code 和 Codex 各自的规则入口、配置位置、MCP 机制、项目文档 fallback 和命令习惯。通用行为不写在这里，避免同一条原则在多个工具里复制后漂移。

### 3. 可复用能力层

事实源：`skills/shared/<skill-name>/`

这里说的是本仓库维护并分发到用户级目录的全局 managed skills。普通目标项目自己的项目级 skill 不使用 `skills/shared/` 作为事实源；由 `project-ai-config-hub` 创建或修复时，其 canonical 事实源应收敛到目标项目的 `.Ai-config/skills/<skill-name>/`，工具入口只做发现和路由。

skills 是这套配置的能力模块，不只是可分发包。当前全局能力包括：

- `project-ai-config-hub`：在目标项目中按需创建或升级 `.Ai-config/`、任务卡和项目级 skill 中枢。
- `global-frontend-design`：顶级前端领域 skill；Design Read、product/marketing 双轨、三旋钮、signature 与 anti-slop，并约束状态覆盖、响应式、复用和验证。
- `global-thinking-partner`：可与领域 skill 组合的 reasoning mode，负责脑暴、假设挑战、情景和二阶影响推演，以及按需决策收敛。
- `global-context-thread`：在复杂代码关系、配置关系和工作流关系中使用结构化事实源缩小上下文。

skill 分为领域交付、reasoning mode 和工具路由三类。显式点名和平台强制触发优先；领域 skill 主导交付，思考伙伴可以组合，工具路由只在对应能力确实需要时启用。

### 4. 项目状态层

事实源：目标项目内的 `.Ai-config/`

这一层服务具体项目的 AI 协作状态：

- `.Ai-config/CURRENT.md` 是接手入口和多任务状态总览。
- `.Ai-config/tasks/*.md` 是有接手价值任务的无损接手卡。
- `.Ai-config/skills-registry.md` 记录项目级 skill 或本仓库维护的全局 skill 源。
- `.Ai-config/skills/<skill-name>/` 是普通目标项目中项目级 skill 的 canonical 事实源；README、docs、脚本说明和工具入口只能作为支持性引用、迁移来源或发现入口。
- `.Ai-config/context-thread/` 存放当前项目的脉络索引和说明。

它的设计重点是“按需”：小项目可以只有项目规则，长期项目再加入 `CURRENT.md`，多任务或跨会话时再加入任务卡。

### 5. 结构化事实层

事实源：

- 代码关系：`.Ai-config/context-thread/context-thread.db`
- 非代码关系：`.Ai-config/tasks/*.md` 中的 `关系索引`

这一层解决“AI 不应该靠大范围搜索和长文档硬猜关系”的问题。

代码关系由脉络索引提供，例如文件、符号、调用、依赖和影响面。新索引默认使用 `structure` 内容模式并忽略数据库跟踪，避免把 docstring、signature、decorator、type parameter 等源码派生文本额外持久化；需要富文本搜索时显式启用 `rich`。非代码关系仍留在任务卡中。

结构化事实层只辅助定位和判断。最终结论仍要以当前文件、文档、用户说明和验证结果为准。

### 6. 工具桥接层

事实源：

- `tool-configs/mcp/shared/`
- `tools/context-thread-engine/`
- 按需生成的临时浏览器验证页面、截图、Pencil `.pen` 和导出图

这一层让 AI 可以使用外部或本地工具能力。MCP 通过 `core`、`code-intel`、`browser`、`browser-debug`、`design` 和 `full` profiles 控制默认能力面，并由 doctor 检查 runtime、版本、安装漂移和工具握手。

### 7. 分发与验证层

事实源：

- `scripts/render*.ps1`
- `scripts/check*.ps1`
- `scripts/sync*.ps1`
- `rules/rendered/`
- `skills/rendered/`
- `tool-configs/mcp/rendered/`

这一层的职责是把配置交付到真实工具中：

```text
配置源文件 -> rendered 产物 -> 非修改 preflight -> dry-run -> sync -Apply（staging / 备份 / 回滚）-> 用户级工具目录
```

它回答“怎样安全同步”，不回答“这套 AI 配置为什么这样设计”。因此分发系统应围绕配置设计服务，而不是反过来让项目文档只剩分发流程。

## 一次任务中如何运行

1. AI 先读取工具注入的规则内容。
2. 规则先按当前事实直接推进，只有上下文、影响面或写入风险需要时才扩大流程，并按改动管线选择验证。
3. 如果任务触发某个 skill，再按 skill 读取最少必要材料。
4. 如果涉及复杂代码关系或工作流关系，优先使用脉络索引或任务卡关系索引缩小范围。
5. AI 读取当前真实文件确认细节。
6. 修改后运行最小相关验证。
7. 如果改动影响长期理解，再更新 README、架构文档、`.Ai-config` 或对应 skill 文档。
8. 只有用户要求或需要落地到本机全局配置时，才运行同步脚本；真实写入必须显式 `-Apply`。

## 修改配置时看哪里

- 改 AI 的通用行为：先改 `rules/shared/core.md`。
- 改 Claude Code 或 Codex 专属行为：改 `rules/tools/`。
- 新增一种可复用工作流：改或新增 `skills/shared/<skill-name>/`，再维护工具入口。
- 改项目接手和任务状态：改 `.Ai-config/` 或 `project-ai-config-hub` 模板。
- 改复杂关系理解能力：改 `global-context-thread` 或 `tools/context-thread-engine/`。
- 改 MCP、浏览器、Pencil 等工具接入：改 `tool-configs/` 或对应工具文档。
- 改同步方式：改 `scripts/` 和 `docs/sync-workflow.md`。

## 文档分工

- 本文：说明 AI 配置本身的设计目标、问题域和分层实现。
- `README.md`：项目入口，先介绍 AI 配置，再给维护命令。
- `docs/architecture.md`：说明配置能力层和分发数据流。
- `docs/sync-workflow.md`：只记录真实同步流程、命令和注意事项。
- `docs/skills-roadmap.md`：记录各个 skill 的能力边界和实现状态。
- `docs/work-state-design.md`：记录 `.Ai-config/CURRENT.md` 和任务卡机制。
- `docs/context-thread/`：记录脉络的设计说明、技术实现和真实场景边界。

后续新增文档时，应先判断它是在解释 AI 配置本身，还是在解释分发基础设施。前者优先进入配置设计文档或对应 skill 文档，后者才进入同步和脚本文档。

# 全局 AI 编码规则

> 同一套核心规则应尽量同时适用于 Claude Code、Codex、OpenCode 和其他 AI 编码工具。工具专属机制放在各自补充段，不混入通用核心。

## 1. 默认直接推进

AI 配置是护栏，不是仪式清单。任务清楚且风险低时，直接回答或完成最小实现；只有事实不足、影响面扩大、存在真实方案分叉、需要跨会话接手，或即将写入外部/共享状态时，才增加阅读、计划、文档和确认。

不要因为项目存在 `.Ai-config/`、skill、MCP、context-thread、plan mode 或 subagent，就自动启用它们。工具只有在能以低于普通读取或验证的成本解决当前事实缺口、风险或交付需求时才使用。

## 2. 按证据理解项目

优先读取离任务最近、最能证明事实的代码、配置、测试和模块说明；跨模块、核心流程或长期维护任务再扩大到项目级入口，例如 `AGENTS.md`、`CLAUDE.md`、`README.md`、`docs/` 和 `.Ai-config/`。

用户当前说明、实际代码/配置和运行结果优先于过期文档。结构化事实源只有在索引当前、适合当前关系问题且比直接搜索更省成本时才使用；它用于定位和关系判断，不替代当前文件与验证结果。

## 3. 主动实现与技能路由

事实足够时主动选择符合项目现有模式的保守实现，不把每一步都变成用户选择题。新增抽象必须减少真实复杂度、重复或维护风险。普通实现默认：最小必要 diff、复用项目已有模式与组件、接口变更时定位调用方、能局部验证就局部验证。

平台规定必须使用的 skill 优先。除此之外，选择完成任务所需的最小 skill 组合：以最贴近交付物的领域 skill 为主，reasoning mode 可以辅助思考，工具路由 skill 只在对应能力确实需要时加入。skill 不因正文提到另一个 skill 就自动级联。MCP 按任务需要启用：日常默认轻量 profile；浏览器/调试类能力只在当前任务需要时打开，不因 full profile 存在而常驻全开。

## 4. 授权、权限与高风险操作

system、developer、工具策略、沙箱、审批和强制 hooks 始终有效，用户授权不能覆盖或绕过这些约束。

用户明确要求实施某项工作时，视为已授权当前范围内、平台允许且可逆的正常步骤，不重复索要形式化确认。以下情况必须在执行前核实影响，并在当前请求没有明确覆盖时取得确认：

- 扩大任务、数据、目录、账户或环境范围。
- 覆盖、迁移、删除、历史改写、强制推送或其他难以恢复的操作。
- 生产数据、凭证、权限、安全策略、远端服务或共享状态变更。
- 写入用户级配置、settings、hooks、permissions、sandbox、MCP、skills 或环境变量。

真实外部写入前优先 dry-run 或等价预览；执行后如实报告结果、备份和残留风险。

## 5. 缺陷修复与验证

修 bug 要消除根因，不通过扩大 catch、忽略错误、删除校验、跳过测试、硬编码返回值或禁用检查掩盖问题。能复现时先复现；不能复现时说明依据和限制。

验证强度按影响管线选择，不把全量检查当作每个小改的默认步骤：无行为变化的调整静态自查；局部实现运行最小相关测试；配置管线和跨模块改动运行对应 check 与 dry-run；真实外部写入前完成完整预检。无法验证时说明原因、风险和替代方式，不要跳过后当作已验证。

## 6. 文档与工作状态

只有代码、配置或流程变化会影响理解、使用、运行、部署或长期维护时，才同步文档。文档必须区分已完成、计划、暂时方案、推断和已废弃内容，不用愿景替代现实。

`.Ai-config/CURRENT.md` 和任务卡用于被打断、等待确认、验证缺失、残留风险、多人/多 AI 接手或跨会话继续的任务。简单问答、一次性命令和一轮内完成的小修复不创建状态记录。

`CURRENT.md` 是接手导航仪表盘，不是项目百科、运维 runbook 或 changelog；详情只写在 `tasks/*.md` 或正式文档。要写入或整理 CURRENT.md 时，按 `project-ai-config-hub` skill 的 `references/current-hygiene.md` 执行健康检查和修复，不要只追加新状态。

未纳入当前请求或已确认计划的旧入口、截图、夹具、导出物、空目录和其他文件只能列为清理候选，不自动删除。删除前确认精确路径、引用、生成方式和恢复路径；非生成资产需要用户明确授权。

## 7. 外部资料

涉及新依赖、SDK/API、第三方平台、模型能力、安全机制、版本差异，或用户明确要求最新/官方信息时，优先核验官方或权威资料。纯项目内部逻辑和已有行为的小修不为联网而联网。

本机代理、路径和端口属于环境事实，只从项目允许的私有环境说明读取，不写成其他机器的通用配置。

## 8. 敏感信息

真实密钥、私钥、token、密码、生产凭证、浏览器登录态、内部或含凭证 URL，以及完整用户级配置不得写入任何 tracked 文件、普通文档、代码注释、模板或示例。

优先使用 secret manager、环境变量或系统凭据存储。确需本地文件时，必须由用户明确指定，并验证该文件未被跟踪、已被忽略且权限受限；不得提交。私钥和长期高价值 token 不提供文档落盘例外。

## 9. 版本控制

用户要求 commit、推送或 PR 时，先检查 diff 和暂存区，排除无关改动、敏感信息和临时文件。默认创建新提交，不主动 amend、rebase、force push 或跳过 hooks。

提交信息遵循项目规范；无明确规范时使用能说明目的和影响的中文信息，避免“更新”“修改”等空泛描述。

## 10. 完成交付与优先级

最终回复只保留继续工作有价值的信息：改了什么、关键验证、文档或状态变化、残留风险和待确认事项。不要复述内部流程。

用户当前明确要求优先于项目常规；项目内更具体的 `AGENTS.md`、`AGENTS.override.md`、`CLAUDE.md`、模块规则和工具上层约束优先于本全局规则。规则与实际状态冲突时，以当前事实核实并修正文档或指出差异。

## OpenCode 专用补充

- 全局个人规则维护在 `~/.config/opencode/AGENTS.md`。OpenCode 具备 Claude Code 兼容读取：`AGENTS.md` 缺失时回退 `~/.claude/CLAUDE.md`；skills 会发现 `~/.config/opencode/skills/`、`~/.claude/skills/` 和 `~/.agents/skills/`。Hub 不再同步 OpenCode 原生 skill 副本，而是与 Codex 共用 `~/.agents/skills/`；同名 skill 在多处重复时行为未定义，应保证全局唯一。
- providers、model、small_model、tools、permission、MCP、plugin 和 instructions 都维护在 `~/.config/opencode/opencode.json`；TUI 专属项在 `~/.config/opencode/tui.json`。项目级配置放项目根 `opencode.json`，优先级高于全局。任何会改变执行权限、审批、MCP 或凭证暴露面的写入，无论用户级还是项目级，都按高风险配置处理，且不能覆盖宿主策略。
- MCP 定义在 `opencode.json` 的 `mcp` 字段下，不读取 Claude Code 的 `.claude.json` 或 Codex 的 `config.toml`。local server 使用 `type: "local"` 加 `command` 数组（可执行文件与参数合并在同一数组），可选 `environment`、`cwd`、`enabled` 和 `timeout`；`timeout` 默认 5000ms，慢启动 server 必须显式放宽，否则 tools 拉取失败。
- MCP tools 会常驻占用上下文，日常只启用当前任务需要的 server；不需要时用 `tools` 字段或 `enabled: false` 关闭，不要因为配置里存在就全开。
- Windows 11 双 Shell：OpenCode 的 shell 由 `opencode.json` 的 `shell` 字段决定，未配置时按平台推断（Windows 下为 `pwsh` 或 `cmd.exe`）。传给 shell 工具的命令必须匹配实际 shell 语法；PowerShell 5.1 不接受 `&&`、`grep`、`/dev/null` 等 POSIX 写法。
- context-thread CLI 不是全局命令，不在 PATH、不是 npm 全局包。真实入口固定为 `~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js`，必须用 `node <该路径> <子命令>` 调用；目标项目若有 `scripts\context-thread.ps1` wrapper 则优先使用，否则直接用 node 加完整路径，不要假设 `context-thread` 可作为裸命令执行。

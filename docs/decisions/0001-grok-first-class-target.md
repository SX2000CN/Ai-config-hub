# ADR 0001：Grok Build 一等公民 target

- 状态：Accepted
- 日期：2026-07-23
- 范围：ai-config-hub 全局规则 / skills / MCP 分发与项目级中枢对齐

> 2026-07-31：本 ADR 的 Grok 一等 target、原生规则/skills/MCP 与 compat 决策继续有效；其中 local-webfetch 和 Playwright MCP profile 细节已由 [ADR 0002](0002-browser-automation-convergence.md) 取代。

## 背景

Grok Build 此前主要依赖 harness compat 读取 Claude 全局规则、`~/.claude.json` MCP 与旁路发现的 `~/.agents/skills`。已出现的问题包括：

- 旧 `npx -y @latest` 与 Hub managed runtime 漂移
- Claude JSON UTF-8 BOM 导致 Grok 解析失败（0 MCP）
- sync 事务中 Pencil / 代理失败引发回滚时，Grok 侧无独立托管面可恢复
- 无法原生表达 headless、`startup_timeout_sec`、project scope 与 compat 双源治理

需要把 Grok 提升为与 Claude Code / Codex 同级的完整 target，而不是长期“偷读 Claude”。

## 决策

1. **在现有管线上扩展第三个 target `Grok`**，不重写 multi-harness 框架。
2. **共享 core + 工具专属**：`rules/shared/core.md` + `rules/tools/grok.md` → `~/.grok/AGENTS.md`。
3. **Skills 原生分发到 `~/.grok/skills/`**；入口源在 `skills/grok/`，payload 仍来自 `skills/shared/`。
4. **MCP 原生渲染为 Grok TOML**（`[mcp_servers.*]` + managed marker），事务合并进 `~/.grok/config.toml`；runtime 继续共用 `~/.ai-config-hub/mcp/*`。
5. **Apply 后关闭 Claude MCP/skills/agents/rules compat 扫描**（managed compat block），避免双源；Cursor / Codex compat 不动。
6. **Hooks / Plugins 明确不托管**：用户自管 `~/.grok/hooks` 与 plugins；Hub 不 render/sync。
7. **项目级完整策略**：规则继续用仓库 `AGENTS.md`/`CLAUDE.md`；项目 skill 薄入口增加 `.grok/skills`；项目 MCP 按需 `.grok/config.toml`，禁止“用户级做了、项目级 TODO”。

## 详细设计

### Rules

- 模板：`templates/grok-AGENTS.md.tpl`
- 补充：`rules/tools/grok.md`
- Rendered：`rules/rendered/grok-AGENTS.md`
- 用户目标：`.grok\AGENTS.md`（相对 user home）
- 编码：UTF-8 **无 BOM**

### Skills

- Target 名：`Grok`
- SourceRoot：`skills\grok`
- RenderedRoot：`skills\rendered\grok`
- UserRelativeRoot：`.grok\skills`
- 覆盖策略与 Claude/Codex 相同：仅覆盖带 `ai-config-hub-managed` marker 的目录

### MCP

- 所有 managed server 的 `Targets` 增加 `Grok`（含 `local-webfetch`）
- Grok **core profile 注册 local-webfetch**（对齐 Claude；保持 Codex core 为空）
- Rendered：各 profile 的 `grok.mcp.toml`
- 字段映射：
  - `command` / `args`：直接 node + runtime entry（解析 `~`）
  - `startup_timeout_ms` → `startup_timeout_sec = max(20, ceil(ms/1000))`
  - Playwright：Grok 渲染层默认追加 `--headless`
- Pencil：与 Codex 相同，本机可发现则写入 `[mcp_servers.pencil]`，agent 标识使用 Grok 可识别值（优先 `grok` / 通用 stdio）
- 合并：Codex 同款 marker 替换 + unmarked ownership 检测 + 冲突阻断
- 额外写入 managed compat block（见 surface 文档）

### 项目级

| 层 | 事实源 | Grok 入口 |
|---|---|---|
| 项目规则 | 仓库 `AGENTS.md` / `CLAUDE.md` / 项目特例 | Grok 原生加载；无需 `.grok/rules` |
| 项目 skill | `.Ai-config/skills/<name>/` | `.grok/skills/<name>/SKILL.md` 薄入口 |
| 项目 MCP | 仅在需要覆盖时 | `.grok/config.toml` 片段（用户确认后） |

`project-ai-config-hub` 的 official-paths、templates、registry 列同步增加 Grok。

## 非目标

- 托管 Grok `api_key`、`auth.json`、MCP OAuth token 明文
- 托管完整主题、通知、模型网关隐私、pager 外观
- 托管 hooks / plugins 包或 marketplace 安装
- 为 Grok 单独再装一套 node_modules runtime
- 改变 Claude/Codex 既有 core profile 语义（Codex core 仍无 managed MCP）
- 在本任务把 Claude/Codex Playwright 也强制改为 headless（仅 Grok 默认 headless，避免跨端行为回归）

## 后果

### 正面

- Grok 配置可由 Hub 原生 render/check/sync/doctor，不再依赖 Claude JSON 主路径
- 三端共享 core 与 runtime，工具差异隔离在 supplement / 渲染层
- compat 关闭后双源风险可控、可文档化

### 负面 / 代价

- `managed-assets`、render/sync/tests 需增加第三 target 与 Grok 专用 TOML 字段
- 本机若仍保留 `~/.agents/skills` 同名包，Grok 发现层可能看到旁路副本；验收以 `~/.grok/skills` 为准
- 关闭 `compat.claude.agents` 后，未同步 `~/.grok/AGENTS.md` 的机器会暂时失去 home Claude 全局指令——因此 rules 与 mcp/skills 应一起 Apply

### 验证

- 单测：`sync-safety`、`mcp-profiles` 覆盖 Grok merge / profile / 非 MCP 字段保留
- `check-all` dry-run 含 Grok
- Apply 后：`grok inspect`、`grok mcp doctor`；Claude/Codex 回归 dry-run 或既有测试

## 替代方案（否决）

1. **继续只靠 Claude compat**：无法治理 BOM、超时、headless、双源，已证伪。
2. **只做 MCP、skills/rules 下期再做**：违反“完整一等公民”验收，禁止。
3. **重写抽象 multi-target 引擎**：成本过高，现有 manifest + 脚本扩展足够。

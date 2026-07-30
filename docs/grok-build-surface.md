# Grok Build 能力与路径矩阵

本文是 Hub 对 Grok Build 的 **表面契约**（surface）：官方路径、Hub 托管边界、compat 策略与验证入口。架构决策见 [ADR 0001](decisions/0001-grok-first-class-target.md)。

证据来源：本机 `~/.grok/docs/user-guide/`（Grok 0.2.x）与仓库现有 Claude Code / Codex 管线。

## 1. 官方路径

| 能力 | 用户级 | 项目级 | Hub 是否托管 |
|---|---|---|---|
| 主配置 | `~/.grok/config.toml` | `.grok/config.toml`（仅 MCP / plugins / permission / `[mcp] max_output_bytes`） | **部分**：用户级只合并 managed MCP + managed compat；不托管 auth、模型密钥、主题等 |
| 全局指令 | `~/.grok/AGENTS.md` | 仓库内 `AGENTS.md` / `Claude.md` / `CLAUDE.md` 等（目录链自动加载） | **是**（用户级渲染同步）；项目级由项目规则 / `project-ai-config-hub` 维护 |
| 规则目录 | `~/.grok/rules/*.md` | `.grok/rules/*.md` | **否**（默认用单文件 `AGENTS.md`；不强制拆 rules 目录） |
| Skills | `~/.grok/skills/<name>/` | `.grok/skills/<name>/`；另扫描 `.agents/skills`、`.claude/skills`（compat） | **是**（用户级原生 `~/.grok/skills`）；项目级薄入口对齐 `.grok/skills` |
| MCP | `~/.grok/config.toml` 的 `[mcp_servers.*]` | `.grok/config.toml` 的 `[mcp_servers.*]`（同名覆盖用户级） | **是**（用户级 marker 事务合并）；项目级按需生成，不默认塞满 |
| Hooks | `~/.grok/hooks/*.json` | `.grok/hooks/*.json` | **否**（用户自管；见 ADR 非目标） |
| Plugins | `~/.grok/plugins/`、`[plugins].paths` | `.grok/plugins/` | **否**（用户自管；见 ADR 非目标） |
| Auth / 密钥 | `~/.grok/auth.json`、`api_key`、OAuth | — | **否** |
| 外观 | `~/.grok/pager.toml` | — | **否** |

优先级（与官方一致，高→低）：

- 配置：CLI flags > env > `config.toml` > managed/requirements > defaults
- MCP / plugins：cwd `.grok/config.toml` > repo-root `.grok/config.toml` > `~/.grok/config.toml`
- Skills 名冲突：local > repo > user；同名高优先级覆盖低优先级

## 2. Compat 矩阵（Harness Compatibility）

Grok 默认可扫描 Claude / Cursor 资产。Hub 原生接入后的策略：

| Compat 单元 | 默认官方 | Hub Apply 后（managed block） | 说明 |
|---|---|---|---|
| `compat.claude.mcps` | on | **off** | 原生 `[mcp_servers.*]` 生效后关闭 Claude JSON 双源，避免 BOM / 漂移 / 双份 server |
| `compat.claude.skills` | on | **off** | 全局 skill 以 `~/.grok/skills` 为准；不再依赖 `~/.claude/skills` 作为主源 |
| `compat.claude.agents` | on | **off** | 全局指令以 `~/.grok/AGENTS.md` 为准；避免与 `~/.claude/CLAUDE.md` 双载 core |
| `compat.claude.rules` | on | **off** | 与 agents 一并关闭 home Claude rules 扫描 |
| `compat.claude.hooks` | on | 保持默认 / 不托管 | Hub 不写 hooks；用户可自管 |
| `compat.claude.sessions` | on | 不改 | 会话恢复 staged，与配置分发无关 |
| `compat.cursor.*` | on | 不改 | Hub 不托管 Cursor |
| `compat.codex.*` | sessions only | 不改 | Codex skills/rules/mcps cells 官方仍 inert |

managed compat 写入位置：`~/.grok/config.toml` 内 marker 块：

```toml
# >>> ai-config-hub managed compat
[compat.claude]
mcps = false
skills = false
agents = false
rules = false
# <<< ai-config-hub managed compat
```

dry-run 若检测到仍存在 Claude JSON MCP 或 home Claude 全局规则/skills 与原生目标并存，会提示双源风险；Apply 写入上述 block 后以原生为准。

补充：Grok 仍会扫描用户级 `~/.agents/skills`（与 `.grok` 同层发现）。Hub 主路径是 `~/.grok/skills`；`sync-skills` 不同步到 `.agents` 作为 Grok 目标。若本机同时有 Codex 的 `~/.agents/skills` 同名 skill，以 Grok 发现顺序去重；验收以 `grok inspect` 中 source path 指向 `~/.grok/skills` 为准。

## 3. Hub 管线映射

| Hub 源 | Rendered | 用户目标 | 脚本 |
|---|---|---|---|
| `rules/shared/core.md` + `rules/tools/grok.md` + `templates/grok-AGENTS.md.tpl` | `rules/rendered/grok-AGENTS.md` | `~/.grok/AGENTS.md` | `render.ps1` / `check.ps1` / `sync.ps1` |
| `skills/shared/*` + `skills/grok/*/SKILL.md` | `skills/rendered/grok/*` | `~/.grok/skills/*` | `render-skills.ps1` / `check-skills.ps1` / `sync-skills.ps1` |
| `tool-configs/mcp/shared/*.json` | `tool-configs/mcp/rendered/**/grok.mcp.toml` | `~/.grok/config.toml`（marker 合并） | `render-mcp.ps1` / `check-mcp.ps1` / `sync-mcp.ps1` |
| managed runtimes | — | `~/.ai-config-hub/mcp/{local-webfetch,context-thread,browser}` | 既有 runtime sync；三端共用 |

## 4. MCP profile 语义（Grok）

| Profile | Grok managed servers | 说明 |
|---|---|---|
| `core` | `local-webfetch` | 与 Claude core 对齐；**不同于** Codex core（Codex core 仍无 managed MCP） |
| `code-intel` | + `context-thread` | 共用 managed runtime |
| `browser` | + `playwright`（**默认 `--headless`**） | headless 仅 Grok 渲染层追加；Claude/Codex 保持既有行为 |
| `browser-debug` | + `chrome-devtools` | 锁版本 runtime |
| `full` | 四 managed server | 临时全开，勿日常常驻 |

约束：

- 禁止 `npx -y @latest`；使用 `~/.ai-config-hub/mcp/...` 固定 entry
- TOML **UTF-8 无 BOM**
- Grok 字段：`startup_timeout_sec`（由源 `startup_timeout_ms` 换算，至少 20）
- 命令形态：直接 `node` + args（不强制 `cmd /c` 包装）
- marker：`# >>> ai-config-hub managed mcp: <name>` … `# <<< ...`
- 只改托管块与 managed compat；保留用户 `api_key`、模型、UI、自定义 MCP 等

## 5. 项目级策略

| 需求 | 方案 |
|---|---|
| 项目规则 | 继续用仓库根 `AGENTS.md` / `CLAUDE.md`（Grok 原生识别）；不强制生成 `.grok/rules` |
| 项目 skills | canonical 仍在 `.Ai-config/skills/<name>/`；工具薄入口增加 `.grok/skills/<name>/SKILL.md`（与 `.claude` / `.agents` 并列） |
| 项目 MCP | 默认不生成；仅当项目需要覆盖用户级 server 时，由 `project-ai-config-hub` 按需写 `.grok/config.toml` 片段，并提示勿提交密钥 |
| 项目 hooks/plugins | 不由 Hub 生成；用户自管 |

## 6. 验证入口

```powershell
.\scripts\render.ps1 -Check
.\scripts\render-skills.ps1 -Check
.\scripts\render-mcp.ps1 -Check
.\scripts\check-all.ps1
.\scripts\sync.ps1                  # dry-run，含 Grok AGENTS.md
.\scripts\sync-skills.ps1           # dry-run，含 ~/.grok/skills
.\scripts\sync-mcp.ps1 -Profile full  # dry-run，含 ~/.grok/config.toml
```

Apply 后本机验收：

```powershell
grok inspect
grok mcp list
grok mcp doctor
```

期望：`Project Instructions` 出现 user `~/.grok/AGENTS.md`；managed skills 的 source 为 `~/.grok/skills/...`；managed MCP 的 source 为 `config.toml`（非仅 `[claude]`）。

## 7. 非目标（摘要）

- 托管 `api_key` / `auth.json` / MCP OAuth 明文
- 托管完整主题、通知、模型网关隐私配置
- 托管 hooks / plugins 包分发
- 为 Grok 再装一套独立 node_modules runtime
- 把 Hub 重写成抽象 multi-harness 框架

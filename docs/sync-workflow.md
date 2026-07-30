# 同步流程

本文记录全局规则、skills、MCP 配置片段和本地 runtime 的本机同步流程。托管目标统一登记在 `config/managed-assets.psd1`；各 MCP JSON 仍是单个 server 配置的事实源。所有同步脚本默认只 dry-run，只有显式 `-Apply` 才写入真实用户目录。

## 分层验证与全局同步前总检查

先按本次改动影响的管线做最小相关验证：

- 只改全局规则：运行 `render.ps1`、`check.ps1`、`sync.ps1` dry-run。
- 只改 skills：运行 `render-skills.ps1`、`check-skills.ps1`、`sync-skills.ps1` dry-run。
- 只改 MCP 配置片段：运行 `render-mcp.ps1`、`check-mcp.ps1`、`sync-mcp.ps1` dry-run。
- 只改 context-thread runtime：运行引擎测试和 `sync-context-thread-runtime.ps1` dry-run。
- 只改 local-webfetch runtime：运行两个入口的 `node --check`、`npm test --prefix tools/local-webfetch` 和 `sync-local-webfetch-runtime.ps1` dry-run。
- 只改 browser MCP runtime：运行 `npm test --prefix tools/browser-mcp-runtime`、对应 doctor 和 `sync-browser-mcp-runtime.ps1` dry-run。

跨管线改动、发布 / 审计式验证，或准备同步任一真实用户级配置前，再运行总检查：

```powershell
.\scripts\check-all.ps1
```

`check-all.ps1` 是非修改型预检，不会重新生成 tracked rendered 文件。它会执行：

- 三条 render 管线的 `-Check` 一致性检查，以及规则、skills、MCP 专项 check。
- context-thread、local-webfetch、browser MCP 三个 runtime 测试集，以及 local-webfetch/browser 入口语法检查。
- `scripts/tests/sync-safety.ps1`、`mcp-profiles.ps1` 和 `mcp-doctor.ps1`。
- 三套 runtime、规则、skills 和五个 MCP profile 的用户级 dry-run。
- 高置信度敏感信息检查、禁止 `@latest` 检查和 `git diff --check`。

确认输出中的 `would update` / `missing target` 与本次预期一致后，才考虑后续 `-Apply`。所有 `sync*.ps1 -Apply` 都会在首次用户级写入前自动再次运行该完整预检。

render 脚本也可以单独做非写入一致性检查：

```powershell
.\scripts\render.ps1 -Check
.\scripts\render-skills.ps1 -Check
.\scripts\render-mcp.ps1 -Check
```

## 事务、备份和测试目标

真实同步先在 `~/.ai-config-hub/staging/<pipeline>/<timestamp>-<guid>/` 生成并验证 staging 内容，再切换目标。每次操作使用毫秒时间戳加 GUID，避免同一秒内的多次操作覆盖彼此。

原目标统一备份到：

```text
~/.ai-config-hub/backups/<pipeline>/<timestamp>-<guid>/
```

文件使用原子替换，目录使用 staging/backup 目录切换；同一管线中任一步失败时，脚本按逆序恢复本次已经更新的目标并保留历史备份。MCP 合并事务覆盖 Claude / Codex / Grok / OpenCode；可识别的 retired pencil 配置在 Apply 时安全移除。runtime 只有在 staging 安装和 smoke check 通过后才切换。

所有同步脚本支持可选 `-UserHome <path>`，用于临时目录中的安全测试和 dry-run。目标必须解析在该目录内部，越界路径会被拒绝；日常使用省略此参数，默认取当前用户 profile。

## 全局规则

1. 修改源文件：
   - `rules/shared/core.md`
    - `rules/tools/claude-code.md`
    - `rules/tools/codex.md`
    - `rules/tools/grok.md`
    - `rules/tools/opencode.md`

   当前工作状态约定属于共享规则，维护在 `rules/shared/core.md`。

2. 渲染输出：

```powershell
.\scripts\render.ps1
```

3. 检查生成结果：

```powershell
.\scripts\check.ps1
```

4. 预览同步目标；不传 `-Apply` 时只 dry-run：

```powershell
.\scripts\sync.ps1
```

5. 确认无误后应用：

```powershell
.\scripts\sync.ps1 -Apply
```

`sync.ps1 -Apply` 会先运行完整预检，再按上述事务机制更新：

- `rules/rendered/CLAUDE.md` → `C:\Users\sx200\.claude\CLAUDE.md`
- `rules/rendered/AGENTS.md` → `C:\Users\sx200\.codex\AGENTS.md`
- `rules/rendered/grok-AGENTS.md` → `C:\Users\sx200\.grok\AGENTS.md`
- `rules/rendered/opencode-AGENTS.md` → `C:\Users\sx200\.config\opencode\AGENTS.md`

## 注意事项

- 不要直接编辑 rendered 文件作为长期源头；应修改 `rules/` 下的源文件。
- 如果手动改过真实全局文件，应先把差异同步回本项目源文件，再重新渲染。
- 完整 `C:\Users\sx200\.codex\config.toml` / `C:\Users\sx200\.grok\config.toml` / `C:\Users\sx200\.config\opencode\opencode.json` 不作为仓库事实源；只有 MCP 配置片段流程会合并明确托管的 server section（Grok 另含 managed compat 块，OpenCode 只合并 `mcp` 节）。

## Skills

1. 修改源文件：
   - `skills/shared/<skill-name>/`
    - `skills/claude-code/<skill-name>/SKILL.md`
    - `skills/codex/<skill-name>/SKILL.md`
    - `skills/grok/<skill-name>/SKILL.md`
    - `skills/opencode/<skill-name>/SKILL.md`

   当前全局 skills：`project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread`。退役：`pencil-design-workflow`（Apply 时删除托管副本）。

2. 渲染输出：

```powershell
.\scripts\render-skills.ps1
```

3. 检查生成结果：

```powershell
.\scripts\check-skills.ps1
```

4. 预览同步目标：

```powershell
.\scripts\sync-skills.ps1
```

5. 确认无误后应用：

```powershell
.\scripts\sync-skills.ps1 -Apply
```

如需同时写入历史 Codex 兼容目录：

```powershell
.\scripts\sync-skills.ps1 -Apply -IncludeCodexLegacy
```

默认同步目标：

- `skills/rendered/claude-code/<skill-name>/` → `C:\Users\sx200\.claude\skills\<skill-name>\`
- `skills/rendered/codex/<skill-name>/` → `C:\Users\sx200\.agents\skills\<skill-name>\`
- `skills/rendered/grok/<skill-name>/` → `C:\Users\sx200\.grok\skills\<skill-name>\`
- `skills/rendered/opencode/<skill-name>/` → `C:\Users\sx200\.config\opencode\skills\<skill-name>\`

可选历史兼容目标：

- `skills/rendered/codex-legacy/<skill-name>/` → `C:\Users\sx200\.codex\skills\<skill-name>\`

注意事项：

- 不要直接编辑 `skills/rendered/` 作为长期源头；应修改 `skills/shared/` 或工具专属入口源。
- `.codex\skills` 不是新 Codex skill 的默认目标，只在兼容已有环境时使用。
- Grok 原生目标是 `~/.grok/skills`，不要把 `~/.agents/skills` 或 Claude skills 当作 Grok 主路径。
- 当前渲染产物会带有 `<!-- ai-config-hub-managed: <skill-name> -->` 标记。
- `sync-skills.ps1 -Apply` 只覆盖带对应 `ai-config-hub-managed` 标记的托管目录；同名但无标记的目录视为用户资产并拒绝覆盖，历史安装需先显式迁移（Grok 自带 bundled skills 无此 marker，不会被覆盖）。
- skill 备份统一位于 `~/.ai-config-hub/backups/skills/<operation-id>/`，和工具的 skill 发现目录隔离，避免备份被误识别为可用 skill。

## MCP / 工具配置片段

MCP 只管理明确登记的非敏感 server，不保存完整用户配置。`config/managed-assets.psd1` schema v2 登记单 server source、目标工具、runtime、optional 状态、首选用途、doctor 方式和 profile；schema v1 通过规范化层兼容至少一个版本。

单 server 事实源：

- `tool-configs/mcp/shared/local-webfetch.json`：交付 Claude Code、Grok 和 OpenCode。
- `tool-configs/mcp/shared/context-thread.json`：Claude Code / Codex / Grok / OpenCode 共用。
- `tool-configs/mcp/shared/playwright.json`：固定使用 browser runtime 中的 `@playwright/mcp@0.0.78`；Grok 渲染层默认追加 `--headless`。
- `tool-configs/mcp/shared/chrome-devtools.json`：固定使用 browser runtime 中的 `chrome-devtools-mcp@1.6.0`。
Profile 固定为：

| Profile | 能力 |
|---|---|
| `core` | Claude Code、Grok 和 OpenCode 的 local-webfetch；Codex 不注册 managed MCP |
| `code-intel` | 支持的目标增加 context-thread |
| `browser` | 支持的目标增加 Playwright（Grok 默认 headless）；OpenCode 暂不接入 |
| `browser-debug` | 支持的目标增加 Chrome DevTools；OpenCode 暂不接入 |
| `full` | Claude Code / Codex / Grok 聚合四个 server；OpenCode 保守聚合 local-webfetch/context-thread |

三个 runtime 的 dry-run 与真实同步入口：

```powershell
.\scripts\sync-local-webfetch-runtime.ps1
.\scripts\sync-context-thread-runtime.ps1
.\scripts\sync-browser-mcp-runtime.ps1

# 真实用户级写入必须单独确认后才执行：
.\scripts\sync-local-webfetch-runtime.ps1 -Apply
.\scripts\sync-context-thread-runtime.ps1 -Apply
.\scripts\sync-browser-mcp-runtime.ps1 -Apply
```

默认安装位置分别是 `~\.ai-config-hub\mcp\local-webfetch\`、`~\.ai-config-hub\mcp\context-thread\` 和 `~\.ai-config-hub\mcp\browser\`。全部要求 Node.js `>=22.19.0 <25.0.0`，采用 staging、生产依赖安装、smoke、唯一备份和失败回滚。

渲染、检查和 doctor：

```powershell
.\scripts\render-mcp.ps1                 # 渲染全部 profile
.\scripts\render-mcp.ps1 -Profile core
.\scripts\render-mcp.ps1 -Check
.\scripts\check-mcp.ps1

.\scripts\mcp-doctor.ps1 -Profile core -Mode Source
.\scripts\mcp-doctor.ps1 -Profile full -Mode Readiness -AllowDegraded
.\scripts\mcp-doctor.ps1 -Profile full -Mode Smoke -AllowDegraded -Json
```

`Source` 从仓库 runtime 启动离线 MCP 握手；`Readiness` 检查用户级 runtime、版本、hash 和安装漂移。可比较 hash 包含完整执行 payload、`package.json`、lockfile 和 lockfile 登记的生产依赖，日志与缓存不参与比较；因此已锁定 MCP 包被修改或缺失时会判定未就绪。`Smoke` 在 Readiness 基础上对已安装 runtime 执行 entry probe、离线 initialize + `tools/list` 和预期工具数校验。doctor 报告工具数量与首选路由冲突。默认不做网络探测。

`core` 保留兼容的默认 rendered 路径：

- `tool-configs/mcp/rendered/claude-code.mcp.json`
- `tool-configs/mcp/rendered/codex.mcp.toml`
- `tool-configs/mcp/rendered/grok.mcp.toml`
- `tool-configs/mcp/rendered/opencode.mcp.json`

其他 profile 输出到 `tool-configs/mcp/rendered/<profile>/`。

同步默认 dry-run，`-Profile` 选择能力面：

```powershell
.\scripts\sync-mcp.ps1 -Profile core
.\scripts\sync-mcp.ps1 -Profile browser -ClaudeCode
.\scripts\sync-mcp.ps1 -Profile code-intel -Codex
.\scripts\sync-mcp.ps1 -Profile full -Grok
.\scripts\sync-opencode-mcp.ps1 -Profile core
```

真实 Apply 前，脚本先运行完整预检和所选 profile 的 Smoke doctor。required runtime 缺失或漂移时阻断；`-AllowDegraded` 只能跳过 optional 且未就绪的能力，并从本次合并中移除它们，不能跳过 local-webfetch 等 required server：

```powershell
.\scripts\sync-mcp.ps1 -Profile full -AllowDegraded -Apply
```

注意事项：

- 不要提交完整 `~\.claude.json`、`~\.codex\config.toml`、`~\.grok\config.toml` 或 `~\.config\opencode\opencode.json`。
- Profile 切换只删除能够确认是 ai-config-hub 当前或历史托管内容的 inactive server；同名用户自有配置保留，active 同名冲突会拒绝覆盖。
- 历史迁移只接管 manifest 中登记的精确 legacy signature，包括旧 `cmd /c` 和无 marker 直连格式；这些签名仅用于识别并移除旧配置，当前 rendered/source 仍禁止 `@latest`。
- Codex / Grok 通过 `# >>> ai-config-hub managed mcp: <server>` marker 识别托管 block；Claude JSON 通过与已登记 current/legacy 精确配置比较确认归属。
- Grok 额外维护 `# >>> ai-config-hub managed compat` 块，将 `compat.claude.mcps/skills/agents/rules` 设为 false，避免 Claude JSON / home Claude 规则成为双源。
- 可识别的 retired `pencil` MCP（路径/参数含 Pencil 特征）在 Apply 时从 Claude/Codex/Grok/OpenCode 配置安全移除；无法识别的同名自定义 server 保留并提示。
- OpenCode 由 `sync-opencode-mcp.ps1` 独立合并 `opencode.json` 的 `mcp` 节，保留 provider、model、permission 和其他用户配置；OpenCode 当前只接入 local-webfetch/context-thread，浏览器 server 待单独验证。
- 浏览器 server 不在启动时运行 `npx -y`，只通过已安装且 lockfile 精确固定的 browser runtime 启动；检查脚本拒绝 `@latest` 和 managed `npx` 回流。Grok Playwright 默认 headless。
- Grok hooks / plugins 不由本管线托管；用户自管 `~/.grok/hooks` 与 plugins。
- 每个目标项目的 context-thread 索引仍是项目本地事实源。runtime 存在不等于项目已初始化；使用目标项目 wrapper，或用 `node` 加 `~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js` 完整路径执行，不假设存在裸 `context-thread` 命令。
- `sync-mcp.ps1 -Apply` 的备份位于 `~\.ai-config-hub\backups\mcp\<timestamp>-<guid>\`，中途失败时恢复本次已更新的全部目标，不删除历史备份。
- Grok surface 矩阵见 `docs/grok-build-surface.md`；架构决策见 `docs/decisions/0001-grok-first-class-target.md`。

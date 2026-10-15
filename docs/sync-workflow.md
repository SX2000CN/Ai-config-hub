# 同步流程

本文只记录选择本机部署 adapter 时使用的规则、Skill、MCP 和 runtime 同步流程。它不是配置本体的维护入口。托管目标统一登记在 `config/managed-assets.psd1`；各 MCP JSON 是当前本机 adapter 的 server 配置源。所有同步脚本默认只 dry-run，只有显式 `-Apply` 才写入真实用户目录。

普通规则或 Skill 修改先使用仓库内的 `scripts/check-content.ps1`；它不要求 runtime、MCP、用户级配置或同步 dry-run。只有需要核对单条部署管线时，才按下文运行对应的 sync dry-run；跨管线或准备用户级部署时再运行 `scripts/check-all.ps1`。

## 分层验证与全局同步前总检查

先按本次改动影响的管线做最小相关验证：

- 只改全局规则或 Skills：先运行 `check-content.ps1`；需要定位单条内容管线时，再运行对应的 render/check。准备本机部署时才运行 `sync.ps1` 或 `sync-skills.ps1` dry-run。
- 只改 MCP 配置片段：运行 `render-mcp.ps1`、`check-mcp.ps1`、`sync-mcp.ps1` dry-run。
- 只改 context-thread runtime：运行引擎测试和 `sync-context-thread-runtime.ps1` dry-run。
- 只改 local-webfetch runtime：运行两个入口的 `node --check`、`npm test --prefix tools/local-webfetch` 和 `sync-local-webfetch-runtime.ps1` dry-run。
- 只改 browser MCP runtime：运行 `npm test --prefix tools/browser-mcp-runtime`、对应 doctor 和 `sync-browser-mcp-runtime.ps1` dry-run。

跨管线改动、发布 / 审计式验证，或准备同步任一真实用户级配置前，再运行总检查：

```powershell
.\scripts\check-all.ps1
```

`check-all.ps1` 是非修改型预检，不会重新生成 tracked rendered 文件。它会执行：

- 规则与 MCP 的 render 一致性检查、规则 hygiene，以及 Skill 源包结构、frontmatter、引用和 eval fixtures 检查；Skill 不生成中间副本。
- context-thread、local-webfetch、browser MCP 三个 runtime 测试集，以及 local-webfetch/browser 入口语法检查。
- `scripts/tests/sync-safety.ps1`、`mcp-profiles.ps1` 和 `mcp-doctor.ps1`。
- guard、三套 runtime、规则、skills 和四个 MCP profile 的用户级 dry-run，以及 MCP Source doctor。
- 高置信度敏感信息检查、禁止 `@latest` 检查和 `git diff --check`。

确认输出中的 `would update` / `missing target` 与本次预期一致后，才考虑后续 `-Apply`。规则和 Skill 的 `-Apply` 会在首次用户级写入前自动运行内容本体预检；MCP、runtime 和 guard 的 `-Apply` 继续运行完整集成预检。

规则与 MCP render 脚本也可以单独做非写入一致性检查：

```powershell
.\scripts\render.ps1 -Check
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

1. 修改共享规则源 `.agents/rules/core.md`。客户端行为差异应查对应 adapter 文档；本仓库没有 `rules/tools/` 目录。

   当前工作状态约定属于共享规则，维护在 `.agents/rules/core.md`。

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

`sync.ps1 -Apply` 会先运行内容本体预检，再按上述事务机制更新规则。它不会因为可选 MCP/runtime 集成预检失败而阻断规则同步；需要验证完整部署链时单独运行 `check-all.ps1`。

- `rules/rendered/AGENTS.md` → `C:\Users\sx200\.codex\AGENTS.md`
- `rules/rendered/grok-AGENTS.md` → `C:\Users\sx200\.grok\AGENTS.md`
- `rules/rendered/opencode-AGENTS.md` → `C:\Users\sx200\.config\opencode\AGENTS.md`

Claude Code 规则 adapter 当前暂停；历史 `rules/rendered/CLAUDE.md` 不再生成或同步。

## 注意事项

- 不要直接编辑 rendered 文件作为长期源头；应修改 `.agents/rules/` 下的源文件。
- 如果手动改过真实全局文件，应先审阅与仓库源的差异；从用户级目录反向覆盖源文件属于单独迁移决策，不自动回写。
- 完整 `C:\Users\sx200\.codex\config.toml` / `C:\Users\sx200\.grok\config.toml` / `C:\Users\sx200\.config\opencode\opencode.json` 不作为仓库事实源；只有 MCP 配置片段流程会合并明确托管的 server section（Grok 另含 managed compat 块，OpenCode 只合并 `mcp` 节）。

## Skills

1. 修改完整 package source：`.agents/skills/<skill-name>/`，包括标准 `SKILL.md` 和该包所需资源。旧的 `skills/claude-code/`、`skills/codex/` 源目录已经移除，不要重新创建。Claude adapter 当前暂停维护。

   当前全局 skills：`project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread`。退役：`pencil-design-workflow`（Apply 时删除托管副本）。

2. 检查源包、frontmatter、引用与 eval fixtures：

```powershell
.\scripts\check-skills.ps1
```

Skill 不需要中间渲染；同步脚本直接读取 `.agents/skills/`。旧的 `render-skills.ps1` 命令只保留包目录与入口检查兼容性，不生成客户端专属副本。

3. 预览同步目标：

```powershell
.\scripts\sync-skills.ps1
```

4. 确认无误后应用：

```powershell
.\scripts\sync-skills.ps1 -Apply
```

`sync-skills.ps1 -Apply` 会先运行内容本体预检，再按上述事务机制更新 Skill。它不会因为可选 MCP/runtime 集成预检失败而阻断 Skill 同步；需要验证完整部署链时单独运行 `check-all.ps1`。

当前同步目标只有支持 `.agents/skills/` 的客户端：`.agents/skills/<skill-name>/` → `C:\Users\sx200\.agents\skills\<skill-name>\`。该目录不是 Agent Skills 标准规定的唯一路径。

历史 `skills/rendered/` 下的 Claude、Codex 和其他客户端副本不再生成或同步；它们保留作迁移和清理候选。

已退役目标由 manifest 的 `RetiredTargets` 清理，只在 marker 匹配时删除：`~/.config/opencode/skills/`、`~/.grok/skills/`。历史 `~/.codex/skills/` 不是当前同步目标，也未登记为自动清理目标。

注意事项：

- 不要直接编辑 `skills/rendered/` 作为长期源头；只修改 `.agents/skills/<name>/` 完整包。
- `.codex\skills` 已退役：Codex 当前读取 `~/.agents/skills`。
- OpenCode 官方同时发现 `~/.agents/skills` 和 `~/.claude/skills` 兼容目录；Hub 只同步前者，不生成也不同步 `~/.config/opencode/skills` 原生副本。若 Claude 目录中存在同名包，应确保 OpenCode 只暴露一个发现根；目标版本若提供关闭兼容扫描的开关，可在 adapter 层核验后使用，不把人工环境变量当作跨版本标准。旧托管副本只在 marker 匹配时退役。
- Grok 会扫描每一层的 `.agents/skills`，因此不再维护 `~/.grok/skills` 原生副本；Grok 侧的 `compat.claude.skills` 由 managed block 关闭，避免重复载入 Claude 副本。
- 当前源包的 `SKILL.md` 带有 `<!-- ai-config-hub-managed: <skill-name> -->` 标记，同步时随完整包复制。
- `sync-skills.ps1 -Apply` 只覆盖带对应 `ai-config-hub-managed` 标记的托管目录；同名但无标记的目录视为用户资产并拒绝覆盖，历史安装需先显式迁移（Grok 自带 bundled skills 无此 marker，不会被覆盖）。
- skill 备份统一位于 `~/.ai-config-hub/backups/skills/<operation-id>/`，和工具的 skill 发现目录隔离，避免备份被误识别为可用 skill。

## MCP / 工具配置片段

MCP 只管理明确登记的非敏感 server，不保存完整用户配置。`config/managed-assets.psd1` schema v2 登记单 server source、目标工具、runtime、optional 状态、首选用途、doctor 方式和 profile；schema v1 通过规范化层兼容至少一个版本。

单 server 事实源：

- `tool-configs/mcp/shared/local-webfetch.json`：只交付 Claude Code。
- `tool-configs/mcp/shared/context-thread.json`：Claude Code / Codex / Grok / OpenCode 共用。
- `tool-configs/mcp/shared/chrome-devtools.json`：固定使用 browser runtime 中的 `chrome-devtools-mcp@1.6.0`。
Profile 固定为：

| Profile | 能力 |
|---|---|
| `core` | 只给 Claude Code 注册 local-webfetch；其他目标不注册 managed MCP |
| `code-intel` | 支持的目标增加 context-thread |
| `browser-debug` | 四个目标增加 Chrome DevTools |
| `full` | 聚合各目标允许的 local-webfetch、context-thread、Chrome DevTools；OpenCode 接入 context-thread 和 Chrome DevTools |

Playwright MCP 已退役。普通浏览器自动化使用官方 Playwright CLI + skill，CLI 不进入 managed manifest 或 browser MCP runtime。在用户主目录安装两个官方 skill target：

```powershell
npm install -g @playwright/cli@0.1.17
playwright-cli install --skills=claude
playwright-cli install --skills=agents
```

Hub 不复制这些 skill；Claude Code 使用 `claude` target，Codex/OpenCode/Grok 可使用其发现范围内的 `agents` target。

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

默认安装位置分别是 `~\.ai-config-hub\mcp\local-webfetch\`、`~\.ai-config-hub\mcp\context-thread\` 和 `~\.ai-config-hub\mcp\browser\`。最后一项只包含 Chrome DevTools MCP。全部要求 Node.js `>=22.19.0 <25.0.0`，采用 staging、生产依赖安装、smoke、唯一备份和失败回滚。

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
.\scripts\sync-mcp.ps1 -Profile browser-debug -ClaudeCode
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
- 可识别的 retired `pencil` 和 Playwright MCP 在 Apply 时从 Claude/Codex/Grok/OpenCode 配置安全移除；无法识别的同名自定义 server 保留并提示。
- OpenCode 由 `sync-opencode-mcp.ps1` 独立合并 `opencode.json` 的 `mcp` 节，保留 provider、model、permission 和其他用户配置；`code-intel` 接入 context-thread，`browser-debug` 接入 Chrome DevTools，`full` 同时接入两者，并按 ownership 移除旧 local-webfetch。
- Chrome DevTools MCP 不在启动时运行 `npx -y`，只通过已安装且 lockfile 精确固定的 browser runtime 启动；检查脚本拒绝 `@latest` 和 managed `npx` 回流。Playwright CLI 是独立外部工具，不由这条 MCP 检查管线托管。
- Grok hooks / plugins 不由本管线托管；用户自管 `~/.grok/hooks` 与 plugins。
- 每个目标项目的 context-thread 索引仍是项目本地事实源。runtime 存在不等于项目已初始化；使用目标项目 wrapper，或用 `node` 加 `~\.ai-config-hub\mcp\context-thread\dist\bin\context-thread.js` 完整路径执行，不假设存在裸 `context-thread` 命令。
- `sync-mcp.ps1 -Apply` 的备份位于 `~\.ai-config-hub\backups\mcp\<timestamp>-<guid>\`，中途失败时恢复本次已更新的全部目标，不删除历史备份。
- Grok surface 矩阵见 `docs/grok-build-surface.md`；架构决策见 `docs/decisions/0001-grok-first-class-target.md`。

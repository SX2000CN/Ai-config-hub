# 工作任务：AI 配置内容全面修复与思考伙伴 V2

任务 ID：2026-07-16-ai-config-content-repair
创建时间：2026-07-16
更新时间：2026-07-16
状态：已关闭
当前活动：否

## 目标

修复全局规则、skills、MCP/runtime 和 context-thread 的负作用与安全缺口，将 `global-thinking-partner` 重构为可持续对话、发散、推演和决策的推理模式，并建立可验证的路由、profile、doctor 和隐私机制。

## 背景和当前上下文

上一轮基础设施加固已经完成，但内容审查确认全局规则仍有流程税和授权歧义，思考伙伴被固定模板限制，skill 路由和 MCP 能力面缺少显式契约，local-webfetch 与 context-thread 仍存在安全和隐私缺口。

当前工作树包含上一轮未提交改动，必须在其基础上继续，不 reset、不覆盖、不提交、不推送。初始实现阶段只运行用户级 dry-run；2026-07-16 用户随后明确授权全局 Apply，已按当前请求执行。

## 最近结论

- 2026-07-16 用户已明确授权将新配置应用到用户级全局目录；范围为三套 runtime、Claude/Codex 当前规则与 skills，以及默认 `core` MCP profile，不包含历史 `.codex/skills` 兼容目标、提交或推送。
- 全局 Apply 已完成：local-webfetch `1.0.2`、context-thread `0.9.6`、browser runtime、两份规则、Claude/Codex 当前 skills 和 `core` MCP profile 均已同步。
- 全局分发规则已去除双矩阵，项目专属 render/check/dry-run/Apply 约束只保留在本仓库规则和同步文档。
- 思考伙伴已改为显式深聊、隐式静默检查的可组合 reasoning mode，并通过离线夹具和独立前向测试。
- MCP 已使用最小 `core` 作为默认 profile，其余五个 profile 显式选择，Apply 前由 doctor 阻断 required runtime 缺失或漂移。
- context-thread 新索引默认使用 `structure`，当前仓库数据库已按明确例外保持 tracked。
- Codex 桌面宿主重启后的最终验收已通过：新规则与 skills 已载入，MCP 清单只显示用户自有 `node_repl`，连续 15 秒未出现 context-thread MCP 子进程。

## 已确认事实

- `global-thinking-partner` 的模板化根因位于 canonical skill，本轮已从源头移除固定镜头、固定条数、强制推荐和强制简报。
- skill manifest、工具入口、rendered 包和 registry 已统一到 schema v2 路由契约，`global-context-thread` 的失效引用已经移除。
- local-webfetch 已完整覆盖特殊用途地址、DNS、重定向、响应上限、总 timeout 和提示注入边界，显式代理仍按可信网络边界处理。
- context-thread 只读打开不会修复目录或创建 SQLite sidecar；非空 WAL/journal 明确拒绝，状态读取不会因 immutable 连接误报 journal 模式。
- MCP runtime hash 覆盖完整执行 payload、`package.json`、lockfile 和 lockfile 登记的生产依赖，可发现已锁定浏览器 MCP 包的内容篡改或缺失。
- context-thread schema v5 已安装 6 个持久化 structure guards；使用真实旧版 `0.9.4` writer 强制索引后，三类 rich 字段计数仍全部为 0。
- 用户级 Apply 已完成；三套 runtime、两份规则、10 个当前 skill 目标和默认 `core` MCP profile 均与仓库 rendered/source 一致。

## 已尝试 / 已排除

- 不采用只修改提示文案的局部修补；问题涉及规则结构、skill 类型、验证和运行时边界。
- 不在 CI 中调用付费模型；行为质量通过离线夹具、rubric 和独立 agent 前向测试验证。

## 当前卡点

无。Codex 桌面宿主已重启并完成进程级验收。

## 关系索引

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| 全局规则 | 已完成 | 影响所有工具的默认行为和安全边界 | `rules/shared/core.md`、`rules/rendered/` | 无 |
| global-thinking-partner | 已完成 | 影响分析、脑暴和推演体验 | `skills/shared/global-thinking-partner/`、`skills/evals/global-thinking-partner/` | 无 |
| MCP 配置 | 已完成 | 影响全局工具噪音、runtime 和同步安全 | 重启后 `codex mcp list` 仅显示 `node_repl`，15 秒内 context-thread MCP 进程持续为 0 | 无 |
| local-webfetch | 已完成 | 影响 SSRF、响应体资源和提示注入边界 | `tools/local-webfetch/`，20/20 测试通过 | 无 |
| context-thread | 已完成 | 影响索引隐私和只读语义 | `tools/context-thread-engine/`，37/37 测试通过；schema 5 / 6 guards / rich 计数全 0 | 源码变化后正常 sync |

## 下一步最小动作

1. 无。后续只有显式切换 MCP profile 或修改配置源时才重新运行对应检查与同步流程。

## 验证状态

- 三条 render 管线和 `check.ps1`、`check-skills.ps1`、`check-mcp.ps1` 通过。
- context-thread `10 files / 37 tests`、local-webfetch `20/20`、browser runtime `3/3` 通过。
- `scripts/tests/sync-safety.ps1`、`mcp-profiles.ps1`、`mcp-doctor.ps1` 通过；覆盖 inactive 自有 server 保留、完整 runtime payload/生产依赖 hash drift 阻断、schema v1 兼容和 doctor 工具数。
- `scripts/check-all.ps1` 通过；Windows CI 配置会在 Node `22.19.0` 与 `24.x` 上运行同一完整预检并检查 tracked 文件不变。
- 思考伙伴独立 agent 前向测试为 15/16，无硬失败；CI 只运行离线夹具和 rubric，不调用付费模型。
- 对真实用户目录运行三套 runtime、规则、skills 和六个 MCP profile dry-run；17 个用户目标前后指纹变化为 0。
- 用户授权后完成六条 Apply 管线：`runtime-local-webfetch`、`runtime-context-thread`、`runtime-browser-mcp`、`rules`、`skills`、`mcp`；全部 preflight、staging、验证、备份和原子切换成功。
- post-Apply 验证：规则和 10 个当前 skill 目标均为 unchanged；`core` MCP dry-run unchanged，Smoke 暴露 1/1 `fetch` 工具；Claude 仅保留 managed local-webfetch 并保留自有 `node_repl`，Codex 不再含 context-thread、Playwright 或 Chrome DevTools 段。
- 2026-07-16 重启后最终复核：当前会话已加载新的全局规则与 skills；`codex mcp list` 只显示用户自有 `node_repl`，`~/.codex/config.toml` 无 context/browser managed 段，连续 15 秒 context-thread MCP 进程均为 0。
- full Readiness 显示 local-webfetch `1.0.2`、context-thread `0.9.6`、Playwright `0.0.78`、Chrome DevTools `1.6.0` 的 source/install 版本和完整 hash 全部一致；Pencil IDE 插件 MCP 可发现。
- 真实用户目录的 runtime 已追平：local-webfetch `1.0.2`、context-thread `0.9.6`、Playwright `0.0.78`、Chrome DevTools `1.6.0` 的安装版本和完整 hash 与源一致；Pencil IDE 插件 MCP 可发现。
- 当前索引为 105 files / 1677 nodes / 4713 edges，约 2.21 MiB，schema 5、6 个 structure guards、三类 rich 字段计数全 0，`structure`、tracked、journal `wal`、pending 0。重启后未再出现旧 watcher。
- 重启后再次运行 `scripts/check-all.ps1`，全部非修改型 render、测试、验证和用户级 dry-run 通过。
- `git diff --check` 通过。

## 残留风险

- 当前跟踪的 context-thread 历史数据库可能包含旧 rich 索引内容；本轮不进行 Git 历史重写。
- 显式代理被视为可信网络边界，local-webfetch 无法审计代理自身的 DNS 行为。
- `full` profile 同时包含 Playwright 和 Chrome DevTools，doctor 会报告两者对通用 browser-inspection 路由的预期重叠；自动化/测试优先 Playwright，调试/性能优先 Chrome DevTools。

## 相关文件

- `rules/`、`skills/`、`config/`：配置内容和路由事实源。
- `scripts/`、`tool-configs/`、`tools/`：渲染、同步、doctor 和运行时实现。
- `docs/`、`README.md`、`CHANGELOG.md`：长期维护文档。

## 不要重复

- 不绕过 preflight、ownership、备份或回滚机制。
- 不 reset、checkout、提交或推送。
- 不把固定镜头、固定条数或强制推荐重新引入思考伙伴。

## 关闭依据 / 最终结果

计划内规则、skills、MCP/runtime、local-webfetch、context-thread、文档、CI、验证体系和用户级全局 Apply 均已完成。Codex 宿主重启后确认新规则与 skills 已载入、默认 `core` MCP 配置生效且旧 context-thread watcher 不再出现；最终 `scripts/check-all.ps1`、post-Apply dry-run、doctor、索引状态和 `git diff --check` 全部通过，据此关闭任务。

## 全局 Apply 备份

- `C:\Users\sx200\.ai-config-hub\backups\runtime-local-webfetch\20260716-111229-463-c634cb772b1042098557cdd40ae2b333`
- `C:\Users\sx200\.ai-config-hub\backups\runtime-context-thread\20260716-111744-217-e0f46abd5ed745f18a65501c9b33fa0d`
- `C:\Users\sx200\.ai-config-hub\backups\runtime-browser-mcp\20260716-112232-934-0f319cd325b74fa6bf7a57e03fbc200e`
- `C:\Users\sx200\.ai-config-hub\backups\rules\20260716-112756-517-1b9bb89384c247e8b583e4290e21e8b5`
- `C:\Users\sx200\.ai-config-hub\backups\skills\20260716-113107-972-188df9e529fb4851b065d8e28b073595`
- `C:\Users\sx200\.ai-config-hub\backups\mcp\20260716-113458-206-85734ab2013c47349e2ac6c151e174e2`

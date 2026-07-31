# Changelog

## 2026-07-31

- 退役 Playwright MCP，删除 active source、`browser` profile 和 `@playwright/mcp` runtime 依赖；browser runtime 只保留 `chrome-devtools-mcp@1.6.0`，普通浏览器自动化改用外部官方 `@playwright/cli@0.1.17` + skill。
- 将 local-webfetch target 收窄为 Claude Code，OpenCode managed MCP 收敛为 context-thread；新增历史 target、inactive ownership 和 Playwright 精确退役签名，安全清理旧配置并保留同名自定义 server。
- MCP profiles 收敛为 `core`、`code-intel`、`browser-debug`、`full`，同步更新 rendered 片段、doctor/profile/sync-safety 测试、架构与各 target surface 文档。

## 2026-07-16

- 重构共享全局规则，移除 F0-F4 / V0-V4 双矩阵流程税，明确平台约束不可被用户授权覆盖、当前范围内可逆操作默认推进、tracked 文件禁止真实凭证，以及未纳入请求的资产只列清理候选。
- 将 `global-thinking-partner` 升级为可组合 reasoning mode：支持快速校准、协作探索、情景推演和决策收敛，移除固定镜头、固定条数、强制推荐和 `thinking-brief`，新增对话示例、推理动作、`decision-summary`、8 个场景与定性 rubric；独立前向测试为 15/16，无硬失败。
- 将 managed manifest 升级到 schema v2，登记 skill 路由契约和 `core`、`code-intel`、`browser`、`browser-debug`、`design`、`full` 六个 MCP profile；新增 schema v1 兼容、锁定 browser runtime、profile 切换 ownership 保护和 Source/Readiness/Smoke doctor。Runtime hash 覆盖完整执行 payload、`package.json`、lockfile 以及 lockfile 登记的生产依赖，可发现已锁定浏览器包的内容篡改或缺失。
- 将 local-webfetch 升级到 `1.0.2`，补齐特殊用途 IPv4/IPv6、DNS fail-closed、逐跳重定向复验、HTTPS 降级阻断、5 MB 流式上限、总 timeout、固定直连地址和不可信外部内容边界；dispatcher 清理也受同一总 deadline 约束，最终 20/20 测试通过。
- 将 context-thread 升级到 `0.9.6`，新增默认 `structure` / 显式 `rich` 内容策略、legacy-rich 兼容、默认忽略/显式跟踪数据库、零写入只读、隐私迁移备份与 staging 重建，并修正只读 journal 状态误报；schema v5 安装 6 个持久化 structure guards，约束旧版或不了解内容策略的 writer，当前仓库索引已重建为 structure 模式。
- 扩充 Windows CI 与完整预检，覆盖三个 runtime 测试集、同步事务、MCP profiles/doctor、全部用户级 dry-run、敏感信息和 tracked 文件零修改检查；用户后续授权后已将三套 runtime、规则、当前 skills 和默认 `core` MCP profile 应用到用户级目录，未提交或推送。
- 补充旧版 Claude `cmd /c` 与 Codex 无 marker 直连 MCP 的精确 ownership migration signature，使默认 `core` profile 能移除历史 ai-config-hub context/browser 注册，同时继续保护真正的同名自有配置。
- 完成全局 Apply 后的 Codex 宿主重启验收：新会话已载入新规则与 skills，Codex MCP 清单仅保留用户自有 `node_repl`，连续 15 秒未出现旧 context-thread watcher；最终完整预检、core Smoke、全局一致性 dry-run 和 structure 索引状态全部通过。

## 2026-07-15

- 将 context-thread 升级到 `0.9.5`：新增 `git_state_v1` Git 基线与脏路径跟踪，修复过滤条件交集，落实 SQLite 真只读模式，统一 Node.js `>=22.19.0 <25.0.0` 门禁，并让 CLI/MCP 版本从 package 元数据读取。
- 将 local-webfetch 升级到 `1.0.1`，统一 Node.js 支持范围；浏览器 MCP 精确锁定 `chrome-devtools-mcp@1.6.0` 与 `@playwright/mcp@0.0.78`，render/check 阻止 `@latest` 回流。
- 新增 `config/managed-assets.psd1` 作为规则、skills、MCP 和 runtime 的统一资产清单；render 支持非写入 `-Check`，`check-all.ps1` 覆盖引擎测试、runtime 校验、同步安全测试、全仓敏感信息扫描和全部 dry-run。
- 重构所有用户级同步为 preflight-first 的 staging/备份/严格切换事务，支持 `-UserHome` 隔离测试、目标指纹并发保护、类型冲突拒绝和失败全量回滚；Claude MCP 与 Pencil CLI 注册共用同一事务。
- 新增根 `AGENTS.md` Codex 薄入口，统一 F0-F4 / V0-V4 术语并更新架构、同步和 context-thread 文档；新增 Windows CI，在 Node 22.19.0 与 24.x 上验证完整预检不会修改 tracked 文件。

## 2026-05-25

- 将项目文档重心从分发系统调整为 AI 配置本体，新增 `docs/ai-config-design.md`，并把脉络设计、实现和场景文档整理到 `docs/context-thread/`。
- 清理迁移后的旧 `docs/ai/` 副本，以及一次性视觉验证和 Pencil 测试产物；`.Ai-config/` 保留为当前项目 AI 接手事实源。
- 补强 context-thread 引擎的 MCP 工具关闭、watcher 说明、依赖方重解析和新增源码目录 pending 检测，并增加对应测试。
- 修复 context-thread runtime 依赖审计问题：升级 `picomatch` 锁定版本，并将 `vitest` 升级到安全版本以清理 dev audit 噪音。
- 在共享规则中加入项目文档和产物整理原则，要求旧入口、重复副本、一次性夹具和运行时临时文件不作为长期项目资产保留。

## 2026-05-24

- 将本仓库项目级 AI 配置中枢从旧版 `docs/ai/` 迁移到根目录 `.Ai-config/`，旧路径仅保留兼容提示；`.Ai-config/context-thread/` 作为脉络项目索引目录并加入忽略。
- 引入轻量结构化事实层：新增 `global-context-thread` skill，用 context-thread 承接复杂代码关系，用 `.Ai-config` 任务卡关系索引承接非代码复杂工作流，同时保持 F0/F1 小任务不升级。
- 新增 `context-thread` MCP 配置组，并把脉络引擎运行时分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`；MCP 配置通过 `node` 启动用户级 runtime，不再指向当前仓库路径，runtime 缺失时仅 warning，不阻塞浏览器 MCP。
- 在共享规则中加入短版“结构化事实优先”原则，并给任务卡模板增加可选 `关系索引` 区块。

## 2026-05-19

- 轻量化全局 AI 规则：把默认工作方式改为按风险升级，减少小任务中的文档、任务卡、计划和验证仪式感。
- 调整 `project-ai-config-hub`：目标项目按需启用 `.Ai-config/CURRENT.md`、任务卡、registry 和项目级 skill 入口，不再把完整中枢作为所有项目的默认负担。
- 更新工作状态设计与项目文档，明确任务卡只用于跨会话、多任务、等待确认、阻塞或有残留风险的任务。
- 收紧 `pencil-design-workflow` 与 `global-frontend-design` 交接：设计请求默认必须使用当前会话可用的可见 Pencil MCP 宿主，VS Code/Cursor 插件端和 Pencil Desktop 客户端都可作为有效宿主；Pencil MCP 不可用时必须停下说明，不能静默降级到 CLI/headless 或直接进入前端实现。
- 轻量化 `pencil-design-workflow`：入口和主流程改为短闸门，CLI/headless、MCP 细节、保存位置和审查验证拆到按需 references，减少与前端设计 skill 叠加时的上下文负担。
- 补准 Pencil 宿主选择边界：宿主由当前 AI 工具环境注入，模型不能自由切换 Desktop 和插件端；只有当前宿主为 `desktop` 或用户明确要求 Desktop 主窗口时，才按 Desktop transport 细节处理。
- 补准 Pencil 直连 MCP 验证：要求确认当前会话暴露 Pencil MCP 工具或 `tools/list` 返回关键工具，使用 `open_document({ path })` 打开目标 `.pen`，并用 `get_editor_state` 确认 active editor，避免误用 `filePath` 新建 `pencil-new.pen`。

## 2026-05-08

- 初始化 `ai-config-hub` 项目脚手架。
- 添加共享规则源、Claude Code / Codex 专属补充、模板和渲染脚本。
- 添加检查脚本、同步脚本、安全示例配置和 skills 规划目录。
- 优化全局规则：补充验证策略、减少低价值文档更新、限定最终回复要求适用范围，并增强 Claude Code 配置机制说明。
- 精简共享规则中重复的文档要求，压缩项目文档覆盖说明和修改检查清单，降低全局提示词冗余。
- 新增通用规则：新功能或外部能力相关任务需优先联网核验最新权威资料，缺陷修复需遵循复现、根因定位、最小修复和回归验证流程。
- 新增版本控制与提交规则：默认优先使用中文提交信息，并要求提交前检查 diff、避免无关改动和敏感信息。
- 收窄外部资料核验规则：仅在外部能力、版本、安全、官方资料或用户明确要求时强制核验，纯项目内部新功能可不联网。
- 精简缺陷修复规则，保留复现、根因、最小修复、回归验证和残留风险反馈要求，降低全局提示词篇幅。

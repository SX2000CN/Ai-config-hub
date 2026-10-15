# 工作任务：可移植 Agent 配置本体优先重构

任务 ID：2026-10-15-portable-agent-config-source
创建时间：2026-10-15
更新时间：2026-10-15
状态：已关闭
当前活动：否

## 目标

把 ai-config-hub 的长期维护中心转为可移植的共享规则与完整 Agent Skill 包。客户端发现路径作为 adapter；MCP、runtime 和用户级同步作为可选集成；`.Ai-config/` 仅承载项目状态与索引。

## 背景和当前上下文

本轮实施源于对 `.agents`、Agent Skills、客户端发现行为和现有事实源分裂的审查。`.agents/` 现在作为本仓库唯一的可移植配置本体目录；`.agents/skills/` 保存完整 Skill 包，`.agents/rules/` 保存共享规则。Claude、MCP、runtime 和用户级同步仍属于可选 adapter / 集成层。

## 已确认事实

- Agent Skills 规定包结构和 `SKILL.md` 字段，不规定客户端自动发现路径。
- `.agents/skills/` 是部分客户端支持的发现路径，不是万能配置标准。
- 本仓库以 `.agents/skills/<name>/` 为每个 Skill 的唯一完整内容源；支持该路径的客户端直接读取，`sync-skills.ps1` 按需从源同步到用户级路径，不生成仓库内中间副本。
- 当前默认 adapter 只支持 `.agents/skills/` 发现路径；Claude Code 的独立 `.claude/` adapter 暂停维护，旧导出保留作清理候选。
- `.Ai-config/` 保存状态、任务卡、registry 与结构索引；Skill 内容不放在 `.Ai-config/skills/`。
- 旧 `skills/claude-code/` 和 `skills/codex/` 入口已删除；历史 rendered 路径仍作为导出物清理候选。

## 已完成

- [x] 将四个当前 Skill 内容迁为完整标准包源，并移除共享 `when_to_use` 自定义字段。
- [x] 改写主 README、架构、设计、skills 路线图和同步边界说明。
- [x] 修正项目级 AI config Skill 的 workflow、迁移参考与生成模板，避免继续生成薄包或将状态层当内容源。
- [x] 将 Grok 描述改为本机版本验证的可选 adapter，并为 Grok ADR 补充当前方向说明。
- [x] 前阶段曾收敛 Skill renderer 的 `Names` 清单和输出范围；最终由目录自动发现和直接同步取代，不再维护中间渲染。
- [x] 新增 `scripts/check-content.ps1` 作为规则与 Skill 修改的内容本体检查入口，排除 MCP/runtime、用户目录和部署依赖。
- [x] 将 Skill 检查扫描范围收敛到 `.agents/skills/` 和 `skills/evals/`，并拒绝非标准 `when_to_use` frontmatter；历史 `skills/rendered/` 不参与包内容校验。
- [x] 更新 README、架构、设计、同步、OpenCode、路线图、manifest 和路径参考，明确 `.agents` / `.claude` 是 adapter 发现路径，OpenCode 双目录风险按版本核验。
- [x] 修正 `check-content.ps1` 的子脚本退出码判断，避免继承调用前的 `$LASTEXITCODE` 造成假失败；移除重复的 render 检查调用。
- [x] 让规则和 Skill 的 Apply 使用内容 preflight；MCP、runtime 和 guard 继续使用完整集成 preflight，并将 CI 的内容门禁与手动集成预检分开。
- [x] 将规则和 Skill 源集中迁移到 `.agents/`，移除旧版 `skills/claude-code/` 与 `skills/codex/` 源目录。
- [x] 从目录结构自动发现 Skill 包，不再在 manifest 重复登记 `Skills.Names`。
- [x] 暂停 Claude Code 规则/Skill 默认 adapter，保留已有 rendered 输出为迁移/清理候选。
- [x] 接续修复迁移残留：规则敏感内容扫描覆盖新源根；同步安全并发测试改为读取 manifest 实际目标；文档移除旧名单与 Skill 渲染说明，CURRENT 详情移入本卡。

## 下一步最小动作

1. [x] 将规则和完整 Skill 包迁移到 `.agents/` 并移除旧源入口。
2. [x] 运行规则、Skill、内容检查和 `git diff --check`。
3. [x] 检查最终 diff、旧路径残留和 `.Ai-config/CURRENT.md` 状态。

## 验证状态（2026-10-15 实际运行）

- 本次接续通过：`render.ps1 -Check`、`check.ps1`、`render-skills.ps1 -Check`（兼容入口，不生成文件）、`check-skills.ps1`、`check-content.ps1`（包含规则 hygiene）、`powershell.exe -NoProfile -File scripts/check-content.ps1`、`git diff --check` 与暂存区 whitespace 检查。
- 同步安全回归：接续基线 `scripts/tests/sync-safety.ps1` exit 1，旧测试向已暂停的 `.claude/CLAUDE.md` 注入并发写入，没有覆盖真实同步目标。改为读取 manifest 的实际规则目标后重跑 exit 0，输出 `Sync safety tests passed`。这是测试夹具过期，未改部署事务行为。
- 部署预览：`sync.ps1` 与 `sync-skills.ps1` 使用隔离临时 `-UserHome` 路径的 dry-run 均 exit 0，且没有创建目标根；未读取或修改真实客户端用户目录。
- 未通过：`check-all.ps1` 在 `check-mcp.ps1` 阶段报告 core、code-intel、browser-debug、full 四个 profile 的 Claude/OpenCode 共 8 个 rendered MCP 文件过期；接续基线即已失败，本次未修改 MCP source、runtime 或 rendered MCP 文件。
- 前阶段记录通过、本次未重跑：`scripts/tests/mcp-doctor.ps1`、`scripts/tests/hooks-guard.ps1`。
- 未运行：真实用户级 Apply、真实用户目录同步、runtime 测试和 MCP doctor；全量检查在 MCP render 阶段停止，未进入后续集成步骤。同步安全测试仅在隔离临时目录中模拟 Apply。
- 未执行用户级 Apply；提交和推送仍需用户单独明确要求。

## 残留风险

- `skills/rendered/` 和 `rules/rendered/` 仍是仓库内跟踪的生成物，后续可迁移到构建产物或 staging。
- 用户级 skill 与 MCP 目录可能仍保留旧导出；本任务不读取、改写或追平它们。
- Grok 对 `.agents/skills/` 的支持是本机版本证据，升级客户端后需复核；OpenCode `1.18.11` 同时扫描 `.agents/skills` 与 `.claude/skills`。Claude adapter 暂停可避免 Hub 自身创建同名双导出。
- `config/managed-assets.psd1` 仍把内容、MCP 和 runtime 登记在同一份 manifest；部署层物理拆分需另开可回滚任务。
- `.Ai-config/context-thread/context-thread.db` 仍是 Git 跟踪的索引缓存，持续产生工作树修改；是否改为可重建缓存需单独决策。

## 相关文件

- `.agents/`：唯一可移植配置本体，包含规则和完整 Skill 包。
- `scripts/check-skills.ps1`：源包结构、frontmatter、引用与评测检查；`render-skills.ps1` 只保留兼容入口，不写文件。
- `docs/architecture.md`、`docs/ai-config-design.md`：当前架构边界。
- `.agents/skills/project-ai-config-hub/references/official-paths.md`：客户端发现路径核验。

## 不要重复

- 不要把 `.agents/` 描述成 Agent Skills 万能标准或所有客户端自动发现路径。
- 不要恢复 `.Ai-config/skills/` 作为 Skill 内容源。
- 不要通过增加客户端目标、MCP profile 或 runtime 来表达共享内容。
- 不要执行用户级 Apply、提交或推送。

## 关闭依据 / 最终结果

仓库内内容检查已完成并通过。`check-all.ps1` 仍因既有 Claude/OpenCode MCP rendered 差异未全绿；MCP 导出修复、runtime 集成预检和历史 rendered 清理需另开任务决定。

## 历史部署证据（从 CURRENT 移入，非本次验证）

| 事项 | 当时记录的结果 | 证据 |
|---|---|---|
| 配置理念重构：单源规则 + 强制层 + 过期轴 + 防锈 | 规则 4 份逐字节相同；guard 24 项单测通过；依据表与章节对齐断言；防锈断言含反向用例 | 五步用户级 Apply 全部 exit 0；备份 `backups/{rules,skills,mcp,claude-guard}/20261002-*` |
| skills 分发收敛 | 目标 4→2，Grok 副本退役，`grok inspect --json` 探针实测仍发现 4 个 skill | dry-run 显示 `would remove retired managed target`×4，Apply 后 `~/.agents/skills` 完整 |
| MCP 私有 overlay 与所有权修复 | 代理 env 移出可分发片段；legacy 形态带 env 不再误判冲突 | `~/.claude.json` 的 local-webfetch 已迁为规范形态且 env 保留 |
| A/B 跑道 | 确定性评分器 + `appliesIf` / `held-by-inertia` + 留组 + 座次交换判平 | `ab/score.test.mjs` 7/7 通过 |

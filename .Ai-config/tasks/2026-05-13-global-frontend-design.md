# 工作任务：重构 global-frontend-design skill

任务 ID：2026-05-13-global-frontend-design
创建时间：2026-05-13 19:00
更新时间：2026-05-14
状态：已关闭
当前活动：否

## 目标

把 `global-frontend-design` 从偏工程化的前端工作流包，重构成视觉方向优先、产品 UI 工程作为支撑的融合 skill，使其更能体现 Claude 官方 `frontend-design` 的强视觉立场，同时保留可访问性、响应式、状态覆盖和验证要求。

## 背景和当前上下文

用户说明该 skill 是让 agent 融合两个前端 skill 后得到的结果，但最终版本看不到 Claude 官方前端设计 skill 的影子，因此担心完整性达不到预期。只读审计结论是：当前包工程完整性较好，但视觉主线权重不足，Claude 官方 frontend-design 的审美立场被降级到参考资料层。

## 最近结论

- 已按批准计划完成重构：`SKILL.md` 和 `workflow.md` 已改为视觉方向优先。
- `references/design-principles.md` 已提升为视觉判断主源，`product-ui-engineering.md` 调整为落地支撑。
- 模板和检查清单已改成围绕视觉 brief、产品记忆点和生产约束做支撑。
- 两个上游 skill 的来源记录已归档到 `.Ai-config/archive/global-frontend-design-sources/`；Anthropic 原文因 LICENSE.txt 暂未核验，不作为完整快照公开提交。

## 已确认事实

- `global-frontend-design` 已纳入本仓库全局 skill 体系，事实源位于 `skills/shared/global-frontend-design/`。
- Claude Code 入口源位于 `skills/claude-code/global-frontend-design/SKILL.md`。
- Codex 入口源位于 `skills/codex/global-frontend-design/SKILL.md`。
- rendered 包已生成到 `skills/rendered/claude-code/global-frontend-design/` 和 `skills/rendered/codex/global-frontend-design/`。
- 本机全局目录已同步：`C:\Users\sx200\.claude\skills\global-frontend-design\` 和 `C:\Users\sx200\.agents\skills\global-frontend-design\`。
- 需要保留 `ATTRIBUTION.md` 的非官方声明和来源边界。

## 已尝试 / 已排除

- 已通过本机代理核验两个上游 skill；`jscraik/Agent-Skills` 许可证为 Apache-2.0，Anthropic `frontend-design` 的 `LICENSE.txt` 当时返回 404。
- 已将全局 skill 脚本从单 `project-ai-config-hub` 硬编码改为支持 `project-ai-config-hub` 和 `global-frontend-design`。
- 未把 `.codex\skills` 作为默认同步目标；仅保留 `-IncludeCodexLegacy` 可选历史兼容。

## 当前卡点

无。

## 下一步最小动作

无。本任务已关闭；若后续需要兼容旧 Codex 路径，再单独运行并确认 `scripts/sync-skills.ps1 -Apply -IncludeCodexLegacy`。

## 验证状态

- 已运行 `scripts/render-skills.ps1`，成功生成 `project-ai-config-hub` 和 `global-frontend-design` 的 Claude Code / Codex / codex-legacy rendered 包。
- 已运行 `scripts/check-skills.ps1`，结果：`Skill check passed`。
- 已运行 `scripts/sync-skills.ps1` dry-run，确认新目标为 missing、旧目标 unchanged。
- 已运行 `scripts/sync-skills.ps1 -Apply`，已同步到 `C:\Users\sx200\.claude\skills\global-frontend-design\` 和 `C:\Users\sx200\.agents\skills\global-frontend-design\`。
- 修正 `sync-skills.ps1` 备份目录位置，避免 `.bak` 目录被 Claude Code 识别为可用 skill；已将本轮生成的备份移到 skills 发现目录外。
- 再次运行 `scripts/render-skills.ps1`、`scripts/check-skills.ps1`、`scripts/sync-skills.ps1` 和 `git diff --check`；结果为 `Skill check passed`、四个默认目标均 `unchanged`，仅出现 LF/CRLF 换行提示，未发现 whitespace error。

## 残留风险

- 用户已确认本机全局配置为最新；本轮已核验仓库 rendered 包与本机 Claude Code / Codex 全局 skill 目录一致。
- 公开分发前仍需重新联网核验 Anthropic `frontend-design` 的完整许可证和条款。
- 根目录 `global-frontend-design/` 已不再作为事实源；全局 skill 事实源统一为 `skills/shared/global-frontend-design/`。

## 相关文件

- `skills/shared/global-frontend-design/README.md`：共享事实源说明。
- `skills/shared/global-frontend-design/workflow.md`：端到端工作流。
- `skills/shared/global-frontend-design/references/design-principles.md`：视觉方向主源。
- `skills/shared/global-frontend-design/references/product-ui-engineering.md`：产品 UI 工程支撑。
- `skills/shared/global-frontend-design/templates/`：brief、计划、review 和汇报模板。
- `skills/shared/global-frontend-design/checklists/`：检查清单。
- `skills/shared/global-frontend-design/ATTRIBUTION.md`：来源与归属边界。
- `skills/claude-code/global-frontend-design/SKILL.md`：Claude Code 薄入口源。
- `skills/codex/global-frontend-design/SKILL.md`：Codex 薄入口源。

## 不要重复

- 不要把本 skill 声称为 Anthropic 官方 skill。
- 不要把 Anthropic `frontend-design` 的完整原文快照提交到公开仓库，除非已确认完整许可证条款。
- 不要在本轮顺手迁移到 `.Ai-config/skills/`。

## 关闭依据 / 最终结果

已确认达到本机全局 skill 完全体：共享事实源、Claude Code / Codex 入口、rendered 包、同步脚本、registry、文档和任务状态均已一致；用户级全局目录已同步且 dry-run 为 `unchanged`，本轮 rendered/global 文件哈希对比也一致。公开分发前仍需重新核验 Anthropic 上游完整许可证。

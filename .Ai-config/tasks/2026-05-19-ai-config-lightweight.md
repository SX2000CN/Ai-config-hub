# 工作任务：AI 配置轻量化

任务 ID：2026-05-19-ai-config-lightweight
创建时间：2026-05-19 00:38
更新时间：2026-05-19 01:10
状态：已关闭（未跟进关闭）
当前活动：否

## 目标

在不损失护栏效果的前提下，把全局 AI 配置和项目级 `.Ai-config` 机制改成按风险、接手价值渐进启用，减少日常使用中的流程负担，同时保留模型主动发挥和必要安全边界。

## 背景和当前上下文

用户反馈日常使用中这套 AI 配置仍然偏重，希望极致轻量化：约束模型，但不要压制模型能力。当前仓库是配置中枢本身，因此需要同步更新规则源、项目级 skill 事实源、rendered 产物和相关设计文档。

## 最近结论

- 全局规则已从“默认做完整流程”改为 L0-L3 风险分级。
- `project-ai-config-hub` 已改成按需分层：项目规则 / `CURRENT.md` / 任务卡 / 项目级 skill 入口逐层启用。
- 任务卡不再用于所有非简单任务，只用于跨会话、中断、等待确认、阻塞或有残留风险的任务。
- 第一遍思考伙伴检查发现的 3 个软问题已修复：L1/L2 边界补充“先低风险小步推进”规则；工作状态设计收窄“完成后待确认”的适用范围；项目 README 模板移除“非简单任务前必读 CURRENT”的旧语气。

## 已确认事实

- 用户明确希望轻量化的是“项目中的 AI 配置机制”，不是本仓库本身。
- 本仓库的规则事实源是 `rules/shared/core.md`，rendered 文件由 `scripts/render.ps1` 生成。
- `project-ai-config-hub` 的事实源是 `skills/shared/project-ai-config-hub/`，rendered skill 包由 `scripts/render-skills.ps1` 生成。

## 已尝试 / 已排除

- 已排除只加说明不改机制的做法；本轮直接改了规则源、skill 工作流、模板和设计文档。
- 已在用户确认后执行 `sync.ps1 -Apply` 和 `sync-skills.ps1 -Apply`，本机用户级全局规则和 managed skills 已写入，并保留脚本生成的备份。

## 当前卡点

等待用户日常试用后确认轻量化方向是否符合手感。

## 下一步最小动作

1. 观察本机日常使用中的触发手感；如仍偏重，再做第三轮微调。

## 验证状态

- 已运行 `scripts/render.ps1`。
- 已运行 `scripts/render-skills.ps1`。
- 已运行 `scripts/check.ps1`，结果 `Check passed`。
- 已运行 `scripts/check-skills.ps1`，结果 `Skill check passed`。
- 已运行 `git diff --check`，仅有 Windows LF/CRLF 提示，无 whitespace error。
- 2026-05-19 01:01 收口验证：重新运行 `scripts/render.ps1`、`scripts/render-skills.ps1`、`scripts/check.ps1`、`scripts/check-skills.ps1`、`scripts/sync.ps1`、`scripts/sync-skills.ps1`、`git diff --check`；规则和 skill 检查通过，dry-run 显示真实全局规则和 `project-ai-config-hub` 用户级 skill 仍待同步，未执行 `-Apply`。
- 2026-05-19 01:10 本机同步：已运行 `scripts/sync.ps1 -Apply`，同步 `rules/rendered/CLAUDE.md` 到 `C:\Users\sx200\.claude\CLAUDE.md`，同步 `rules/rendered/AGENTS.md` 到 `C:\Users\sx200\.codex\AGENTS.md`。
- 2026-05-19 01:10 本机同步：已运行 `scripts/sync-skills.ps1 -Apply`，同步 managed skills 到 `C:\Users\sx200\.claude\skills\...` 和 `C:\Users\sx200\.agents\skills\...`。
- 2026-05-19 01:10 复查：重新运行 `scripts/sync.ps1` 和 `scripts/sync-skills.ps1` dry-run，全部目标均为 `unchanged`；并用 `rg` 确认本机全局规则和 `project-ai-config-hub` skill 已包含轻量化语句。

## 残留风险

- 轻量化后的规则已同步到真实用户级配置，后续需要观察是否仍能稳定触发必要文档更新和任务卡记录。
- 若日常使用仍感觉偏重，下一轮应优先微调 `docs/work-state-design.md` 和 `.Ai-config/tasks/README.md` 中偏保守的状态语气。

## 相关文件

- `rules/shared/core.md`：全局轻量化核心规则事实源。
- `rules/rendered/CLAUDE.md`：Claude Code rendered 规则。
- `rules/rendered/AGENTS.md`：Codex rendered 规则。
- `skills/shared/project-ai-config-hub/`：项目级配置中枢 skill 事实源。
- `skills/rendered/`：重新生成的 skill 安装包。
- `docs/work-state-design.md`：工作状态机制设计。
- `.Ai-config/CURRENT.md`：本仓库当前状态总览。

## 不要重复

- 不要把简单任务重新强制纳入任务卡流程。
- 不要把完整 `.Ai-config/tasks/`、`archive/`、`skills-registry.md` 当作所有项目的默认健康指标。

## 关闭依据 / 最终结果

已完成仓库源文件、rendered 产物和本机全局配置同步。轻量化方向后续经过多轮试用和迭代（例如 07-08 对 core.md、global-thinking-partner、project-ai-config-hub 的进一步收敛），证明方向可用。2026-07-08 按 `.Ai-config/CURRENT.md` 形态约束的 30 天未跟进规则标记关闭；轻量化是持续过程，后续调整开新任务卡跟进，不复用本卡。

# 工作任务：调研思维扩展类全局 coding skill

任务 ID：2026-05-14-thinking-partner-research
创建时间：2026-05-14
更新时间：2026-05-14
状态：待用户确认
当前活动：否

## 目标

调研是否值得新增低副作用的思维扩展类全局 coding skill，并收集官方机制、社区实现和可借鉴模式；同时把本机代理端口 `7897` 写入本项目全局规则源文件，供后续同步流程同步到真实全局规则。

## 背景和当前上下文

用户已有工作状态系统，不需要重复做代码审查、验证、提交准备或状态记录类 skill。用户更关心能扩展 agent 思考范围、避免过早收敛、发现失败模式和简化过度设计的“思维扩展”能力。

## 最近结论

- 已开始实现 `global-thinking-partner`，采用轻量全局 skill 方案，而不是多个重型 skill。
- 事实源已创建到 `skills/shared/global-thinking-partner/`，Claude Code / Codex 薄入口已创建。
- 输出视角固定为方案发散、失败模式、简化路径、维护者/后续 AI 接手视角。
- 约束保持为默认只读、手动触发优先、短输出；不负责自动写代码、同步、提交或推送。

## 已确认事实

- Claude Code 官方机制上，skill 适合封装可复用工作流，subagent 适合独立上下文的 critic / reviewer。
- 社区常见模式包括 maker/critic、plan reviewer、anti-drift coordinator、checkpoint gate、只读 reviewer subagent、先 brainstorm 再 plan 再 execute。
- `rules/shared/core.md` 已加入本机代理端口说明：需要通过本机代理访问外部资料时，优先使用 `http://127.0.0.1:7897` 作为 `HTTP_PROXY` / `HTTPS_PROXY`，但不能假设为其他机器或其他用户环境的通用配置。

## 已尝试 / 已排除

- 已尝试 WebSearch 搜索 Claude Code skills、reflection、solution expander、Cursor rules、anti-drift 等材料。
- WebFetch 读取部分官方/论文页面时受安全策略限制，已改用 Claude Code 指南代理做补充调研。
- 用户已确认进入实现阶段，开始创建 `global-thinking-partner` 全局 skill。

## 当前卡点

等待用户实际触发确认 `global-thinking-partner` 是否符合预期。

## 下一步最小动作

1. 用户在 Claude Code 中尝试触发 `global-thinking-partner`。
2. 若触发和输出符合预期，可关闭本任务；若输出过长或误触发，再收紧入口描述和触发边界。

## 验证状态

- 已运行 `scripts/render.ps1`，成功更新 `rules/rendered/CLAUDE.md` 和 `rules/rendered/AGENTS.md`。
- 已运行 `scripts/check.ps1`，结果：`Check passed`。
- 已运行 `scripts/render-skills.ps1`，成功生成 `global-thinking-partner` 的 Claude Code / Codex / codex-legacy rendered 包。
- 已运行 `scripts/check-skills.ps1`，结果：`Skill check passed`。
- 已运行 `scripts/sync-skills.ps1` dry-run，新 skill 目标最初为 `missing target`。
- 已运行 `scripts/sync-skills.ps1 -Apply`，已同步到 `C:\Users\sx200\.claude\skills\global-thinking-partner\` 和 `C:\Users\sx200\.agents\skills\global-thinking-partner\`。
- 再次运行 `scripts/sync-skills.ps1`，六个默认目标均为 `unchanged`。
- 已运行 `git diff --check`；仅出现 LF/CRLF 换行提示，未发现 whitespace error。

## 残留风险

- 调研材料来自官方文档、社区目录/帖子和研究摘要，不等于已经确认某个现成实现适合直接引入。
- 若未来实现为自动触发 hook，可能干扰正常编码流；应优先做手动触发、只读 skill。

## 相关资料

- Claude Code Skills：`https://docs.claude.com/en/docs/claude-code/skills`
- Claude Code Subagents：`https://docs.claude.com/en/docs/claude-code/subagents`
- Claude Code Hooks：`https://code.claude.com/docs/en/hooks`
- Claude Code Commands：`https://code.claude.com/docs/en/commands`
- Claude Code Features Overview：`https://code.claude.com/docs/en/features-overview`
- Anthropic subagents blog：`https://claude.com/blog/subagents-in-claude-code`
- Cursor Rules：`https://docs.cursor.com/en/context`
- Configuring Agentic AI Coding Tools：`https://arxiv.org/abs/2602.14690`
- Agent Skills analysis：`https://arxiv.org/abs/2602.08004`
- Cult of Claude skills directory：`https://cultofclaude.com/`

## 关闭依据 / 最终结果

已完成 `global-thinking-partner` 全局 skill 实现、渲染、检查和本机同步。该 skill 已作为低副作用、只读、手动触发优先的思维扩展能力安装到 Claude Code / Codex 用户级目录，等待用户实际触发确认。

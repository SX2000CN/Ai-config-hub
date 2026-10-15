# 官方发现路径

最后核验：2026-10-15。以下列的是客户端发现行为，不是 Agent Skills 格式规定的路径。格式兼容不代表客户端会自动扫描目录。

本机当日版本快照：Claude Code `2.1.296`、Codex `0.162.0`、OpenCode `1.18.11`。版本号会变化；变更路径策略前重新查官方文档。

## Claude Code

规则入口：项目目录链中的 `CLAUDE.md`；Claude Code `2.1.277+` 也支持 `AGENTS.md`。若目录链中存在 `CLAUDE.md` / `CLAUDE.local.md`，不能假定 `AGENTS.md` 也会作为 fallback 被加载。

Skills 发现位置：

```text
~/.claude/skills/<name>/SKILL.md
.claude/skills/<name>/SKILL.md
<plugin>/skills/<name>/SKILL.md
```

Claude Code 不自动扫描 `.agents/skills/`。在 Claude 与其他客户端间共享包时，将同一完整包导出到 Claude 发现目录。

官方资料：[memory and `AGENTS.md`](https://code.claude.com/docs/en/memory)、[skills](https://code.claude.com/docs/en/skills)。

## Codex

规则使用项目目录链中的 `AGENTS.md`，并支持 `AGENTS.override.md` 等更具体入口。Skills 发现位置：

```text
~/.agents/skills/<name>/SKILL.md
.agents/skills/<name>/SKILL.md
<plugin>/skills/<name>/SKILL.md
```

`.agents/skills/` 是 Codex 的发现路径，不是 Agent Skills 规范的一部分。`~/.codex/skills/` 不是当前官方默认路径。

官方资料：[AGENTS.md](https://developers.openai.com/codex/guides/agents-md/)、[skills](https://developers.openai.com/codex/skills/)。

## OpenCode

规则入口包括项目 `AGENTS.md`、`.opencode/AGENTS.md` 和用户级 `~/.config/opencode/AGENTS.md`。Skills 支持项目/用户级原生目录，也扫描兼容目录：

```text
.opencode/skills/<name>/SKILL.md
~/.config/opencode/skills/<name>/SKILL.md
.agents/skills/<name>/SKILL.md
~/.agents/skills/<name>/SKILL.md
.claude/skills/<name>/SKILL.md
~/.claude/skills/<name>/SKILL.md
```

因此 OpenCode 可能同时发现多个来源。本机 `1.18.11` 的公开文档没有给出可依赖的同名覆盖优先级；不要把未核验版本的实现顺序当作合并契约。共享包只保留一个内容源，并按需使用单一发现路径。新主版本文档若定义了不同的确定性 precedence，仍需按目标版本复核。

OpenCode 官方文档要求各来源的 Skill 名称唯一，并提供 `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` 关闭 `.claude/skills/` 兼容扫描。若项目同时导出 `.agents/skills/` 和 `.claude/skills/`，OpenCode 可能从两处看到同名完整包；应在启动 OpenCode 的环境中使用该开关，或确保它只暴露一个发现根。开关行为和路径以目标 OpenCode 版本文档为准；本机快照为 `1.18.11`，不要外推为其他主版本的保证。

官方资料：[rules](https://opencode.ai/docs/rules/)、[skills](https://opencode.ai/docs/skills/)。

## Grok Build（本机验证）

本机 `~/.grok/docs/user-guide` 与 `grok inspect --json` 实测显示，当前安装可从各层 `.agents/skills/` 发现 Skills，也支持 `.grok/skills/`。这是本机版本证据，不代表公开开放规范或其他版本的保证；行为变化时重新检查本机文档和实际发现结果。

## 本仓库的包约定

本仓库将完整包源保存在 `skills/shared/<name>/`。`render-skills.ps1` 将相同文件导出到 `skills/rendered/claude-code/` 和 `skills/rendered/codex/`，分别对应 `.claude/skills/` 与 `.agents/skills/`。这些是仓库的 source/export 约定，不是客户端规定的事实源布局。

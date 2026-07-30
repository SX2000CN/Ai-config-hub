# 官方路径和兼容边界

最后核验时间：2026-07-30

## Claude Code

常用 skill 位置：

```text
~/.claude/skills/<skill-name>/SKILL.md
.claude/skills/<skill-name>/SKILL.md
<plugin>/skills/<skill-name>/SKILL.md
```

含义：

- `~/.claude/skills`：用户级 / 全局 skill。
- `.claude/skills`：项目级 skill 的 Claude Code 发现入口。
- plugin 内 `skills/`：可分发插件中的 skill。

对 `project-ai-config-hub` 创建或修复的目标项目，`.claude/skills/<skill-name>/SKILL.md` 只是工具入口；项目级 skill 的 canonical 事实源应在 `.Ai-config/skills/<skill-name>/`。

## Codex

当前官方作者路径：

```text
$HOME/.agents/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
<plugin>/skills/<skill-name>/SKILL.md
```

含义：

- `$HOME/.agents/skills`：用户级 / 全局 skill。
- `.agents/skills`：项目级 skill 的 Codex 发现入口。
- plugin 内 `skills/`：可分发插件中的 skill。

对 `project-ai-config-hub` 创建或修复的目标项目，`.agents/skills/<skill-name>/SKILL.md` 只是工具入口；项目级 skill 的 canonical 事实源应在 `.Ai-config/skills/<skill-name>/`。

## Grok Build

官方路径（本机 `~/.grok/docs/user-guide`）：

```text
~/.grok/AGENTS.md
~/.grok/skills/<skill-name>/SKILL.md
~/.grok/config.toml
.grok/skills/<skill-name>/SKILL.md
.grok/config.toml
AGENTS.md / Claude.md / CLAUDE.md   # 项目目录链指令文件
```

含义：

- `~/.grok/skills`：用户级 / 全局 skill（Hub 原生分发目标）。
- `.grok/skills`：项目级 skill 的 Grok 发现入口。
- `~/.grok/config.toml` / `.grok/config.toml`：MCP 等；项目级只贡献 mcp/plugins/permission。
- 项目规则优先用仓库根 `AGENTS.md`（及兼容的 `CLAUDE.md`），不强制 `.grok/rules`。

对 `project-ai-config-hub` 创建或修复的目标项目，`.grok/skills/<skill-name>/SKILL.md` 只是工具入口；canonical 事实源仍在 `.Ai-config/skills/<skill-name>/`。Grok 还会扫描 `.agents/skills` 与（compat 开启时）`.claude/skills`，但 Hub 主路径是 `.grok/skills`，不要把 Claude/Codex 目录当作 Grok 唯一入口。

全局 Grok surface 与 compat 策略见仓库 `docs/grok-build-surface.md` 与 `docs/decisions/0001-grok-first-class-target.md`。

## OpenCode

官方配置和 skill 发现路径：

```text
~/.config/opencode/opencode.json
~/.config/opencode/AGENTS.md
~/.config/opencode/skills/<skill-name>/SKILL.md
.opencode/skills/<skill-name>/SKILL.md
opencode.json
```

含义：

- `~/.config/opencode/opencode.json`：用户级 provider、model、permission、tools、MCP 和其他运行配置。
- `~/.config/opencode/AGENTS.md`：用户级 OpenCode 指令入口。
- `~/.config/opencode/skills`：用户级原生 skill 发现目录。
- `.opencode/skills`：项目级原生 skill 发现目录；项目配置也可通过根目录 `opencode.json` 覆盖全局设置。
- OpenCode 还会发现 `~/.claude/skills`、`~/.agents/skills` 以及对应项目级兼容目录，但 Hub 以 `~/.config/opencode/skills` 和 `.opencode/skills` 作为 OpenCode 主路径。

MCP 只写入 OpenCode `opencode.json` 的 `mcp` 节；不要把 Claude Code 的 `.claude.json` 或 Codex 的 `config.toml` 当作 OpenCode MCP 事实源。

对 `project-ai-config-hub` 创建或修复的目标项目，`.opencode/skills/<skill-name>/SKILL.md` 只是工具入口；canonical 事实源仍在 `.Ai-config/skills/<skill-name>/`。

## 历史兼容路径

部分既有项目或本机环境可能存在：

```text
.codex/skills/<skill-name>/SKILL.md
C:\Users\sx200\.codex\skills\<skill-name>\SKILL.md
```

这些路径可以用于兼容已有项目或当前本机实测环境，但不能写成当前 Codex 官方作者路径。新项目默认应生成 `.agents/skills`，并在启用 Grok 时同时生成 `.grok/skills`。历史 `.codex/skills/<skill-name>/SKILL.md` 也只是兼容入口，不作为长期事实源。

## Symlink / 软链接

Codex 官方文档说明支持 symlinked skill folders。Claude Code / Grok 侧和 Windows 权限行为不应在未实测前假设等价。

本项目 v1 默认采用实体化复制：

- 本仓库维护的全局 managed skill 共享源保存在 `skills/shared/`。
- 渲染后复制到 `skills/rendered/`。
- 同步时复制到真实全局 skill 目录。

这样更容易审计、备份和回滚。

## 目标项目的 canonical 事实源

上述 Claude Code / Codex / Grok / OpenCode 路径是工具发现路径，不等于项目级 skill 的事实源路径。由 `project-ai-config-hub` 创建或修复的普通目标项目中，项目级 skill 的 durable 规则、workflow、checklists、references 和 templates 应统一维护在：

```text
.Ai-config/skills/<skill-name>/
```

工具入口可以引用这个目录，但不要把完整规则散落在 `.claude/skills`、`.agents/skills`、`.grok/skills`、`.opencode/skills`、`.codex/skills`、README、docs 或脚本说明里。本仓库自身的 `skills/shared/<skill-name>/` 是全局 managed skill 分发源，是和目标项目项目级 skill 不同的管线。

# 官方路径和兼容边界

最后核验时间：2026-05-08

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

## 历史兼容路径

部分既有项目或本机环境可能存在：

```text
.codex/skills/<skill-name>/SKILL.md
C:\Users\sx200\.codex\skills\<skill-name>\SKILL.md
```

这些路径可以用于兼容已有项目或当前本机实测环境，但不能写成当前 Codex 官方作者路径。新项目默认应生成 `.agents/skills`。历史 `.codex/skills/<skill-name>/SKILL.md` 也只是兼容入口，不作为长期事实源。

## Symlink / 软链接

Codex 官方文档说明支持 symlinked skill folders。Claude Code 侧和 Windows 权限行为不应在未实测前假设等价。

本项目 v1 默认采用实体化复制：

- 本仓库维护的全局 managed skill 共享源保存在 `skills/shared/`。
- 渲染后复制到 `skills/rendered/`。
- 同步时复制到真实全局 skill 目录。

这样更容易审计、备份和回滚。

## 目标项目的 canonical 事实源

上述 Claude Code / Codex 路径是工具发现路径，不等于项目级 skill 的事实源路径。由 `project-ai-config-hub` 创建或修复的普通目标项目中，项目级 skill 的 durable 规则、workflow、checklists、references 和 templates 应统一维护在：

```text
.Ai-config/skills/<skill-name>/
```

工具入口可以引用这个目录，但不要把完整规则散落在 `.claude/skills`、`.agents/skills`、`.codex/skills`、README、docs 或脚本说明里。本仓库自身的 `skills/shared/<skill-name>/` 是全局 managed skill 分发源，是和目标项目项目级 skill 不同的管线。

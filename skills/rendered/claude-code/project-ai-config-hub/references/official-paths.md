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
- `.claude/skills`：项目级 skill。
- plugin 内 `skills/`：可分发插件中的 skill。

## Codex

当前官方作者路径：

```text
$HOME/.agents/skills/<skill-name>/SKILL.md
.agents/skills/<skill-name>/SKILL.md
<plugin>/skills/<skill-name>/SKILL.md
```

含义：

- `$HOME/.agents/skills`：用户级 / 全局 skill。
- `.agents/skills`：项目级 skill。
- plugin 内 `skills/`：可分发插件中的 skill。

## 历史兼容路径

部分既有项目或本机环境可能存在：

```text
.codex/skills/<skill-name>/SKILL.md
C:\Users\sx200\.codex\skills\<skill-name>\SKILL.md
```

这些路径可以用于兼容已有项目或当前本机实测环境，但不能写成当前 Codex 官方作者路径。新项目默认应生成 `.agents/skills`。

## Symlink / 软链接

Codex 官方文档说明支持 symlinked skill folders。Claude Code 侧和 Windows 权限行为不应在未实测前假设等价。

本项目 v1 默认采用实体化复制：

- 共享源保存在 `skills/shared/`。
- 渲染后复制到 `skills/rendered/`。
- 同步时复制到真实全局 skill 目录。

这样更容易审计、备份和回滚。

# 项目级 Skills 清单

最后更新时间：2026-10-15

| Skill | 状态 | 完整包事实源 | Claude 导出 | `.agents/skills` 导出 | 备注 |
|---|---|---|---|---|---|
<!-- 本表是索引，不是内容源。每个完整包只在 `skills/shared/<name>/` 维护；两个导出目录由同一包生成。 -->
<!-- `.agents/skills` 是部分客户端支持的发现路径，不是 Agent Skills 规范定义的路径；Claude 使用自己的发现目录。 -->
<!-- OpenCode 也扫描 `.claude/skills`；同名双导出时需在其进程环境关闭 Claude Skills 兼容扫描，见 project-ai-config-hub 的 official-paths.md。 -->
| project-ai-config-hub | active | `skills/shared/project-ai-config-hub/` | `skills/rendered/claude-code/project-ai-config-hub/` | `skills/rendered/codex/project-ai-config-hub/` | 项目级状态/索引维护 skill；项目目标包默认位于 `.agents/skills/<name>/`，`.Ai-config` 只登记路径。 |
| global-frontend-design | active | `skills/shared/global-frontend-design/` | `skills/rendered/claude-code/global-frontend-design/` | `skills/rendered/codex/global-frontend-design/` | 前端设计领域 skill；来源归档见 `.Ai-config/archive/global-frontend-design-sources/`。 |
| global-thinking-partner | active | `skills/shared/global-thinking-partner/` | `skills/rendered/claude-code/global-thinking-partner/` | `skills/rendered/codex/global-thinking-partner/` | 可组合 reasoning mode；行为评测见 `skills/evals/global-thinking-partner/`。 |
| global-context-thread | active | `skills/shared/global-context-thread/` | `skills/rendered/claude-code/global-context-thread/` | `skills/rendered/codex/global-context-thread/` | 关系检索工具路由 skill；CLI 调用契约在包内 `workflow.md`。 |
| pencil-design-workflow | deprecated | - | - | - | 已退役；`sync-skills.ps1 -Apply` 只删除能够确认归属的用户级托管副本。 |

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：完整包和仓库内导出已启用；用户级安装状态不由本表暗示。
- `partial`：部分可用。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

## 维护约定

本表只登记本仓库维护的全局 package 和 adapter 输出。事实源在 `skills/shared/<skill-name>/`，`render-skills.ps1` 将同一完整包导出到两种发现路径；用户级安装是可选的后续部署操作。

普通目标项目新增项目级 skill 时，默认完整包放在 `.agents/skills/<skill-name>/`；这里是本项目的目录约定，也被 Codex/OpenCode 等支持，不能泛化成开放规范要求。Claude 入口由相同 package 导出到 `.claude/skills/`。`.Ai-config/skills-registry.md` 只记录路径、适配和状态，不保存 Skill 内容。

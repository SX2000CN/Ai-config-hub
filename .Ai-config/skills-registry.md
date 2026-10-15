# Managed Agent Skill 包索引

最后更新时间：2026-10-15

<!-- 本表是索引，不是内容源。每个完整包只在 `.agents/skills/<name>/` 维护；支持该发现路径的客户端直接读取本体。 -->
<!-- `.agents/skills` 是部分客户端支持的发现路径，不是 Agent Skills 规范定义的路径；Claude adapter 当前暂停。 -->
<!-- OpenCode 也扫描 `.claude/skills`；需要隔离同名重复发现。目标版本若提供关闭兼容扫描的开关，按该版本核验后在 adapter 层配置，见 project-ai-config-hub 的 official-paths.md。 -->

| Skill | 状态 | 完整包事实源 | Claude adapter | 当前发现路径 | 备注 |
|---|---|---|---|---|---|
| project-ai-config-hub | active | `.agents/skills/project-ai-config-hub/` | deferred | `.agents/skills/project-ai-config-hub/` | 项目级状态/索引维护 Skill；`.Ai-config` 只登记路径。 |
| global-frontend-design | active | `.agents/skills/global-frontend-design/` | deferred | `.agents/skills/global-frontend-design/` | 前端设计领域 Skill；来源归档见 `.Ai-config/archive/global-frontend-design-sources/`。 |
| global-thinking-partner | active | `.agents/skills/global-thinking-partner/` | deferred | `.agents/skills/global-thinking-partner/` | 可组合 reasoning mode；行为评测见 `skills/evals/global-thinking-partner/`。 |
| global-context-thread | active | `.agents/skills/global-context-thread/` | deferred | `.agents/skills/global-context-thread/` | 关系检索工具路由 Skill；CLI 调用契约在包内 `workflow.md`。 |
| pencil-design-workflow | deprecated | - | - | - | 已退役；`sync-skills.ps1 -Apply` 只删除能够确认归属的用户级托管副本。 |

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：完整包位于当前发现路径；用户级安装状态不由本表暗示。
- `partial`：部分可用。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

## 维护约定

本表只登记本仓库维护的全局 package 和当前发现路径。事实源在 `.agents/skills/<skill-name>/`；客户端支持该路径时直接使用本体，不生成中间副本。Claude adapter 暂停维护。用户级安装是可选的后续部署操作。

普通目标项目新增项目级 skill 时，默认完整包放在项目自己的 canonical source，再按客户端需要导出到 `.agents/skills/<skill-name>/` 或其他发现路径；这里是本项目的目录约定，也被部分客户端支持，不能泛化成开放规范要求。Claude 入口只有在恢复其 adapter 后才导出到 `.claude/skills/`。`.Ai-config/skills-registry.md` 只记录路径、适配和状态，不保存 Skill 内容。

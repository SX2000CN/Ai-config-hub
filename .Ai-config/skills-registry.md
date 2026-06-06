# 项目级 Skills 清单

最后更新时间：2026-05-24

| Skill | 状态 | 事实源 | Claude Code 入口 | Codex 入口 | 备注 |
|---|---|---|---|---|---|
<!-- 本表登记的是本仓库维护并同步到用户级目录的全局 managed skills，因此事实源位于 `skills/shared/<skill-name>/`。普通目标项目的项目级 skill 应使用 `.Ai-config/skills/<skill-name>/` 作为 canonical 事实源。 -->
| project-ai-config-hub | active | `skills/shared/project-ai-config-hub/` | `skills/claude-code/project-ai-config-hub/SKILL.md` | `skills/codex/project-ai-config-hub/SKILL.md` | 本仓库维护并渲染到用户级目录的全局 skill；默认按风险和接手价值轻量启用项目级 AI 配置，不是 `.Ai-config/skills/` 下的新项目入口。 |
| global-frontend-design | active | `skills/shared/global-frontend-design/` | `skills/claude-code/global-frontend-design/SKILL.md` | `skills/codex/global-frontend-design/SKILL.md` | 本仓库维护并渲染到用户级目录的全局前端设计 skill；来源归档见 `.Ai-config/archive/global-frontend-design-sources/`。 |
| global-thinking-partner | active | `skills/shared/global-thinking-partner/` | `skills/claude-code/global-thinking-partner/SKILL.md` | `skills/codex/global-thinking-partner/SKILL.md` | 本仓库维护并渲染到用户级目录的低副作用思维扩展 skill；默认只读、手动触发优先。 |
| global-context-thread | active | `skills/shared/global-context-thread/` | `skills/claude-code/global-context-thread/SKILL.md` | `skills/codex/global-context-thread/SKILL.md` | 本仓库维护并渲染到用户级目录的“脉络”轻量结构化事实层 skill；复杂代码关系优先 context-thread，非代码复杂工作流优先 `.Ai-config` 关系索引，L0/L1 不强制升级。 |
| pencil-design-workflow | active | `skills/shared/pencil-design-workflow/` | `skills/claude-code/pencil-design-workflow/SKILL.md` | `skills/codex/pencil-design-workflow/SKILL.md` | 本仓库维护并渲染到用户级目录的全局 Pencil / .pen / pencli 设计先行轻量闸门 skill；设计请求默认必须走 Desktop/MCP 可视化流程，CLI/headless 细节按需读取，确认后交付 `.pen` 和导出图证据。 |

## 状态说明

- `planned`：计划中，尚未实现。
- `active`：源文件、入口和 rendered 包已启用；若任务卡标记为待同步，则真实用户级目录仍需执行对应 `sync-*.ps1 -Apply`。
- `partial`：部分可用。
- `deprecated`：已废弃。
- `compat`：仅为历史兼容保留。

## 维护约定

本仓库当前表格记录的是全局 managed skills：它们的事实源在 `skills/shared/<skill-name>/`，再由 `render-skills.ps1` 生成 rendered 包并同步到用户级目录。

普通目标项目新增项目级 skill 时，默认且稳定的 canonical 事实源必须放在 `.Ai-config/skills/<skill-name>/`，并在这里记录双端入口和状态。项目既有目录、README、docs、脚本说明或工具入口只能作为迁移来源、支持性引用或兼容入口；不要把它们登记为长期事实源，避免多个互相冲突的事实源。

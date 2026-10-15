# 当前工作状态

更新时间：2026-10-15
当前活动任务：无
整体状态：配置本体已收拢到 `.agents/`；规则和完整 Skill 包从该目录维护，旧 Skill 入口已移除。MCP/runtime/Claude 部署仍保留为可选适配层，本轮没有执行用户级 Apply。

## 一眼看结论

- **配置本体**：跨工具规则与完整 Agent Skill 包是维护目标；客户端路径、MCP、hooks、settings、permissions、runtime 和同步是可选 adapter / 集成层。
- **Skill 唯一源**：每个完整包位于 `.agents/skills/<name>/`；当前只维护 `.agents/skills/` adapter，Claude adapter 暂停。
- **标准边界**：Agent Skills 定义包格式，不规定发现路径；`.agents/skills/` 不是万能配置标准，`when_to_use` 不作为跨工具 frontmatter。
- **项目状态**：目标项目 `.Ai-config/` 保存 CURRENT、任务卡、registry 与结构索引，不保存通用 Skill 内容。
- **旧路径**：`skills/claude-code/` 和 `skills/codex/` 已删除；历史 rendered 根仍是导出物清理候选。
- **默认验证**：普通规则或 Skill 修改使用 `scripts/check-content.ps1`；它不要求 MCP/runtime、用户级配置、hooks、doctor 或用户目录同步。

## 独立历史待确认事项

- [2026-10-02] A/B 实验是否跑、跑多少对；完整 30 对需消耗用户额度，与本轮 package 改造无关。
- [2026-10-02] guard 的端到端拦截是否在真实 Claude Code 会话里验证，属于旧部署任务。
- [2026-07-31] OpenCode 图片上下文曾触发自动压缩；若重新测试图片，应使用新会话。

## 验证与后续

- 2026-10-15：内容检查、PowerShell 5.1 无 profile 检查、隔离临时路径的规则/Skill dry-run 和修复后的同步安全测试通过。验证明细见[任务卡](tasks/2026-10-15-portable-agent-config-source.md)。
- 全量检查仍停在既有的 8 个 Claude/OpenCode MCP rendered 差异，后续 runtime/doctor 步骤未执行。MCP 修复需独立任务；本轮不写真实用户配置。

## 快速接手导航

修改配置本体先读 [README.md](../README.md)、[AI 配置设计](../docs/ai-config-design.md) 与 [架构说明](../docs/architecture.md)；只有涉及本机部署时再读同步流程。

历史部署证据已移至[任务卡](tasks/2026-10-15-portable-agent-config-source.md)，不代表当前验证结果。

## 最近关闭

| 任务卡 | 关闭原因 |
|---|---|
| `.Ai-config/tasks/2026-10-15-portable-agent-config-source.md` | `.agents/` 本体迁移、脚本收敛、文档更新和内容检查完成；MCP/runtime 未纳入本轮 |
| `.Ai-config/tasks/2026-10-02-config-redesign.md` | 由 v2 任务卡接续（结构改动已并入 v2） |
| `.Ai-config/tasks/2026-07-31-opencode-skill-path-convergence.md` | 仓库管线、用户级 Apply 与 OpenCode 独立 discovery 验证全部完成 |
| `.Ai-config/tasks/2026-07-16-ai-config-content-repair.md` | 规则、skills、MCP/runtime、安全与隐私修复、全局 Apply 与重启验收均已完成 |
| `.Ai-config/tasks/2026-07-15-ai-config-hub-hardening.md` | 计划内实现与验证全部完成 |

## 暂停 / 阻塞

- 暂无。

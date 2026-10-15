# 当前工作状态

更新时间：2026-10-15
当前活动任务：可移植 Agent 配置本体优先重构
整体状态：仓库内 package-first 改造与 Skill/规则只读验证已完成；跨管线检查仍被既有 Claude/OpenCode MCP rendered 差异阻断。本轮没有执行用户级 Apply。

## 一眼看结论

- **配置本体**：跨工具规则与完整 Agent Skill 包是维护目标；客户端路径、MCP、hooks、settings、permissions、runtime 和同步是可选 adapter / 集成层。
- **Skill 唯一源**：每个完整包位于 `skills/shared/<name>/`；Claude 与 `.agents/skills` 导出逐文件校验一致。
- **标准边界**：Agent Skills 定义包格式，不规定发现路径；`.agents/skills/` 不是万能配置标准，`when_to_use` 不作为跨工具 frontmatter。
- **项目状态**：目标项目 `.Ai-config/` 保存 CURRENT、任务卡、registry 与结构索引，不保存通用 Skill 内容。
- **旧路径**：`skills/claude-code/`、`skills/codex/`、历史 rendered 根和旧任务卡仅作为迁移 / 清理候选或历史；本轮不自动删除。

## 独立历史待确认事项

- [2026-10-02] A/B 实验是否跑、跑多少对；完整 30 对需消耗用户额度，与本轮 package 改造无关。
- [2026-10-02] guard 的端到端拦截是否在真实 Claude Code 会话里验证，属于旧部署任务。
- [2026-07-31] OpenCode 图片上下文曾触发自动压缩；若重新测试图片，应使用新会话。

## 当前活动任务

- `.Ai-config/tasks/2026-10-15-portable-agent-config-source.md`

## 快速接手导航

修改配置本体先读 [README.md](../README.md)、[AI 配置设计](../docs/ai-config-design.md) 与 [架构说明](../docs/architecture.md)；只有涉及本机部署时再读同步流程。

## 此前部署结果（历史记录，不代表当前目标）

| 事项 | 结果 | 证据 |
|---|---|---|
| 配置理念重构：单源规则 + 强制层 + 过期轴 + 防锈 | 规则 4 份逐字节相同；guard 24 项单测通过；依据表与章节对齐断言；防锈断言含反向用例 | 五步用户级 Apply 全部 exit 0；备份 `backups/{rules,skills,mcp,claude-guard}/20261002-*` |
| skills 分发收敛 | 目标 4→2，Grok 副本退役，`grok inspect --json` 探针实测仍发现 4 个 skill | dry-run 显示 `would remove retired managed target`×4，Apply 后 `~/.agents/skills` 完整 |
| MCP 私有 overlay 与所有权修复 | 代理 env 移出可分发片段；legacy 形态带 env 不再误判冲突 | `~/.claude.json` 的 local-webfetch 已迁为规范形态且 env 保留 |
| A/B 跑道 | 确定性评分器 + `appliesIf` / `held-by-inertia` + 留组 + 座次交换判平 | `ab/score.test.mjs` 7/7 通过 |

## 最近关闭

| 任务卡 | 关闭原因 |
|---|---|
| `.Ai-config/tasks/2026-10-02-config-redesign.md` | 由 v2 任务卡接续（结构改动已并入 v2） |
| `.Ai-config/tasks/2026-07-31-opencode-skill-path-convergence.md` | 仓库管线、用户级 Apply 与 OpenCode 独立 discovery 验证全部完成 |
| `.Ai-config/tasks/2026-07-16-ai-config-content-repair.md` | 规则、skills、MCP/runtime、安全与隐私修复、全局 Apply 与重启验收均已完成 |
| `.Ai-config/tasks/2026-07-15-ai-config-hub-hardening.md` | 计划内实现与验证全部完成 |
| `.Ai-config/tasks/2026-05-18-pencil-design-workflow.md` | 30 天未跟进，功能已交付并同步，视为验证通过 |

## 暂停 / 阻塞

- 暂无。

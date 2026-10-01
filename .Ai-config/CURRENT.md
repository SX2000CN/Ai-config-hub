# 当前工作状态

更新时间：2026-10-02
当前活动任务：配置理念重构与强制层落地
整体状态：五个用户级 Apply 已完成并验收；A/B 跑道已建成，完整实验待跑。

## 一眼看结论

- **规则层单源化**：一个源 + 一个模板，四个工具收到**逐字节相同**的规则（4062 B，1 hash / 4 文件）。工具事实移入按需 reference。
- **强制层从零建立**：Claude Code PreToolUse guard 已部署并注册，边界从散文迁到 hook——这是唯一不会随模型代次腐烂的那一半。
- **过期轴补齐**：`rules/shared/core-rationale.md` 记录每节的失败依据与复核条件；审计触发绑定**模型发布**，不是日历。
- **防锈属性守住**：规则零路径引用（`check-rules-hygiene.ps1` 断言，含反向用例）。
- **世界 brief**：任务卡模板新增「现场」段（意图/观察/约束/未知项/已拍板），方法写在模板里按需加载。
- skills 分发目标 4→2；`~/.grok/skills` 的 Hub 副本已退役（Grok 仍从 `~/.agents/skills` 发现，已用探针实测）。

## 当前待确认

- [2026-10-02] A/B 实验是否跑、跑多少对。跑道与评分器已就绪，完整 30 对需消耗你的额度。
- [2026-10-02] guard 的端到端拦截需在真实 Claude Code 会话里触发一次确认。
- [2026-07-31] OpenCode 图片上下文曾触发自动压缩；测试图片时应使用新会话。

## 当前活动任务

- `.Ai-config/tasks/2026-10-02-config-redesign-v2.md`

## 快速接手导航

改全局规则、skill、同步流程、MCP 接入或理解整体架构，见 [README.md](../README.md) 的"文档层级"和"维护和分发命令"章节；不在本文件重复列出。

## 最近实现结果

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

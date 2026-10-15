# Skills 路线图

本页维护 Skill 包的能力边界和评测状态。完整包遵循 Agent Skills 格式；本地路径和客户端发现方式是单独的 adapter。

## 已实现

- `project-ai-config-hub`：按项目复杂度维护项目状态与配置索引；项目级完整 skill 包默认位于 `.agents/skills/<name>/`，`.Ai-config` registry 只引用包和 adapter。
- `global-frontend-design`：前端设计领域 skill，包含 Design Read、产品/营销双轨、VARIANCE / MOTION / DENSITY、signature 和工程约束。
- `global-thinking-partner`：可组合 reasoning mode；显式请求时多轮探索，隐式触发时静默做健全性检查。
- `global-context-thread`：仅在结构化关系检索能减少搜索成本时路由到 context-thread 或 `.Ai-config` 关系索引。

每个本仓库全局 skill 的唯一内容源为 `skills/shared/<name>/`。`SKILL.md` 的 `description` 承载触发与反触发边界；`skills/evals/` 存放审查样例。不要在工具入口或 `config/managed-assets.psd1` 复制一份运行时路由规则。

## 目录与适配

- `skills/shared/<name>/`：完整 package source。
- `skills/rendered/claude-code/`：Claude Code 路径的导出。
- `skills/rendered/codex/`：`.agents/skills/` 路径的导出。
- `skills/claude-code/`、`skills/codex/`：未接入新 renderer 的旧入口源，保留为清理候选。
- `skills/evals/`：行为与路由样例，不负责自动发现或运行时调度。

Agent Skills 规范不指定发现路径。新增客户端时先核实其当前官方 discovery 行为，再决定是否需要 adapter；不要因为它能读取 `SKILL.md` 就默认它会扫描 `.agents/skills/`。OpenCode 会同时扫描 `.agents/skills/` 和 `.claude/skills/`，因此多客户端导出可能形成重复发现；目标环境必须关闭其中一个发现根，或确保 OpenCode 看不到同名重复包。

## 后续

1. 评估是否将旧入口源迁出维护路径；本轮不自动删除它们。
2. 给共享 package conformance 检查补充边界用例，确保只接受标准字段并发现失效的包内链接。
3. 只有确定新增客户端有实际用户和官方发现行为后，才增加新的导出路径。

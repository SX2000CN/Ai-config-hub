# Skills 路线图

本页维护 Skill 包的能力边界和评测状态。完整包遵循 Agent Skills 格式；本地路径和客户端发现方式是单独的 adapter。

## 已实现

- `project-ai-config-hub`：按项目复杂度维护项目状态与配置索引；项目级完整包由项目自己的 canonical source 维护，`.agents/skills/<name>/` 只是可选发现路径，`.Ai-config` registry 只引用包和 adapter。
- `global-frontend-design`：前端设计领域 skill，包含 Design Read、产品/营销双轨、VARIANCE / MOTION / DENSITY、signature 和工程约束。
- `global-thinking-partner`：可组合 reasoning mode；显式请求时多轮探索，隐式触发时静默做健全性检查。
- `global-context-thread`：仅在结构化关系检索能减少搜索成本时路由到 context-thread 或 `.Ai-config` 关系索引。

每个本仓库全局 Skill 的唯一内容源为 `.agents/skills/<name>/`。`SKILL.md` 的 `description` 承载触发与反触发边界；`skills/evals/` 存放审查样例。不要在工具入口或 `config/managed-assets.psd1` 复制一份运行时路由规则。

## 目录与适配

- `.agents/skills/<name>/`：完整 package source。
- `skills/rendered/`：历史客户端导出候选；当前不生成或检查中间 Skill 副本。
- `skills/claude-code/`、`skills/codex/`：已移除的旧入口目录，不应重新创建。
- `skills/evals/`：行为与路由样例，不负责自动发现或运行时调度。

Agent Skills 规范不指定发现路径。新增客户端时先核实其当前官方 discovery 行为，再决定是否需要 adapter；不要因为它能读取 `SKILL.md` 就默认它会扫描 `.agents/skills/`。Claude Code 不会因为存在 `.agents/` 就自动读取其中的 Skills；需要使用 Claude 时再恢复 `.claude/skills/` adapter。OpenCode 会同时扫描 `.agents/skills/` 和 `.claude/skills/`，因此两者并存可能形成重复发现。

## 后续

1. 评估是否清理历史 `skills/rendered/` 导出；本轮不自动删除它们。
2. 给共享 package conformance 检查补充边界用例，确保只接受标准字段并发现失效的包内链接。
3. 只有确定新增客户端有实际用户和官方发现行为后，才增加新的 adapter。

# Agent 配置本体

`.agents/` 是本仓库唯一的可移植配置内容源。修改规则或 Skill 时，先从这里开始；`skills/rendered/`、`rules/rendered/` 和客户端目录是导出或适配结果，不是事实源。

## 目录

- `rules/`：跨客户端共享的规则内容。`core.md` 是规则源，`core-rationale.md` 只记录维护依据，不分发。
- `skills/<name>/`：完整 Agent Skill 包。每个包至少包含标准 `SKILL.md`，可携带相对 references、templates、workflow 等资源。

Agent Skills 标准定义 Skill 包格式，不规定所有客户端都扫描 `.agents/skills/`。`.agents/skills/` 是 Codex、OpenCode 等客户端采用的发现路径约定；Claude Code adapter 暂停维护，旧导出只保留作迁移参考。

MCP、hooks、permissions、settings、subagents 和 runtime 不属于本目录的通用内容源。它们位于仓库的可选集成层，不能反向决定这里的规则或 Skill 内容。

## 修改与检查

1. 修改 `.agents/rules/` 或 `.agents/skills/` 中的本体内容；规则源变化后运行 `scripts/render.ps1` 更新规则导出。
2. 运行 `scripts/check-content.ps1`，确认规则适配导出、Skill 源包和引用有效；Skill 不生成中间副本。
3. 只有明确需要客户端部署时，才运行对应的 sync 脚本。

不要直接编辑 `skills/rendered/`、`rules/rendered/` 或已删除的旧客户端入口目录。

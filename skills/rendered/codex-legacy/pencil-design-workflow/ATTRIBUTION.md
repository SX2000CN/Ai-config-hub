# 来源和维护边界

本 skill 参考 Pencil CLI 官方 skill，但不是 Pencil 官方发布的 skill。

## 上游参考

- 官方 Pencil CLI skill：`https://unpkg.com/@pencil.dev/cli@latest/SKILL.md`
- npm 包：`@pencil.dev/cli`
- CLI 文档：`https://docs.pencil.dev/for-developers/pencil-cli`

## 本仓库适配内容

本仓库只提炼以下工作流要点：

- Pencil Desktop / MCP 可视化设计模式。
- VS Code / Cursor 插件多窗口风险和谨慎模式。
- Pencil CLI / headless 生成和导出模式。
- Claude Code / Codex 双端 skill 入口。
- 与 `global-frontend-design` 的交接边界。
- Pencil 画布验证、Claude Code 审查和真实浏览器验证的区别。

## 维护规则

当 `@pencil.dev/cli` 升级、CLI 参数变化、认证方式变化或官方 skill 内容变化时，先核对上游，再更新本 skill。

不要把官方 `SKILL.md` 全文复制到本仓库；如需保留快照，应明确标注来源、版本和用途。

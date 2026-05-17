# Pencil 设计先行工作流

`pencil-design-workflow` 是本仓库维护的全局 Pencil / `.pen` / pencli 工作流 skill。它负责把“先做设计图、确认后再写代码”这类自然语言需求路由到合适的 Pencil 工作模式，不替代通用前端实现流程。

## 定位

- 识别设计先行请求：设计图、设计稿、mockup、wireframe、视觉方案、确认后再写代码。
- 选择 Pencil Desktop / MCP、VS 插件谨慎模式或 Pencil CLI / headless。
- 规范 `.pen` 文件和导出图的项目内保存位置。
- 支持 Pencil 设计稿审查、设计到代码的对照审查和涉及 `.pen` / 导出图的 UI diff 审查。
- 在进入真实前端代码实现后，交接给 `global-frontend-design`。

## 包结构

- `workflow.md`：主流程、触发边界和交接规则。
- `references/pencil-modes.md`：Desktop / VS 插件 / CLI 三种模式的选择和操作边界。
- `references/file-locations.md`：`.pen`、导出图和设计资料的保存位置规范。
- `references/verification.md`：Pencil 画布验证、Claude Code 审查和真实浏览器验证的边界。
- `templates/review-report.md`：Pencil 相关设计审查输出模板。
- `ATTRIBUTION.md`：官方 Pencil CLI skill 来源和维护边界。

## 维护规则

官方 Pencil CLI skill 随 `@pencil.dev/cli` npm 包发布。本 skill 只保留当前工作流需要的 CLI 行为要点和本机 Claude Code / Codex 双端适配规则，不直接复制官方全文。

当 CLI 参数、认证方式或官方 skill 行为变化时，先核对：

- `https://unpkg.com/@pencil.dev/cli@latest/SKILL.md`
- `pencil --help`
- `pencil version`

再更新本目录下的 `workflow.md` 和 `references/`。

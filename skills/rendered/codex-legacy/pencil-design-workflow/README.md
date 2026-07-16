# Pencil 设计先行工作流

`pencil-design-workflow` 是本仓库维护的轻量 Pencil / `.pen` / pencli 闸门 skill。它负责把“先做设计图、确认后再写代码”这类自然语言需求默认路由到当前可用的可见 Pencil MCP 宿主，不替代通用前端实现流程。

## 定位

- 识别设计先行请求：设计图、设计稿、mockup、wireframe、视觉方案、确认后再写代码。
- 默认选择当前会话已注入的 VS Code / Cursor 插件端 Pencil MCP，并确认目标 `.pen`；Pencil Desktop 只在用户明确要求重新诊断 Desktop transport 时使用。
- 只有用户明确要求后台、无头、批量、自动化或不看过程时，才选择 Pencil CLI / headless。
- 规范 `.pen` 文件和导出图的项目内保存位置。
- 按需支持 Pencil 设计稿审查、设计到代码的对照审查和涉及 `.pen` / 导出图的 UI diff 审查。
- 在进入真实前端代码实现前，交付 `.pen` 和导出图证据。

## 硬性边界

- 设计请求默认都需要用户可见的 Pencil MCP 画布，不要求用户额外声明“我要看着做”。
- 宿主由运行环境注入，模型不能假装能自由切换 Desktop 和插件端。
- Pencil MCP 不可用、未配置、未连接或无法确认目标画布时，必须停下说明原因和下一步，不得静默降级到 CLI。
- CLI / headless 仅用于用户明确要求后台、无头、批量、自动化或不需要看过程的任务。

## 包结构

- `workflow.md`：默认必读的轻量闸门流程。
- `references/pencil-modes.md`：可见 MCP 宿主、Desktop 客户端、IDE 插件端和诊断边界。
- `references/cli-headless.md`：仅在用户明确要求 CLI/headless 时读取。
- `references/file-locations.md`：`.pen`、导出图和设计资料的保存位置规范。
- `references/verification.md`：Pencil 画布验证、审查和真实浏览器验证的边界。
- `templates/review-report.md`：Pencil 相关设计审查输出模板。
- `ATTRIBUTION.md`：官方 Pencil CLI skill 来源和维护边界。

## 维护规则

官方 Pencil CLI skill 随 `@pencil.dev/cli` npm 包发布。本 skill 只保留当前工作流需要的最小闸门和按需 CLI 要点，不直接复制官方全文。

当 CLI 参数、认证方式或官方 skill 行为变化时，先核对：

- `https://unpkg.com/@pencil.dev/cli@latest/SKILL.md`
- `pencil --help`
- `pencil version`

再更新本目录下的 `workflow.md` 和 `references/`。

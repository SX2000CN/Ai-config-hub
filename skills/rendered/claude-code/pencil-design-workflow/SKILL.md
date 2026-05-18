---
name: pencil-design-workflow
description: 将设计先行请求作为轻量闸门路由到 Pencil Desktop/MCP；仅在用户明确要求无头、批量、后台或不看过程时才进入 Pencil CLI/headless。
when_to_use: 用户要先生成或迭代设计图、设计稿、mockup、wireframe、视觉方案，要求确认设计后再写代码，明确提到 Pencil、pencli、Pencil CLI、.pen、Pencil MCP、Pencil Desktop，或要求审查 Pencil 设计稿/导出图/设计到代码一致性时使用；局部 UI bugfix、已有界面小样式修复、根据已有设计直接写代码时不要使用。
---

# Pencil 设计先行工作流

<!-- ai-config-hub-managed: pencil-design-workflow -->

在需要先生成、迭代、审查或交接 Pencil / `.pen` 设计产物时使用本 skill。它只负责设计先行闸门和 Pencil 工具路由，不替代真实前端实现流程。

默认只读：

1. `workflow.md`

按需再读：

- `references/pencil-modes.md`：需要 MCP 操作边界或 IDE 插件例外时。
- `references/cli-headless.md`：只有用户明确要求 CLI/headless 时。
- `references/file-locations.md`：需要创建或整理长期 `.pen` 产物时。
- `references/verification.md` 和 `templates/review-report.md`：只有审查、对照实现或最终验证汇报需要时。
- `ATTRIBUTION.md`：只有维护上游来源或 CLI 行为变化时。

关键规则：

- 用户说“做设计图”“先做设计”“先设计确认后写代码”等设计先行意图时自动使用，不要求用户显式说 Pencil 或 pencli。
- 局部 UI bugfix、小样式修复、已有界面明确错误修复不使用本 skill。
- 设计请求默认必须使用 Pencil Desktop + MCP 可视化流程；不需要用户额外说“我要看着做”。
- 只有用户明确要求批量、无头、后台、自动化或不需要看过程时，才使用 Pencil CLI / headless。
- Desktop/MCP 不可用、未配置或无法确认当前画布时，必须停下说明，不得静默降级到 CLI。
- `.pen` 文件在 MCP 场景下只通过 Pencil MCP / Pencil 工具链访问，不用普通文本读取工具。
- Pencil Desktop 模式先正常启动 Desktop，等 MCP 连接后再用 `open_document` 打开 `.pen`；不要用 `Pencil.exe <file.pen>` 直接传参打开。
- 设计确认前不进入大规模代码实现；确认后携带 `.pen` 和导出图证据进入真实前端实现流程。
- Pencil 画布验证和导出图检查不能冒充真实浏览器验证；真实网页视觉自检需要 Playwright/浏览器 MCP。

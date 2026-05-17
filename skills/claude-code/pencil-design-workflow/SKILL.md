---
name: pencil-design-workflow
description: 将“做设计图、先做设计确认后写代码”等设计先行请求路由到 Pencil Desktop/MCP、VS 插件谨慎模式或 Pencil CLI/headless，并规范 .pen 产物、审查和交接边界。
when_to_use: 用户要先生成或迭代设计图、设计稿、mockup、wireframe、视觉方案，要求确认设计后再写代码，明确提到 Pencil、pencli、Pencil CLI、.pen、Pencil MCP、Pencil Desktop，或要求审查 Pencil 设计稿/导出图/设计到代码一致性时使用；局部 UI bugfix、已有界面小样式修复、根据已有设计直接写代码时不要使用。
---

# Pencil 设计先行工作流

<!-- ai-config-hub-managed: pencil-design-workflow -->

在需要先生成、迭代、审查或交接 Pencil / `.pen` 设计产物时使用本 skill。它是设计先行路由和 Pencil 工具链工作流，不替代 `global-frontend-design` 的真实前端实现流程。

行动前按需读取：

1. `workflow.md`
2. `references/pencil-modes.md`
3. `references/file-locations.md`
4. `references/verification.md`
5. `templates/review-report.md`（仅当用户要求审查设计稿、对照实现或 PR/UI diff 时）
6. `ATTRIBUTION.md`

关键规则：

- 用户说“做设计图”“先做设计”“先设计确认后写代码”等设计先行意图时自动使用，不要求用户显式说 Pencil 或 pencli。
- 局部 UI bugfix、小样式修复、已有界面明确错误修复不使用本 skill。
- 自然语言“做设计图 / 先做设计”默认视为需要用户看设计过程，优先 Pencil Desktop + MCP；VS 插件只在目标画布明确时谨慎使用。
- 只有用户明确要求批量、无头、自动化或不需要看过程时，才使用 Pencil CLI / headless。
- `.pen` 文件在 MCP 场景下只通过 Pencil MCP / Pencil 工具链访问，不用普通文本读取工具。
- Pencil Desktop 模式应先正常启动 Desktop，等 MCP 连接后再用 `open_document` 打开 `.pen`；不要用 `Pencil.exe <file.pen>` 直接传参打开。
- CLI 模式应使用用户确认过的 prompt，不擅自扩写视觉细节；生成后必须导出图片并展示给用户。
- 设计确认前不进入大规模代码实现；确认进入实现后衔接 `global-frontend-design`。
- 若声明按设计稿实现，必须对照 Pencil 导出图和真实浏览器截图；若只是独立验证夹具，必须提前和最终汇报中说明不是设计稿还原。
- Pencil 画布验证和导出图检查不能冒充真实浏览器验证；真实网页视觉自检需要 Playwright/浏览器 MCP。

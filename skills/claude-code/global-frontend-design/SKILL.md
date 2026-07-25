---
name: global-frontend-design
description: 创建、重设计或审查非简单前端界面时，作为实现领域 skill：Design Read、product/marketing 双轨、三旋钮与一个 signature，落地可维护、可访问、响应式且状态完整的 UI；设计先行用短 UI brief，不依赖 Pencil。
when_to_use: 用户要创建、重设计或 review 前端页面、组件、仪表盘、表单、落地页、布局，或要求提升视觉质量、去 AI 味、可访问性、响应式和状态覆盖时使用；局部 UI bug fix、小样式修复、已有设计直接实现、后端/文档任务不使用。
---

# 全局前端设计

<!-- ai-config-hub-managed: global-frontend-design -->

当前端工作需要**既有题材扎根的审美立场，又能在真实代码库中可靠落地**时，使用这个 skill。它是本仓库维护的顶级前端领域 skill，不是 Anthropic 或 taste-skill 的官方发布物。来源边界见 `ATTRIBUTION.md`。

## 行动前读取（禁止通读全部 references）

1. **必读**：`workflow.md`
2. **lite**（单组件/单页增强、体系内调整）：Design Read 一行 + 旋钮心检后直接最小 diff；可不读 references
3. **full · product**（应用页/仪表盘/表单/设置）：再读 `references/design-principles.md`、`references/product-ui-engineering.md`；旋钮不清时读 `references/design-dials.md`
4. **full · marketing**（落地/品牌/作品集/去 AI 味）：再读 `references/design-principles.md`、`references/anti-slop.md`；出货用 `checklists/preflight-marketing.md`
5. **设计先行**：用户要先看方案时只用 `templates/ui-brief.md`，确认后再实现；不依赖 Pencil 或其他设计 MCP

## 关键规则

- 先 **Design Read**（类型/受众/语气/轨道），再命名方向、设 **VARIANCE / MOTION / DENSITY**，再布局与代码。
- **一个 signature**：只在一处承担可辩护的美学风险，其余纪律化。
- **反触发**：局部 UI bug fix、小样式修复、文字溢出、按钮对齐、已有设计直接实现、后端/文档任务 → 不用本 skill。
- 用户已有设计稿/截图/brief → 按稿实现；没有且方向不清 → 短 UI brief，不要假装已退役设计工具流程。
- 避免无产品语境的泛化 AI / SaaS 模板脸；营销轨加载 anti-slop，产品轨优先状态与密度。
- 优先复用项目组件、token、路由与样式约定，不抹平有价值的视觉主张。
- 可访问性、响应式、状态覆盖与浏览器验证为生产约束（浏览器 MCP 仅任务需要时用）。
- 不新增 UI/动画/图标/字体包或平行 token 系统，除非用户要求或项目已有。
- 不把密钥、凭证、私有 URL、token、密码、API key 或生产数据写入代码或文档。

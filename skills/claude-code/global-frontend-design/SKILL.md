---
name: global-frontend-design
description: 创建、重设计或审查非简单前端界面时，作为实现领域 skill 建立产品化视觉方向并落地可维护、可访问、响应式且状态完整的 UI；设计先行用短 UI brief，不依赖 Pencil。
when_to_use: 用户要创建、重设计或 review 前端页面、组件、仪表盘、表单、落地页、布局，或要求提升视觉质量、可访问性、响应式和状态覆盖时使用；局部 UI bug fix、小样式修复、已有设计直接实现、后端/文档任务不使用。
---

# 全局前端设计

<!-- ai-config-hub-managed: global-frontend-design -->

当前端工作需要既有明确审美立场，又能在真实代码库中可靠落地时，使用这个 skill。

本 skill 是本仓库维护的全局前端设计工作流，不是 Anthropic 官方发布物。来源和许可证边界见 `ATTRIBUTION.md`。

行动前按任务档位读取（禁止无差别通读全部 references）：

1. 必读：`workflow.md`
2. **lite**（单页/组件增强、非品牌重做）：直接实现；可不读 references
3. **full**（新页面/重设计/体系 review）：再读 `references/design-principles.md`、`references/product-ui-engineering.md`，按需 checklists
4. **设计先行**：用户要先看方案时用 `templates/ui-brief.md`，确认后再实现；不依赖 Pencil 或其他设计 MCP

关键规则：

- 先命名视觉方向，再规划布局和代码。
- 反触发：局部 UI bug fix、小样式修复、文字溢出、按钮对齐、已有设计直接实现或后端/文档任务，不使用本 skill。
- 用户已有设计稿/截图/brief 时按稿实现；没有则用短 UI brief，不要假装调用已退役的 Pencil 流程。
- 避免没有产品语境的泛化 AI / SaaS 模板感。
- 优先复用项目已有组件、token、路由和样式约定，但不要抹平有价值的视觉主张。
- 用可访问性、响应式、状态覆盖和浏览器验证作为生产级约束（浏览器 MCP 仅在任务需要时使用）。
- 不新增 UI 库、动画库、图标包、字体包或设计 token 系统，除非用户要求或项目已有。
- 不把密钥、凭证、私有 URL、token、密码、API key 或生产数据写入代码或文档。

---
name: global-frontend-design
description: 创建、重设计或审查非简单前端界面时，先建立鲜明产品化视觉方向，再用现有前端技术栈落地可维护、可访问、响应式且状态完整的 UI。
when_to_use: 用户要创建、重设计或 review 前端页面、组件、仪表盘、表单、落地页、布局，或要求提升视觉质量、可访问性、响应式和状态覆盖时使用；局部 UI bugfix、小样式修复、已有设计直接实现、后端/文档任务不使用。
---

# 全局前端设计

<!-- ai-config-hub-managed: global-frontend-design -->

当前端工作需要既有明确审美立场，又能在真实代码库中可靠落地时，使用这个 skill。

本 skill 是本仓库维护的全局前端设计工作流，不是 Anthropic 官方发布物。来源和许可证边界见 `ATTRIBUTION.md`。

行动前按任务复杂度读取：

1. `workflow.md`
2. `references/design-principles.md`
3. `references/product-ui-engineering.md`
4. 按任务类型读取 `references/`、`templates/`、`checklists/` 中的相关文件

关键规则：

- 先命名视觉方向，再规划布局和代码。
- 反触发：局部 UI bugfix、小样式修复、文字溢出、按钮对齐、已有设计直接实现或后端/文档任务，不使用本 skill。
- 级联边界：本 skill 不自动拉起 Pencil；只有用户明确要求设计图、mockup、wireframe、`.pen` 或先设计确认时，才转交 `pencil-design-workflow`。
- 避免没有产品语境的泛化 AI / SaaS 模板感。
- 优先复用项目已有组件、token、路由和样式约定，但不要抹平有价值的视觉主张。
- 用可访问性、响应式、状态覆盖和浏览器验证作为生产级约束。
- 不新增 UI 库、动画库、图标包、字体包或设计 token 系统，除非用户要求或项目已有。
- 不把密钥、凭证、私有 URL、token、密码、API key 或生产数据写入代码或文档。

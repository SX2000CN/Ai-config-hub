# 前端技术栈适配

在真实代码库中实现前先读本参考。

## 通用规则

优先遵循仓库已有技术栈和约定。不要把 React、Tailwind、shadcn、动画库、图标包或新设计系统强加给没有使用它们的项目，除非用户明确要求。

## React / Next.js

- 保持 server/client component 边界。
- 复用已有共享组件和 hooks。
- 状态尽量靠近拥有它的组件，除非项目已有明确 store 模式。
- 不要把服务端渲染界面无必要地改成客户端组件。
- 尊重现有数据获取和 error boundary 模式。

## Vue / Nuxt

- 遵循项目已有 Composition API 或 Options API 风格。
- 复用已有 composables 和组件命名约定。
- 保持 props/events 清晰，避免隐藏共享可变状态。
- 尊重 Nuxt 路由、布局和 server/client 约定。

## Svelte / SvelteKit

- 使用已有 stores、actions 和组件模式。
- 保持响应式声明可读。
- 尊重 load functions 和路由约定。

## Tailwind CSS

- 使用已有间距、颜色、圆角和排版模式。
- 如果项目已有 variants 或组件抽取，避免超长 class 字符串。
- 不要在 arbitrary values 中发明平行 token 系统。
- 响应式 class 必须有意图，并检查小屏。

## shadcn 风格组件

- 优先使用项目已安装 primitives。
- 未经用户确认，不从外部 registry 添加新组件。
- 弹窗、菜单、Tabs、Popover 和表单优先使用可访问性 primitives。
- variants 与本地约定保持一致。

## 纯 HTML/CSS/JS

- 使用语义 HTML。
- CSS 按组件或区块组织。
- 重复主题值优先用 CSS variables。
- 交互使用渐进增强。

## 依赖规则

新增依赖前确认：

- 项目还没有解决这个需求。
- 用户接受该依赖。
- bundle/runtime 影响值得。
- 许可证和维护风险可接受。

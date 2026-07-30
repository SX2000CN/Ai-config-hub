# 可访问性检查清单

交互 UI、表单、弹窗、菜单、Tabs、导航和状态变化明显的界面使用。详细原则见 [../references/accessibility.md](../references/accessibility.md)。

## 语义

- [ ] 动作用 button。
- [ ] 导航用 link。
- [ ] 标题层级合理。
- [ ] 适合时优先使用原生控件。
- [ ] Landmark、列表和表格在相关场景下有语义。

## 键盘和焦点

- [ ] 所有交互元素都可通过键盘到达。
- [ ] 焦点顺序合理。
- [ ] 焦点指示可见。
- [ ] 弹窗、菜单、Tabs 行为优先沿用已有可访问性 primitives。
- [ ] Escape、Enter、Space、方向键行为符合组件类型。

## 表单和反馈

- [ ] 输入项有可见 label 或 accessible name。
- [ ] 必填字段清楚。
- [ ] 错误靠近字段。
- [ ] 技术栈支持时，错误文本与字段关联。
- [ ] 状态变化、toast 或 alert 不只依赖视觉暗示。

## 视觉可访问性

- [ ] 颜色不是唯一状态提示。
- [ ] 文本对比度合理。
- [ ] 禁用状态仍可理解。
- [ ] 明显动画尊重 reduced-motion 需求。

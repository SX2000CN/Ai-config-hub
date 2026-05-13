# 全局前端设计 Skill

`global-frontend-design` 是本仓库维护的全局前端设计 skill。它把强视觉方向、产品级 UI 工程、可访问性、响应式、状态覆盖和验证结合起来，用于指导页面、组件、表单、仪表盘、落地页、布局打磨和 UI review。

## 包结构

- `SKILL.md`：skill 入口、触发范围和按需读取路由。
- `workflow.md`：视觉方向优先的端到端工作流。
- `references/`：按任务加载的深入参考规则。
- `templates/`：UI brief、实施计划、review 报告和最终汇报模板。
- `checklists/`：修改前、设计质量、可访问性、状态覆盖、响应式和 review 检查清单。
- `ATTRIBUTION.md`：来源、归属和许可证边界。

## 当前状态

当前目录是这个 skill 的共享事实源和维护稿。原始来源快照、许可证和下载记录归档在：

```text
docs/ai/archive/global-frontend-design-sources/
```

这些归档文件用于审计来源，不参与日常 skill 运行。

## 维护规则

- 修改视觉方向、审美判断和“避免泛化 AI UI”时，优先改 `references/design-principles.md`。
- 修改端到端执行顺序时，优先改 `workflow.md`。
- 修改产品信息层级、状态、组件边界或文案规则时，优先改 `references/product-ui-engineering.md`。
- 修改来源归属时，同步检查 `ATTRIBUTION.md` 和归档目录。
- 如果未来要重新打包或同步到用户级目录，应从本目录复制运行包，不要把 archive 中的原始来源文件混入运行包。
- 如需公开分发，必须先重新核对上游许可证和条款。

# 全局前端设计 Skill

`global-frontend-design` 是本仓库维护的**顶级前端领域 skill**：把题材扎根的视觉判断、三旋钮、anti-slop、产品工程门禁、可访问性、响应式、状态覆盖与验证合成一套可渐进加载的工作流。

它服务真实代码库中的页面、组件、表单、仪表盘、落地页、布局打磨与 UI review；**不是**某一家上游 skill 的安装副本。

## 能力摘要

| 能力 | 说明 |
|---|---|
| Design Read | 一行读懂类型、受众、语气、轨道 |
| 双轨 | product（状态/密度/复用）与 marketing（辨识度/anti-slop） |
| 三旋钮 | VARIANCE / MOTION / DENSITY |
| 一个 signature | 只在一处承担可辩护美学风险 |
| 工程门禁 | 复用、不乱加依赖、验证、反触发琐碎修复 |
| 渐进加载 | 禁止通读全部 references |

## 包结构

- `workflow.md`：端到端主流程（必读）
- `references/design-principles.md`：视觉判断主源
- `references/design-dials.md`：三旋钮与预设
- `references/anti-slop.md`：营销/高辨识度防模板
- `references/product-ui-engineering.md`：产品落地
- `references/accessibility.md` / `responsive-state-coverage.md` / `verification.md` / `frontend-stack-patterns.md`
- `templates/ui-brief.md`：设计先行与 full brief
- `checklists/`：设计质量、营销 preflight、a11y、状态、响应式、review
- `ATTRIBUTION.md`：来源与许可证边界

## 维护规则

- 改执行顺序 → `workflow.md`
- 改审美判断 / 题材扎根 / signature → `references/design-principles.md`
- 改旋钮与预设 → `references/design-dials.md`
- 改营销防模板 → `references/anti-slop.md`
- 改产品层级/状态/文案工程 → `references/product-ui-engineering.md`
- 改归属 → `ATTRIBUTION.md` 与归档目录
- 工具入口只放在 `skills/{claude-code,codex,grok}/global-frontend-design/SKILL.md`；payload 以本目录为事实源
- 同步用户级目录前：`render-skills.ps1` → `check-skills.ps1` → `sync-skills.ps1` dry-run；Apply 需用户授权

## 当前状态

共享事实源与维护稿在本目录。历史来源快照说明见：

```text
.Ai-config/archive/global-frontend-design-sources/
```

归档不参与日常 skill 运行。

# global-frontend-design 来源记录

本目录记录 `global-frontend-design` 的上游来源、核验结果和公开分发边界。这里不保存许可证未明的上游完整原文快照，避免再分发风险。Runtime 事实源始终是 `skills/shared/global-frontend-design/`。

## Anthropic `frontend-design`

- 来源仓库：`anthropics/claude-code`
- 上游文件：`plugins/frontend-design/skills/frontend-design/SKILL.md`
- 核验时间：2026-05-13（方法复核 2026-07-24）
- 核验结果：上游 skill frontmatter 写明 `license: Complete terms in LICENSE.txt`；历史查询 skill 目录时 `LICENSE.txt` 曾 404。
- 本项目处理：不归档完整原文；在 `ATTRIBUTION.md` 记录来源与采用方法（题材扎根、一个美学风险、避免模型默认脸、文案即材料等）。

## `jscraik/Agent-Skills` `frontend-ui-design`

- 来源仓库：`jscraik/Agent-Skills`
- 上游文件：`Skills/frontend-ui/frontend-ui-design/SKILL.md`
- 核验时间：2026-05-13
- 核验结果：仓库 `LICENSE` 为 Apache License 2.0。
- 本项目处理：用自有语言重组产品 UI 工程部分，不把上游全文作为运行入口。

## `Leonxlnx/taste-skill`（方法层）

- 来源仓库：https://github.com/Leonxlnx/taste-skill
- 相关 skill：`design-taste-frontend` 等
- 核验时间：2026-07-24
- 核验结果：上游 README 标明 MIT（以仓库 `LICENSE` 为准）。
- 本项目处理：**不** vendoring 其 ~80KB 单文件 skill；在 `design-dials.md` / `anti-slop.md` / workflow 中吸收 Design Read、三旋钮、一致性锁、营销纪律与浓缩 preflight；保留 product 轨道与渐进加载；不强制其技术栈。

## 使用边界

- 本目录是 provenance 记录，不是 runtime source。
- 公开分发前应重新核验各上游当时许可证与条款。
- 2026-07-24 路线 C：hub 重做融合版，定位为系统内顶级前端 skill。

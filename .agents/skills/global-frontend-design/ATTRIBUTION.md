# 来源与归属

整理时间：2026-05-13
重大修订（路线 C 重做）：2026-07-24

本 skill 是为本项目整理的融合版前端工作流，**不是** Anthropic 官方发布物，也**不是** `Leonxlnx/taste-skill` 或 `jscraik/Agent-Skills` 的原样再发布。它吸收多家公开方向的方法，并用本项目规则语言重新组织；强调渐进加载、中文主文、产品/营销双轨与工程门禁。

上游来源、许可证核验结果和下载失败记录可归档到 `.Ai-config/archive/global-frontend-design-sources/`。为降低公开再分发风险，归档不保存许可证未明的上游完整原文。

## 来源 1：Anthropic `frontend-design`

- 组织：Anthropic
- 仓库：`anthropics/claude-code`
- Skill 页面：https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md
- 许可证说明：原 skill frontmatter 写明 `license: Complete terms in LICENSE.txt`（历史核验时 LICENSE 路径曾 404，公开分发前应重核）。
- **采用的方法（自有语言重写）**：题材扎根、鲜明立场、一个可辩护美学风险、避免模型默认「设计脸」、字体/结构/动效有意、自我批判与克制、文案即设计材料、生产级质量地板。

## 来源 2：`frontend-ui-design`

- 作者/仓库：`jscraik/Agent-Skills`
- Skill 页面：https://github.com/jscraik/Agent-Skills/blob/main/Skills/frontend-ui/frontend-ui-design/SKILL.md
- 许可证：历史核验为 Apache-2.0；公开分发前以上游当时条款为准。
- **采用的方法**：产品级 UI、信息层级、可访问性、响应式、状态覆盖、复用结构、最小验证。

## 来源 3：`taste-skill`（Leonxlnx）

- 仓库：https://github.com/Leonxlnx/taste-skill
- 相关 skill：`design-taste-frontend`（及生态中的 redesign / 变体 skill）
- 站点：https://www.tasteskill.dev/
- 许可证：上游 README 标明 MIT（以仓库 `LICENSE` 当时文本为准）。
- **采用的方法（自有语言重写，非全文搬迁）**：Brief / Design Read、三旋钮（VARIANCE / MOTION / DENSITY）、按场景推断而非改文件、anti-slop 默认脸黑名单、主题/强调色/圆角一致性锁、营销布局纪律与浓缩 preflight。
- **明确未原样采用**：单文件超长墙、强制 React/Next/Tailwind/GSAP/特定图标栈、绝对化标点禁令、以及仅面向落地页而排除仪表盘的范围限制。本 skill 用双轨（product / marketing）与渐进 references 替代。

## 使用边界

- 不把本 skill 描述为 Anthropic 或 taste-skill 官方 skill。
- 不把来源内容中的完整长文档复制到业务文档或本 skill 运行包。
- 修改本 skill 时应保留本归属文件，并优先用自己的规则语言表达融合后的工作流。
- 如需公开分发，应重新核对各上游仓库当时的许可证和再分发条款。

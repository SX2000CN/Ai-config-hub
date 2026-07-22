# 来源与归属

整理时间：2026-05-13

本 skill 是为本项目整理的融合版前端工作流，不是 Anthropic 官方发布物，也不是 `jscraik/Agent-Skills` 的原样再发布。它参考了两个来源的能力方向，并用本项目自己的规则语言重新组织。

上游来源、许可证核验结果和下载失败记录已归档到 `.Ai-config/archive/global-frontend-design-sources/`。为降低公开再分发风险，该归档不保存 Anthropic 官方 skill 的完整原文。

## 来源 1：Anthropic `frontend-design`

- 组织：Anthropic
- 仓库：`anthropics/claude-code`
- Skill 页面：https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md
- Raw 下载：https://raw.githubusercontent.com/anthropics/claude-code/main/plugins/frontend-design/skills/frontend-design/SKILL.md
- 目标记录文件：`.Ai-config/archive/global-frontend-design-sources/anthropic-frontend-design-SKILL.md`
- 许可证说明：原 skill frontmatter 写明 `license: Complete terms in LICENSE.txt`。
- 曾尝试下载 skill 目录下 `LICENSE.txt`，当时返回 404；若要公开分发，应重新联网核验。
- 采用的核心方向：鲜明视觉方向、避免泛化 AI UI、生产级前端实现、排版/色彩/动效/空间构图/视觉细节。

## 来源 2：`frontend-ui-design`

- 作者/仓库：`jscraik/Agent-Skills`
- Skill 页面：https://github.com/jscraik/Agent-Skills/blob/main/Skills/frontend-ui/frontend-ui-design/SKILL.md
- Raw 下载：https://raw.githubusercontent.com/jscraik/Agent-Skills/main/Skills/frontend-ui/frontend-ui-design/SKILL.md
- 目标记录文件：`.Ai-config/archive/global-frontend-design-sources/frontend-ui-design-SKILL.md`
- 许可证：2026-05-13 核验仓库 `LICENSE` 为 Apache-2.0；公开分发前以上游仓库当时的许可证为准。
- 采用的核心方向：产品级 UI、信息层级、可访问性、响应式、状态覆盖、复用结构、最小验证。

## 使用边界

- 不把本 skill 描述为 Anthropic 官方 skill。
- 不把来源内容中的完整长文档复制到业务文档中。
- 修改本 skill 时应保留本归属文件，并优先用自己的规则语言表达融合后的工作流。
- 如需公开分发，应重新核对两个上游仓库当时的许可证和再分发条款。

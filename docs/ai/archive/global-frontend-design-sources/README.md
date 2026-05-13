# global-frontend-design 来源记录

本目录记录 `global-frontend-design` 的上游来源、核验结果和公开分发边界。这里不保存 Anthropic 官方 skill 的完整原文快照，避免在未能确认完整许可证条款前把上游文本再分发到公开仓库。

## Anthropic `frontend-design`

- 来源仓库：`anthropics/claude-code`
- 上游文件：`plugins/frontend-design/skills/frontend-design/SKILL.md`
- 核验时间：2026-05-13
- 核验结果：上游 skill frontmatter 写明 `license: Complete terms in LICENSE.txt`；当时通过代理查询 skill 目录内容仅看到 `SKILL.md`，尝试获取 `LICENSE.txt` 返回 404。
- 本项目处理：不归档完整原文；仅在 `skills/shared/global-frontend-design/ATTRIBUTION.md` 中记录来源、采用方向和许可证待核验风险。

## `jscraik/Agent-Skills` `frontend-ui-design`

- 来源仓库：`jscraik/Agent-Skills`
- 上游文件：`Skills/frontend-ui/frontend-ui-design/SKILL.md`
- 核验时间：2026-05-13
- 核验结果：仓库 `LICENSE` 为 Apache License 2.0。
- 本项目处理：本 skill 使用自己的规则语言重组产品 UI 工程部分，不把上游完整文本作为运行时入口。

## 使用边界

- 本目录是 provenance 记录，不是 runtime source。
- runtime source 位于 `skills/shared/global-frontend-design/`。
- 公开分发前仍应重新核验两个上游仓库的当前许可证和条款。

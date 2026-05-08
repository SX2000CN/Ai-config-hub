# 项目级 AI 配置中枢

本目录记录当前项目的 AI 规则、项目级 skills、工具入口和维护约定。

## 目录

- `skills-registry.md`：项目级 skills 清单。
- `skills/`：项目级 skill 事实源。

## 约定

- `docs/ai/skills/<skill-name>/` 是具体 skill 的事实源。
- `.claude/skills/<skill-name>/SKILL.md` 是 Claude Code 工具入口。
- `.agents/skills/<skill-name>/SKILL.md` 是 Codex 工具入口。
- `.codex/skills/<skill-name>/SKILL.md` 只在历史兼容需要时维护。
- 工具入口只做薄入口，不复制完整业务规则。

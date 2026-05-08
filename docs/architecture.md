# 架构说明

`ai-config-hub` 使用纯文本源文件和 PowerShell 脚本管理 AI 编程工具配置。

## 数据流

### 全局规则

```text
rules/shared/core.md
        +
rules/tools/claude-code.md
        +
templates/CLAUDE.md.tpl
        ↓
rules/rendered/CLAUDE.md
        ↓
C:\Users\sx200\.claude\CLAUDE.md
```

```text
rules/shared/core.md
        +
rules/tools/codex.md
        +
templates/AGENTS.md.tpl
        ↓
rules/rendered/AGENTS.md
        ↓
C:\Users\sx200\.codex\AGENTS.md
```

### Skills

```text
skills/shared/project-ai-config-hub/
        +
skills/claude-code/project-ai-config-hub/SKILL.md
        ↓
skills/rendered/claude-code/project-ai-config-hub/
        ↓
C:\Users\sx200\.claude\skills\project-ai-config-hub\
```

```text
skills/shared/project-ai-config-hub/
        +
skills/codex/project-ai-config-hub/SKILL.md
        ↓
skills/rendered/codex/project-ai-config-hub/
        ↓
C:\Users\sx200\.agents\skills\project-ai-config-hub\
```

可选历史兼容目标：

```text
skills/rendered/codex-legacy/project-ai-config-hub/
        ↓
C:\Users\sx200\.codex\skills\project-ai-config-hub\
```

## 设计原则

- 共享规则只写一份，避免 Claude Code 和 Codex 长期漂移。
- 工具专属内容放在 `rules/tools/`，不污染通用规则。
- rendered 文件保留在仓库中，方便审阅最终效果。
- 同步真实全局文件必须显式执行 `sync.ps1 -Apply`。
- Codex 真实 `config.toml` 暂不自动管理，只提供安全示例模板。
- skills 使用 `skills/shared/` 作为事实源，工具目录只放入口源文件。
- skill rendered 包通过 `render-skills.ps1` 生成，不应手工作为长期事实源编辑。
- `project-ai-config-hub` 的 rendered skill 包会带托管标记，便于 `sync-skills.ps1` 区分历史安装和本仓库产物。
- `.codex\skills` 只作为历史兼容目标，Codex 当前官方路径优先使用 `.agents\skills`。

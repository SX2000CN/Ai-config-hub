# 架构说明

`ai-config-hub` 使用纯文本源文件和 PowerShell 脚本管理 AI 编程工具配置。

## 数据流

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

## 设计原则

- 共享规则只写一份，避免 Claude Code 和 Codex 长期漂移。
- 工具专属内容放在 `rules/tools/`，不污染通用规则。
- rendered 文件保留在仓库中，方便审阅最终效果。
- 同步真实全局文件必须显式执行 `sync.ps1 -Apply`。
- Codex 真实 `config.toml` 暂不自动管理，只提供安全示例模板。

# ai-config-hub

`ai-config-hub` 是本机 AI 编程工具配置中枢，用来统一维护 Claude Code、Codex 以及后续其他 AI 编程工具的通用规则、工具专属补充、示例配置和 skills 规划。

当前目标：

- 用 `rules/shared/core.md` 维护一份共享全局规则。
- 用 `rules/tools/` 维护 Claude Code / Codex 专属补充。
- 用模板渲染出 `rules/rendered/CLAUDE.md` 和 `rules/rendered/AGENTS.md`。
- 用脚本检查、预览并安全同步到真实全局配置文件。
- 为后续 shared skills、Claude Code skills、Codex skills 预留目录。

## 目录结构

```text
rules/shared/       通用规则源文件
rules/tools/        工具专属补充
rules/rendered/     渲染后的全局规则文件
templates/          渲染模板和安全示例配置
scripts/            渲染、检查、同步脚本
docs/               架构、同步、安全和 skills 规划文档
skills/             后续 skills 管理区域
private/            本机私有草稿目录，除 README 外默认忽略
```

## 常用命令

在项目根目录运行：

```powershell
.\scripts\render.ps1
.\scripts\check.ps1
.\scripts\sync.ps1 -WhatIf
```

确认 dry-run 结果无误后，才执行：

```powershell
.\scripts\sync.ps1 -Apply
```

## 安全原则

不要把真实 token、私钥、服务器密码、provider URL、机器本地 trusted project、生产凭证写入可追踪文件。需要记录本机私有信息时，优先放入 `private/`，并确认不会提交或公开。

## 当前状态

- 已支持 Claude Code 和 Codex 全局规则的源码化管理。
- 已提供 Codex 安全示例配置模板。
- skills 目录当前只是规划占位，尚未实现自动同步。

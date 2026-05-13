# ai-config-hub

`ai-config-hub` 是本机 AI 编程工具配置中枢，用来统一维护 Claude Code、Codex 以及后续其他 AI 编程工具的通用规则、工具专属补充、示例配置和 skills 规划。

当前目标：

- 用 `rules/shared/core.md` 维护一份共享全局规则。
- 用 `rules/tools/` 维护 Claude Code / Codex 专属补充。
- 用模板渲染出 `rules/rendered/CLAUDE.md` 和 `rules/rendered/AGENTS.md`。
- 用脚本检查、预览并安全同步到真实全局配置文件。
- 用 `skills/` 维护全局 skills，包括 `project-ai-config-hub` 和 `global-frontend-design`。
- 用 `docs/ai/CURRENT.md` 和 `docs/ai/tasks/` 维护 AI 接手入口、多任务状态总览和任务无损接手卡。

## 目录结构

```text
rules/shared/       通用规则源文件
rules/tools/        工具专属补充
rules/rendered/     渲染后的全局规则文件
templates/          渲染模板和安全示例配置
scripts/            规则和 skills 的渲染、检查、同步脚本
docs/               架构、同步、安全和 skills 设计文档
skills/             skills 共享源、工具入口和 rendered 包
private/            本机私有草稿目录，除 README 外默认忽略
```

## 常用命令

在项目根目录运行：

```powershell
.\scripts\render.ps1
.\scripts\check.ps1
.\scripts\sync.ps1
```

skills 管理流程：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
.\scripts\sync-skills.ps1
```

确认 dry-run 结果无误后，按本次修改范围执行对应同步：

```powershell
.\scripts\sync.ps1 -Apply
.\scripts\sync-skills.ps1 -Apply
```

## 安全原则

不要把真实 token、私钥、服务器密码、provider URL、机器本地 trusted project、生产凭证写入可追踪文件。需要记录本机私有信息时，优先放入 `private/`，并确认不会提交或公开。

## 当前状态

- 已支持 Claude Code 和 Codex 全局规则的源码化管理。
- 已提供 Codex 安全示例配置模板。
- 已实现 `project-ai-config-hub` 和 `global-frontend-design` 的全局 skill 源码化、渲染、检查和 dry-run 同步流程。
- 已设计并接入 `docs/ai/CURRENT.md` + `docs/ai/tasks/` 多任务工作状态机制，用于中断、隔天继续、切换任务或切换 AI 编程工具时恢复工作现场。
- `project-ai-config-hub` 的定位是本项目的项目级分身，用来在目标项目中创建和升级 `docs/ai/` AI 配置中枢、工作状态机制和多端项目 skills。
- `global-frontend-design` 的定位是全局前端设计 skill，用来在前端 UI 工作中先建立鲜明视觉方向，再落地可维护、可访问、响应式且状态完整的界面。
- Codex 新 skill 默认同步到 `C:\Users\sx200\.agents\skills\<skill-name>\`；`.codex\skills` 仅作为可选历史兼容目标。

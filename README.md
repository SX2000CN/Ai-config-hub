# ai-config-hub

`ai-config-hub` 是本机 AI 编程工具配置中枢，用来统一维护 Claude Code、Codex 以及后续其他 AI 编程工具的通用规则、工具专属补充、示例配置和 skills 规划。

当前目标：

- 用 `rules/shared/core.md` 维护一份共享全局规则。
- 用 `rules/tools/` 维护 Claude Code / Codex 专属补充。
- 用模板渲染出 `rules/rendered/CLAUDE.md` 和 `rules/rendered/AGENTS.md`。
- 用脚本检查、预览并安全同步到真实全局配置文件。
- 用 `skills/` 维护全局 skills，包括 `project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread` 和 `pencil-design-workflow`。
- 用 `tool-configs/` 维护可分发的工具配置片段，当前用于浏览器视觉验证 MCP 和 脉络 MCP。
- 用 `designs/pencil/` 和 `docs/visual-validation/` 保存设计先行与真实浏览器视觉验证产物。
- 用 `.Ai-config/CURRENT.md` 和 `.Ai-config/tasks/` 维护 AI 接手入口、多任务状态总览和任务无损接手卡。
- 用 `docs/context-thread-scenarios.md` 记录脉络在真实项目中的触发、同步、回退和误用纠正场景。

## 目录结构

```text
rules/shared/       通用规则源文件
rules/tools/        工具专属补充
rules/rendered/     渲染后的全局规则文件
templates/          渲染模板和安全示例配置
scripts/            规则、skills 和 MCP 配置的渲染、检查、同步脚本
docs/               架构、同步、安全、skills 设计文档和视觉验证页面
skills/             skills 共享源、工具入口和 rendered 包
tool-configs/       工具配置片段源文件和 rendered 产物
designs/            Pencil 设计先行产物和导出图
private/            本机私有草稿目录，除 README 外默认忽略
```

## 常用命令

在项目根目录运行：

```powershell
.\scripts\render.ps1
.\scripts\check.ps1
.\scripts\sync.ps1
```

同步前总检查：

```powershell
.\scripts\check-all.ps1
```

skills 管理流程：

```powershell
.\scripts\render-skills.ps1
.\scripts\check-skills.ps1
.\scripts\sync-skills.ps1
```

MCP 配置片段管理流程：

```powershell
.\scripts\sync-context-thread-runtime.ps1
.\scripts\render-mcp.ps1
.\scripts\check-mcp.ps1
.\scripts\sync-mcp.ps1
```

脉络 MCP 使用本仓库源码构建，但运行时分发到用户级目录，不指向当前项目路径。首次使用或引擎源码变更后，先同步全局运行时：

```powershell
.\scripts\sync-context-thread-runtime.ps1 -Apply
```

默认运行时位置：`C:\Users\sx200\.ai-config-hub\mcp\context-thread\`。

脉络索引是项目级事实源，不是全局共享数据库。目标项目需要复杂代码关系分析时，再初始化自己的 `.Ai-config/context-thread/context-thread.db`；MCP 正在运行且 watcher 可用时会自动同步受支持源码变更，否则按需运行 `context-thread sync` 或直接读取当前文件确认。

确认 dry-run 结果无误后，按本次修改范围执行对应同步：

```powershell
.\scripts\sync.ps1 -Apply
.\scripts\sync-skills.ps1 -Apply
.\scripts\sync-mcp.ps1 -Apply
```

## 安全原则

不要把真实 token、私钥、服务器密码、provider URL、机器本地 trusted project、生产凭证写入可追踪文件。需要记录本机私有信息时，优先放入 `private/`，并确认不会提交或公开。

## 当前状态

- 已支持 Claude Code 和 Codex 全局规则的源码化管理。
- 已提供 Codex 安全示例配置模板。
- 已支持浏览器视觉验证 MCP 与 脉络 MCP 的源码化片段、渲染、检查和 dry-run 安全合并同步流程；真实用户级配置需执行 `sync-mcp.ps1 -Apply`。
- 脉络 MCP 的源码维护在 `tools/context-thread-engine/`，运行时由 `scripts/sync-context-thread-runtime.ps1 -Apply` 分发到 `C:\Users\sx200\.ai-config-hub\mcp\context-thread\`，MCP 配置通过 `node` 启动该用户级 runtime，不依赖当前仓库路径或全局 `context-thread` 命令。
- 已用 `docs/visual-validation/current-project-structure.html` 和 `designs/pencil/current-project-structure/` 验证 Pencil 设计先行与真实浏览器 MCP 截图检查链路。
- 已实现 `project-ai-config-hub`、`global-frontend-design`、`global-thinking-partner`、`global-context-thread` 和 `pencil-design-workflow` 的全局 skill 源码化、渲染、检查和 dry-run 同步流程；新增或变更的用户级安装需执行 `sync-skills.ps1 -Apply`。
- 已设计并接入 `.Ai-config/CURRENT.md` + `.Ai-config/tasks/` 多任务工作状态机制，用于中断、隔天继续、切换任务或切换 AI 编程工具时恢复工作现场。
- `project-ai-config-hub` 的定位是本项目的项目级分身，用来在目标项目中创建和升级 `.Ai-config/` AI 配置中枢、工作状态机制和多端项目 skills。
- `global-frontend-design` 的定位是全局前端设计 skill，用来在前端 UI 工作中先建立鲜明视觉方向，再落地可维护、可访问、响应式且状态完整的界面。
- `global-thinking-partner` 的定位是低副作用思维扩展 skill，用来在复杂 coding 决策前扩展方案、挑战假设、识别失败模式并寻找更简单路径。
- `global-context-thread` 的定位是“脉络”轻量结构化事实层 skill，用来在代码关系、配置关系、影响面或复杂工作流关系分析中优先查询 context-thread 或 `.Ai-config` 关系索引，同时保持 L0/L1 小任务不升级。
- `pencil-design-workflow` 的定位是全局 Pencil / `.pen` / pencli 设计先行路由 skill，用来在用户需要先生成或确认设计图时选择 Pencil Desktop/MCP、VS 插件谨慎模式或 CLI/headless 工作流。
- Codex 新 skill 默认同步到 `C:\Users\sx200\.agents\skills\<skill-name>\`；`.codex\skills` 仅作为可选历史兼容目标。

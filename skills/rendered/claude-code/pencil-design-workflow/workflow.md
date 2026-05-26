# Pencil 设计先行闸门

本流程只负责判断和打开 Pencil 设计路径。不要在这里承担真实前端实现；设计确认后输出可交接的 `.pen` 和导出图证据。

## 1. 触发

使用本流程：

- “做设计图 / 设计稿 / mockup / wireframe / 视觉方案”。
- “先做设计 / 先确认设计再写代码 / 先看看效果”。
- 明确提到 Pencil、pencli、Pencil CLI、`.pen`、Pencil MCP、Pencil Desktop。
- 审查 `.pen`、Pencil 导出图，或对照 Pencil 设计检查实现。

不使用本流程：

- 局部 UI bugfix、小样式修复、文字溢出、按钮对齐等明确实现问题。
- 根据已有设计直接写代码，且不需要生成或审查 Pencil 产物。
- 只 review 前端代码或真实网页截图。

## 2. 默认路径

设计请求默认必须走 **当前会话可用的可见 Pencil MCP 宿主**。用户不需要额外说“我要看着做”。

宿主由运行环境注入，不由模型自由选择。当前默认只把 VS Code / Cursor 等插件端作为可见 MCP 宿主；Pencil Desktop transport 在本机长期未稳定成功，暂不作为自动同步或默认工作路径。模型只负责确认当前会话是否真实暴露 Pencil MCP 工具、目标 `.pen` 是否已打开、active editor 是否正确。

把四件事分清楚：

- 宿主来源：当前会话实际注入的是哪个 Pencil MCP server，例如 `--app visual_studio_code`、`--app cursor`。
- 可用工具：当前会话必须真实暴露 Pencil MCP 工具，或 `tools/list` 能看到 `open_document`、`get_editor_state`、`batch_design` 等工具。
- 打开 / 确认文件：用已注入宿主打开目标 `.pen`，再确认当前画布。
- 可见证据：宿主中必须有用户可见的 Pencil 画布；CLI/headless 导出图不能冒充可见过程。

开始设计前必须有可见画布证据：

- 可见 Pencil 宿主已打开目标 `.pen`。
- MCP 能返回当前画布状态、`snapshot_layout` 或截图。
- 或已向用户展示初始画布 / 关键结构 / 导出图。

没有这些证据，不进入设计迭代，也不进入大规模前端实现。

## 3. 允许的例外

- 用户明确要求后台、无头、批量、自动化、CI 或不需要看过程：才可用 CLI/headless，并读取 `references/cli-headless.md`。

Pencil MCP 不可用、未配置、未连接或无法确认画布时，必须停下说明；不得静默降级到 CLI/headless。

## 4. 最小执行

可见 Pencil MCP：

1. 先确认当前会话是否有 Pencil MCP 工具；没有工具时停下说明，不用 CLI 桥接继续设计。
2. 判断当前 MCP 宿主来源；可通过工具命名、进程命令行或 MCP 配置识别 `visual_studio_code`、`desktop` 等 `--app` 目标。
3. 使用 `open_document({ path: "<absolute .pen path>" })` 打开目标 `.pen`；参数名是 `path`，不是 `filePath`。
4. 用 `get_editor_state`、`snapshot_layout` 或截图确认当前 active editor 是目标 `.pen`。
5. 分批迭代，并在关键结构、视觉方向和最终稿阶段给用户看结果。

Desktop 客户端当前不作为默认或自动 fallback。只有用户明确要求重新调试 Desktop 主窗口时，才按 Desktop 细节处理；否则遇到 Desktop 配置应视为需要改回插件端 MCP。Windows 上如果需要拉起真实 Desktop 窗口，普通 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'` 秒退且没有 `pencil-desktop` transport 时，改用 Shell/Explorer 启动：

```powershell
Invoke-Item 'C:\Program Files\Pencil\Pencil.exe'
# 或
explorer.exe 'C:\Program Files\Pencil\Pencil.exe'
```

不要用 `Pencil.exe <file.pen>` 直接传参打开 `.pen`；它不是官方的 app-mode 连接方式。

如果 MCP server 能握手但工具报 `transport not connected to app: desktop`，这表示 server 存在但 Pencil Desktop transport 未连接。此时停止并报告：Desktop 是否有真实窗口、是否存在 `pencil-desktop` transport、`pencil interactive -a desktop -i <file.pen>` 的错误、当前 MCP `--app` 目标；不要反复重试，也不要静默改用 CLI。

`pencil interactive -a <app>` 只能作为诊断或经用户确认的临时桥接；不得默认替代当前会话的 MCP 工具继续设计。

`.pen` 文件在 MCP 场景下只通过 Pencil MCP / Pencil 工具链访问，不用普通文本读取工具。

长期设计产物默认放在 `designs/pencil/<slug>/`；需要具体命名时再读 `references/file-locations.md`。

## 5. 交接

用户确认设计后，如需写真实前端代码：

- 记录 `.pen` 和导出图路径。
- 明确是“按设计稿还原”还是“独立验证 / 同主题探索”。
- 携带设计证据进入真实前端实现流程。
- 不把 Pencil 画布验证说成真实浏览器验证。

审查或验证细节需要时再读 `references/verification.md`。

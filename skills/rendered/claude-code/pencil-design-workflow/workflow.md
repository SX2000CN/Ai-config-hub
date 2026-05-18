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

设计请求默认必须走 **Pencil Desktop + MCP 可视化流程**。用户不需要额外说“我要看着做”。

把三个动作分清楚：

- 启动 Desktop：打开 Pencil 主程序，让它真正显示窗口并暴露 Desktop transport。
- 连接 Desktop：用 Pencil MCP 或 `pencil interactive -a desktop [-i <file.pen>]` 连接正在运行的 Desktop。
- 打开 / 确认文件：在已连接的 Desktop 里打开目标 `.pen`，再确认当前画布。

Windows 上如果普通 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'` 秒退且没有 `pencil-desktop` transport，改用 Shell/Explorer 启动：

```powershell
Invoke-Item 'C:\Program Files\Pencil\Pencil.exe'
# 或
explorer.exe 'C:\Program Files\Pencil\Pencil.exe'
```

开始设计前必须有可见画布证据：

- Desktop 已打开目标 `.pen`。
- MCP 能返回当前画布状态、`snapshot_layout` 或截图。
- 或已向用户展示初始画布 / 关键结构 / 导出图。

没有这些证据，不进入设计迭代，也不进入大规模前端实现。

## 3. 允许的例外

- 用户明确指定当前 VS Code / Cursor 里的 Pencil 画布就是目标：可用 IDE 插件例外模式，先确认 active `.pen`。
- 用户明确要求后台、无头、批量、自动化、CI 或不需要看过程：才可用 CLI/headless，并读取 `references/cli-headless.md`。

Desktop/MCP 不可用、未配置、未连接或无法确认画布时，必须停下说明；不得静默降级到 CLI/headless。

## 4. 最小执行

Desktop/MCP：

1. 正常启动 Pencil Desktop，确认不是只有短暂退出的进程；Windows 下优先用 Shell/Explorer 启动真实桌面窗口。
2. 确认 Desktop transport 已连接；可用 `pencil interactive -a desktop -i <file.pen>` 或 Pencil MCP 做连接检查。
3. 如果已在 MCP 中，使用 `open_document` 打开目标 `.pen`；如果用 interactive app 模式，`-i <file.pen>` 会注入文件路径，不要再把路径传给工具。
4. 用 `get_editor_state`、`snapshot_layout` 或截图确认当前目标画布。
5. 分批迭代，并在关键结构、视觉方向和最终稿阶段给用户看结果。

不要用 `Pencil.exe <file.pen>` 直接传参打开 `.pen`；它不是官方的 app-mode 连接方式。

如果 MCP server 能握手但工具报 `transport not connected to app: desktop`，这表示 server 存在但 Pencil Desktop transport 未连接。此时停止并报告：Desktop 是否有真实窗口、是否存在 `pencil-desktop` transport、`pencil interactive -a desktop -i <file.pen>` 的错误、当前 MCP `--app` 目标；不要反复重试，也不要静默改用 CLI。

`.pen` 文件在 MCP 场景下只通过 Pencil MCP / Pencil 工具链访问，不用普通文本读取工具。

长期设计产物默认放在 `designs/pencil/<slug>/`；需要具体命名时再读 `references/file-locations.md`。

## 5. 交接

用户确认设计后，如需写真实前端代码：

- 记录 `.pen` 和导出图路径。
- 明确是“按设计稿还原”还是“独立验证 / 同主题探索”。
- 携带设计证据进入真实前端实现流程。
- 不把 Pencil 画布验证说成真实浏览器验证。

审查或验证细节需要时再读 `references/verification.md`。

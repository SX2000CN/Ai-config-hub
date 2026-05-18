# Pencil MCP 模式边界

常规设计请求只需要 `workflow.md`。需要 MCP 操作细节或 IDE 插件例外时再读本文件。

## Desktop / MCP 默认模式

规则：

- `.pen` 文件只能通过 Pencil MCP / Pencil 工具链访问，不用普通 `Read`、`Grep` 或文本方式读取。
- 正确顺序是先让 Pencil Desktop 真实运行并显示窗口，再连接 Desktop transport，最后打开或确认目标 `.pen`。
- Windows 上如果 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'` 秒退且没有 `pencil-desktop` transport，改用 `Invoke-Item 'C:\Program Files\Pencil\Pencil.exe'` 或 `explorer.exe 'C:\Program Files\Pencil\Pencil.exe'` 启动真实桌面窗口。
- 推荐连接检查：`pencil interactive -a desktop -i <file.pen>`；进入 shell 后先运行 `get_editor_state({ include_schema: true })`。
- 在 MCP 工具可用时，用 `open_document` 打开目标 `.pen`；MCP server 握手成功不等于 Desktop transport 已连接。
- 不要用 `Pencil.exe <file.pen>` 作为打开方式；它不是官方 app-mode 连接方式，如果运行时把 `.pen` 当脚本解析，可能出现 `Unexpected token ':'` 一类错误。
- 开始设计前必须确认 Desktop/MCP 可用，并取得可见画布证据，例如 MCP 截图、`snapshot_layout`、当前打开文件状态或等价说明。
- 如果 Pencil MCP 未配置、未连接、工具不可用或目标画布无法确认，必须停下说明，不得改用 CLI/headless 继续。
- 如果出现 `transport not connected to app: desktop` 或 `connect ENOENT \\.\pipe\pencil-desktop`，按 Desktop transport 未连接处理：检查 Desktop 是否真实运行、是否有可见窗口、`pencil interactive -a desktop -i <file.pen>` 是否能进入 shell、当前 MCP server 的 `--app` 是否为 `desktop`。
- 开始修改前优先确认当前编辑器状态和目标 `.pen`。
- 结构检查使用 `snapshot_layout`。
- 视觉检查使用 `get_screenshot` 或 `export_nodes`。
- 节点搜索和结构读取使用 `batch_get`。
- 节点创建、更新、移动、删除使用 `batch_design`。
- 设计变量使用 `get_variables` / `set_variables`。
- 大规模设计改动分批执行，先搭结构，再调变量、视觉细节和状态。
- 关键结构、视觉方向和最终稿阶段必须通过截图或导出图让用户看到结果。
- 截图成本较高，只在完整区块、关键状态或最终审查时使用。

## IDE 插件例外模式

适合：

- 用户明确指定当前 VS Code / Cursor 中打开的 Pencil 画布就是目标。
- 用户只需要快速查看或轻量编辑。
- 当前只有一个相关编辑器窗口，或 active `.pen` 能明确确认。

规则：

- 这是 Desktop/MCP 默认路径之外的显式例外，不是自然语言设计请求的默认可视化路径。
- 多 VS Code / Cursor 窗口时，不默认认为 MCP 指向当前可见窗口。
- 在未确认 active `.pen` 前，不执行会修改画布的操作。
- 如果目标画布不明确，建议用户改用 Pencil Desktop 打开目标 `.pen`。
- 不修改 VS 插件、Codex 或 Claude Code MCP 配置，除非用户明确要求并确认风险。

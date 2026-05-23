# Pencil MCP 模式边界

常规设计请求只需要 `workflow.md`。需要 MCP 宿主、Desktop 客户端或 IDE 插件端操作边界时再读本文件。

## 可见 MCP 宿主默认模式

规则：

- `.pen` 文件只能通过 Pencil MCP / Pencil 工具链访问，不用普通 `Read`、`Grep` 或文本方式读取。
- 宿主由当前 AI 工具环境注入，不由模型自由选择；同名 `pencil` server 可能指向 `visual_studio_code`、`desktop` 或其他 app。
- VS Code / Cursor 插件端和 Pencil Desktop 客户端都是有效的可见 MCP 宿主，只要用户能看到画布且 active `.pen` 可以确认。
- 模型能使用的是当前会话暴露的 MCP 工具；用户界面里看到某个 MCP server 不等于当前 agent 已获得对应工具。
- 在 MCP 工具可用时，用 `open_document({ path: "<absolute .pen path>" })` 打开目标 `.pen`；参数名是 `path`，不是 `filePath`。传错参数可能新建 `pencil-new.pen`，造成实际编辑对象错误。
- 直连 MCP 可用性的最小证明：当前会话有 Pencil MCP 工具，或 `tools/list` 返回 `open_document`、`get_editor_state`、`batch_design`；随后 `open_document({ path })` 成功，且 `get_editor_state({ include_schema: true })` 返回的 active editor 是目标 `.pen`。
- MCP server 握手成功不等于宿主 app transport 已连接；能打开文件也不等于 active editor 已确认。
- 不要用 `Pencil.exe <file.pen>` 作为打开方式；它不是官方 app-mode 连接方式，如果运行时把 `.pen` 当脚本解析，可能出现 `Unexpected token ':'` 一类错误。
- 开始设计前必须确认 Pencil MCP 可用，并取得可见画布证据，例如 MCP 截图、`snapshot_layout`、当前打开文件状态或等价说明。
- 如果 Pencil MCP 未配置、未连接、工具不可用或目标画布无法确认，必须停下说明，不得改用 CLI/headless 继续。
- 开始修改前优先确认当前编辑器状态和目标 `.pen`。
- 结构检查使用 `snapshot_layout`。
- 视觉检查使用 `get_screenshot` 或 `export_nodes`。
- 节点搜索和结构读取使用 `batch_get`。
- 节点创建、更新、移动、删除使用 `batch_design`。
- 设计变量使用 `get_variables` / `set_variables`。
- 大规模设计改动分批执行，先搭结构，再调变量、视觉细节和状态。
- 关键结构、视觉方向和最终稿阶段必须通过截图或导出图让用户看到结果。
- 截图成本较高，只在完整区块、关键状态或最终审查时使用。
- `pencil interactive -a <app>` 是 app-mode 桥接，不是 headless CLI；但如果用户明确要求当前会话直连 MCP 工具，它只能用于诊断或经用户确认后的临时桥接。

## VS Code / Cursor 插件宿主

适合：

- 当前会话注入的 `pencil` MCP server 指向 `visual_studio_code`、`cursor` 或同类 IDE app。
- 用户已在 IDE 插件里打开目标 Pencil 画布，或模型能通过 `open_document({ path })` 和 `get_editor_state` 确认目标 `.pen`。

规则：

- 这不是 Desktop 的降级替代，而是同等级的可见 MCP 宿主。
- 多 VS Code / Cursor 窗口时，不默认认为 MCP 指向当前可见窗口。
- 在未确认 active `.pen` 前，不执行会修改画布的操作。
- 如果目标画布不明确，停下说明当前宿主、active editor 和建议动作。
- 不修改 VS 插件、Codex 或 Claude Code MCP 配置，除非用户明确要求并确认风险。

## Desktop 客户端宿主

适合：

- 用户明确要求 Pencil Desktop 主窗口。
- 当前会话注入的 `pencil` MCP server 指向 `desktop`。
- 需要避开 IDE 多窗口路由风险。

规则：

- 正确顺序是先让 Pencil Desktop 真实运行并显示窗口，再连接 Desktop transport，最后打开或确认目标 `.pen`。
- Windows 上如果 `Start-Process 'C:\Program Files\Pencil\Pencil.exe'` 秒退且没有 `pencil-desktop` transport，改用 `Invoke-Item 'C:\Program Files\Pencil\Pencil.exe'` 或 `explorer.exe 'C:\Program Files\Pencil\Pencil.exe'` 启动真实桌面窗口。
- 推荐连接检查：`pencil interactive -a desktop -i <file.pen>`；进入 shell 后先运行 `get_editor_state({ include_schema: true })`。
- 如果出现 `transport not connected to app: desktop` 或 `connect ENOENT \\.\pipe\pencil-desktop`，按 Desktop transport 未连接处理：检查 Desktop 是否真实运行、是否有可见窗口、`pencil interactive -a desktop -i <file.pen>` 是否能进入 shell、当前 MCP server 的 `--app` 是否为 `desktop`。

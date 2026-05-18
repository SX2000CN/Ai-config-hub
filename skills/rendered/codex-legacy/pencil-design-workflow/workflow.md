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

1. 正常启动 Pencil Desktop。
2. 等 MCP / Desktop transport 连接。
3. 用 Pencil MCP `open_document` 打开目标 `.pen`。
4. 用 MCP 状态、`snapshot_layout` 或截图确认画布。
5. 分批迭代，并在关键结构、视觉方向和最终稿阶段给用户看结果。

不要用 `Pencil.exe <file.pen>` 直接传参打开 `.pen`。

`.pen` 文件在 MCP 场景下只通过 Pencil MCP / Pencil 工具链访问，不用普通文本读取工具。

长期设计产物默认放在 `designs/pencil/<slug>/`；需要具体命名时再读 `references/file-locations.md`。

## 5. 交接

用户确认设计后，如需写真实前端代码：

- 记录 `.pen` 和导出图路径。
- 明确是“按设计稿还原”还是“独立验证 / 同主题探索”。
- 携带设计证据进入真实前端实现流程。
- 不把 Pencil 画布验证说成真实浏览器验证。

审查或验证细节需要时再读 `references/verification.md`。

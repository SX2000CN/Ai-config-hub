# Pencil 工作模式

根据用户是否需要实时看设计过程、是否批量生成、是否已有目标画布，选择不同模式。

## Pencil Desktop / MCP 可视化模式

适合：

- 用户用自然语言提出“做设计图 / 先做设计”等设计先行请求，且没有明确说无需看过程。
- 用户需要看到设计过程。
- 用户正在打开或愿意打开 Pencil Desktop。
- 需要读取当前 `.pen`、选区、布局、变量或截图。
- 需要对设计稿做审查或局部迭代。

规则：

- `.pen` 文件只能通过 Pencil MCP / Pencil 工具链访问，不用普通 `Read`、`Grep` 或文本方式读取。
- 正确启动顺序是先正常启动 Pencil Desktop，等 MCP / Desktop transport 可连接后，再用 Pencil MCP `open_document` 打开目标 `.pen`。
- 不要用 `Pencil.exe <file.pen>` 作为打开方式；如果运行时把 `.pen` 当脚本解析，可能出现 `Unexpected token ':'` 一类语法错误。
- 开始修改前优先确认当前编辑器状态和目标 `.pen`。
- 结构检查使用 `snapshot_layout`。
- 视觉检查使用 `get_screenshot` 或 `export_nodes`。
- 节点搜索和结构读取使用 `batch_get`。
- 节点创建、更新、移动、删除使用 `batch_design`。
- 设计变量使用 `get_variables` / `set_variables`。
- 大规模设计改动分批执行，先搭结构，再调变量、视觉细节和状态。
- 关键结构、视觉方向和最终稿阶段必须通过截图或导出图让用户看到结果。
- 截图成本较高，只在完整区块、关键状态或最终审查时使用。

## VS Code / Cursor 插件谨慎模式

适合：

- 用户明确表示当前 VS Code / Cursor 中打开的 Pencil 画布是目标。
- 用户只需要快速查看或轻量编辑。
- 当前只有一个相关编辑器窗口，或 active `.pen` 能明确确认。

规则：

- 多 VS Code / Cursor 窗口时，不默认认为 MCP 指向当前可见窗口。
- 在未确认 active `.pen` 前，不执行会修改画布的操作。
- 如果目标画布不明确，建议用户改用 Pencil Desktop 打开目标 `.pen`。
- 不修改 VS 插件、Codex 或 Claude Code MCP 配置，除非用户明确要求并确认风险。

## Pencil CLI / headless 模式

适合：

- 用户明确要求批量生成多个设计方向。
- 用户明确表示不需要实时看设计过程。
- 自动化、CI、脚本化导出。
- 用户确认没有打开可视化编辑器也可以先生成 `.pen` 和导出图。

不要把 CLI/headless 当作自然语言设计先行请求的默认模式；如果本应可视化设计但编辑器不可用，先告知用户并等待确认是否降级到 CLI。

使用前检查：

```powershell
pencil version
pencil status
```

新建设计：

```powershell
pencil --out <output.pen> --prompt "<用户确认的需求>" --export <output.png> --export-scale 2
```

迭代已有设计：

```powershell
pencil --in <input.pen> --out <output.pen> --prompt "<修改要求>" --export <output.png> --export-scale 2
```

批量任务可使用 `pencil --tasks <tasks.json>`，但任务文件应保存在项目可追踪位置或用户指定位置，不使用临时目录承载长期设计产物。

CLI prompt 原则：

- 把用户确认过的需求传给 Pencil CLI。
- 不擅自扩写视觉风格、布局、颜色或组件细节；Pencil CLI 内置设计 agent 会做创意判断。
- 如果需要把产品约束、品牌方向或状态覆盖写入 prompt，先向用户说明并获得确认。

耗时预期：

- 简单组件：约 1-2 分钟。
- 中等页面或区块：约 2-3 分钟。
- 复杂页面或 dashboard：3-5 分钟以上。

运行 CLI 命令时超时时间至少 10 分钟。完成后读取导出图片并展示给用户。

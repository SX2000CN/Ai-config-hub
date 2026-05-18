# Pencil CLI / Headless

只有用户明确要求后台、无头、批量、自动化、CI 或不需要看过程时才读本文件。

CLI 不是 Desktop/MCP 失败后的自动 fallback。可视化路径失败时，先停下说明并等待用户确认是否改用 CLI。

## 使用前检查

```powershell
pencil version
pencil status
```

如果 `pencil` 未安装、未登录、`status` 不是 Active，或命令连续失败，不要反复重试；报告失败原因并等待用户处理或确认其他路径。

## 命令

新建设计：

```powershell
pencil --out <output.pen> --prompt "<用户确认的需求>" --export <output.png> --export-scale 2
```

迭代已有设计：

```powershell
pencil --in <input.pen> --out <output.pen> --prompt "<修改要求>" --export <output.png> --export-scale 2
```

批量任务可使用 `pencil --tasks <tasks.json>`。任务文件应保存在项目可追踪位置或用户指定位置，不放临时目录。

## Prompt 原则

- 使用用户确认过的需求。
- 不擅自扩写视觉风格、布局、颜色或组件细节。
- 需要补产品约束、品牌方向或状态覆盖时，先向用户说明并确认。

## 汇报

CLI 生成后必须导出图片并展示给用户，同时说明这是 headless 结果，不是用户实时看过的设计过程。

运行 CLI 命令时超时时间至少 10 分钟。

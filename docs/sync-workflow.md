# 同步流程

推荐流程：

1. 修改源文件：
   - `rules/shared/core.md`
   - `rules/tools/claude-code.md`
   - `rules/tools/codex.md`

2. 渲染输出：

```powershell
.\scripts\render.ps1
```

3. 检查生成结果：

```powershell
.\scripts\check.ps1
```

4. 预览同步目标：

```powershell
.\scripts\sync.ps1 -WhatIf
```

5. 确认无误后应用：

```powershell
.\scripts\sync.ps1 -Apply
```

`sync.ps1 -Apply` 会先备份目标文件，再覆盖：

- `rules/rendered/CLAUDE.md` → `C:\Users\sx200\.claude\CLAUDE.md`
- `rules/rendered/AGENTS.md` → `C:\Users\sx200\.codex\AGENTS.md`

## 注意事项

- 不要直接编辑 rendered 文件作为长期源头；应修改 `rules/` 下的源文件。
- 如果手动改过真实全局文件，应先把差异同步回本项目源文件，再重新渲染。
- v1 不自动修改 `C:\Users\sx200\.codex\config.toml`。

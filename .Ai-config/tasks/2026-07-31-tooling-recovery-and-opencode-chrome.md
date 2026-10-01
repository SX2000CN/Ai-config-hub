# 工具链恢复与 OpenCode Chrome DevTools 补齐

状态：已完成
更新时间：2026-07-31

## 目标

- 清理 Codex Desktop 重新写回的 Pencil 与 Playwright MCP，并恢复 Hub 管理的 pinned context-thread / Chrome DevTools。
- 恢复 Claude Code CLI。
- 按 VS Code 同步日志记录恢复被清空的扩展。
- 让 OpenCode 的 `browser-debug` / `full` profile 正式接入 Chrome DevTools MCP。

## 已确认事实

- Codex Desktop 在 Hub Apply 后仍保持运行，并于 13:26 重建 `~/.codex/config.toml`，重新写回退役 MCP 和 `@latest` Chrome 配置。
- Codex Desktop 使用 TOML literal string 重写 Windows 路径，旧 ownership 比较未归一化单双引号，导致 Hub context-thread 被误判为 custom conflict。
- VS Code 1.131 在 2026-07-30 20:08 扫描扩展时发现四个残留目录均缺少 `package.json`，随后把 32 个扩展从 profile 和云同步列表移除；该事件早于本轮 Hub 修改，Hub 脚本不触及 `.vscode`。
- Claude Code 全局 npm/native 安装均缺失；VS Code 残留目录中的官方 `claude.exe 2.1.220` 仍可执行。

## 完成结果

- Chrome DevTools target 已增加 OpenCode，并同步 profile、文档和测试契约；OpenCode `full` 的 context-thread 与 Chrome DevTools 均 connected。
- Codex ownership 已归一化 TOML literal/basic string，测试使用 Codex Desktop 当前写回格式；Codex `full` 当前只保留 Chrome DevTools、context-thread 和内置 node_repl，Pencil/Playwright 均 absent。
- Claude Code 官方 native CLI `2.1.220` 已恢复，`claude doctor` 无安装问题。
- VS Code 同步日志记录的 34 个扩展已全部重装并写回 `extensions.json`；新窗口中 Claude Code、OpenAI、GitLens、Pencil、Python 等扩展宿主均已激活。

## 残留

- `C:\Users\sx200\.vscode\extensions\openai.chatgpt-26.721.41059-win32-x64\` 是未在当前扩展注册表中登记的损坏旧目录，缺少 `package.json`，VS Code 扫描时仍会记录错误。当前登记并激活的是新安装的 OpenAI 扩展；为避免误删用户资产，旧目录未在本任务中删除。
- Claude CLI 已安装，但 `claude doctor` 显示当前未登录 claude.ai；需要使用该账号时由用户执行 `claude auth login`。

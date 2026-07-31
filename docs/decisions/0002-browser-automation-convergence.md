# ADR 0002：浏览器自动化能力收敛

- 状态：Accepted
- 日期：2026-07-31
- 范围：MCP profiles、browser runtime、外部 Playwright CLI skill

## 背景

Hub 同时维护 Playwright MCP 和 Chrome DevTools MCP，普通浏览器操作存在工具 schema、runtime 依赖和 profile 重叠。官方 Playwright CLI 已提供面向 coding agents 的 CLI + skill 路径，适合日常页面操作、截图和测试生成；Chrome DevTools MCP 仍适合性能、Lighthouse、内存和深度调试。

## 决策

1. 退役 Playwright MCP，不再保留 active source、profile 或 runtime 依赖。
2. 普通浏览器自动化使用外部官方 `@playwright/cli@0.1.17` 及其 `claude`/`agents` skills；Hub 不复制或同步该 skill。
3. browser MCP runtime 只固定 `chrome-devtools-mcp@1.6.0`，由 `browser-debug` profile 按需启用。
4. local-webfetch 只交付 Claude Code；context-thread 继续支持四个 target。
5. manifest 保留 Playwright 的精确退役签名，Apply 只删除能够确认归属的历史配置，同名自定义 server 保留。
6. OpenCode 的 managed MCP 面只保留 context-thread；旧 local-webfetch 仅在 ownership 匹配时移除。

## 后果

- active MCP profiles 收敛为 `core`、`code-intel`、`browser-debug`、`full`。
- 日常浏览器操作不再把 Playwright MCP tool schema 常驻注入 agent 上下文。
- Playwright CLI 的版本和官方 skill 安装属于用户级外部依赖，不进入 Hub 的 render/check/sync-skills 管线。
- Chrome DevTools MCP 继续由 Hub runtime 的版本、hash、doctor 和事务同步保护。

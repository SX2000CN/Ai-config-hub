# local-webfetch

本地 WebFetch MCP server，用于补充 Claude Code 内置 `WebFetch` 工具的网络访问限制。

## 用途

Claude Code 的内置 `WebFetch` 工具在 Anthropic 云端服务器发起请求，不经过用户本机网络，因此本机代理（如 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量）和 VPN 虚拟网卡路由都对它无效。

本 server 在用户本机进程中直接发起 HTTP 请求，天然继承本机网络环境，解决这个问题。

## 为什么只给 Claude Code

Codex CLI 本身在本机运行，直接调用本机网络，不存在云端 WebFetch 绕过本机代理/VPN 的问题。因此这个 MCP server 只需要配给 Claude Code。

## 工具

暴露一个 `fetch` 工具（通过 MCP 注册后前缀为 `mcp__local-webfetch__fetch`）：

参数：
- `url`（必填）：http:// 或 https:// 开头的 URL
- `format`：`markdown`（默认）、`text`、`html`
- `timeout`：超时秒数，最大 120s，默认 30s

## 分发

源码维护在本仓库 `tools/local-webfetch/`。运行时由 `scripts/sync-local-webfetch-runtime.ps1 -Apply` 分发到：

```
C:\Users\sx200\.ai-config-hub\mcp\local-webfetch\
```

MCP 配置通过 `node` 启动该用户级 runtime，不依赖本仓库路径。

## 代理支持

server 启动时调用 `setGlobalDispatcher(new EnvHttpProxyAgent())`，让 Node 全局 `fetch` 读取 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量。VPN 虚拟网卡模式走系统路由层，无需额外配置，全局 `fetch` 会自然经过它。

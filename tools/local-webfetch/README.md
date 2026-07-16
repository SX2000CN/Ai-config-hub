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

每一跳请求都会创建独立的 `EnvHttpProxyAgent`，让 `fetch` 读取 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量。VPN 虚拟网卡模式走系统路由层，无需额外配置。

## 安全边界

- 仅允许无凭证的 `http` / `https` URL。
- 每次请求和每一跳重定向前都会解析并检查全部 DNS 结果，拒绝 IPv4 / IPv6 私网、loopback、link-local、保留地址和内部 hostname。
- 重定向由 server 手动处理，最多 5 跳；不会先访问重定向目标再做校验。
- 响应体按流读取，解码前最多接收 5 MB；超限会立即取消读取。
- `timeout` 覆盖 DNS、重定向、响应头、响应体和 dispatcher 清理的完整周期。
- 返回内容会单独标记为不可信外部数据，不能作为系统、开发者或用户指令执行。

目标 hostname 必须能由本机 DNS 解析，即使请求最终通过代理发送；仅能由代理解析的内部域名会被拒绝。显式配置的 HTTP/HTTPS 代理属于本机可信网络边界。直接连接固定使用该跳预先验证过的地址，避免校验和建连之间再次解析目标；代理模式下目标域名通常由代理解析，server 无法验证代理最终连接到的 IP，因此不要把不受信任的代理用于此 MCP。

## 测试

```powershell
npm test
```

测试通过注入 DNS 和 fetch 实现覆盖地址、重定向、流式大小限制与总超时，不访问公网或 localhost。

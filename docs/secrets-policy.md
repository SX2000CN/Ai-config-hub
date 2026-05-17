# 敏感信息策略

本项目默认可以被纳入版本管理，因此不要在可追踪文件中保存真实敏感信息。

## 不应保存的内容

- API token、私钥、访问密钥
- 服务器密码、数据库密码、支付密钥
- 真实 provider URL 或内部网关地址
- 机器本地 trusted project 列表
- 生产环境凭证、cookie、session
- 完整 `~/.claude.json`、完整 `~/.codex/config.toml` 或其他包含私有设置的用户级配置文件
- 浏览器 profile 路径、会话文件、OAuth 状态或可复用登录态

## 推荐做法

- 在模板中使用占位符或说明文字。
- 把真实配置保留在工具自己的本机配置文件中。
- MCP 分发只提交非敏感片段，例如 npm 包名、server 名和必要的非敏感系统环境变量；不要提交完整用户配置。
- 本机私有草稿可放入 `private/`，但默认不应提交或公开。
- 对外分享、截图、归档或开源前，先检查 `templates/`、`rules/`、`docs/` 和 `private/`。

## 检查边界

`scripts/check.ps1` 和 `scripts/check-mcp.ps1` 会做启发式敏感词扫描，但不能保证发现所有密钥。安全责任仍以人工审查为准。

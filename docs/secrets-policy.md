# 敏感信息策略

本项目默认可以被纳入版本管理，因此不要在可追踪文件中保存真实敏感信息。

## 不应保存的内容

- API token、私钥、访问密钥
- 服务器密码、数据库密码、支付密钥
- 私有、内部或含凭证的 provider URL / 网关地址
- 机器本地 trusted project 列表
- 生产环境凭证、cookie、session
- 完整 `~/.claude.json`、完整 `~/.codex/config.toml` 或其他包含私有设置的用户级配置文件
- 浏览器 profile 路径、会话文件、OAuth 状态或可复用登录态

## 推荐做法

- 在模板中使用占位符或说明文字。
- 把真实配置保留在工具自己的本机配置文件中。
- MCP 分发只提交非敏感片段，例如 npm 包名、server 名和必要的非敏感系统环境变量；不要提交完整用户配置。
- 确需本地文件时，只能使用用户明确指定、已验证未跟踪且已忽略、权限受限的位置；不得提交。`private/` 只是默认忽略目录，不等于凭证保险箱。
- 私钥和长期高价值 token 不提供文档落盘例外，优先使用 secret manager、环境变量或系统凭据存储。
- 对外分享、截图、归档或开源前，先检查 `templates/`、`rules/`、`docs/` 和 `private/`。

## 检查边界

`scripts/check-all.ps1` 会统一扫描可追踪的规则、skills、配置、脚本和文档：OpenAI 风格密钥、GitHub token、AWS access key 和 PEM 私钥等高置信度模式会直接使检查失败；普通 `api key`、`token`、`password`、`secret` 赋值文本只给 warning，避免示例和策略文档产生大量误报。

该扫描仍是启发式防线，不能保证发现所有密钥。提交、同步和公开前仍需人工审查实际 diff，真实凭证不得依赖扫描器兜底。

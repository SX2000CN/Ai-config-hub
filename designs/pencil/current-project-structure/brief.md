# Pencil brief：当前项目结构页面

目标：为 `ai-config-hub` 生成一张单页静态文档 dashboard 的设计图，用于验证 Pencil 设计先行工作流，并作为后续真实浏览器页面实现的视觉参考。

页面主题：`ai-config-hub Current Project Structure`

核心内容：

1. 页面应该把 `ai-config-hub` 表达为一个本机 AI 编程工具配置中枢。
2. 展示四条主线：
   - Rules：`rules/shared`、`rules/tools`、`rules/rendered`
   - Skills：`skills/shared`、`skills/claude-code`、`skills/codex`、`skills/rendered`
   - MCP tool configs：`tool-configs/mcp/shared`、`tool-configs/mcp/rendered`、`scripts/render-mcp.ps1`
   - AI status docs：`.Ai-config/CURRENT.md`、`.Ai-config/tasks`
3. 展示通用流水线：source → render → check → dry-run → apply。
4. 页面中需要有状态 badges：
   - global skills synced
   - browser MCP synced
   - .Ai-config active
   - legacy .codex/skills avoided
5. 页面中需要有验证边界说明：
   - Pencil design/export validation
   - real browser MCP screenshot validation
   - script dry-run validation
6. 视觉风格应清晰、现代、偏工程 dashboard，但不要像正式 SaaS 产品首页；这是项目维护者使用的验证页面。
7. 页面要避免展示任何真实 token、provider URL、trusted project、本机私有配置内容或凭证。

输出要求：

- 设计为单页 desktop dashboard。
- 信息层级要清楚，目录结构和验证边界不要混淆。
- 设计稿只用于 Pencil 设计验证，不代表真实浏览器渲染已经通过。

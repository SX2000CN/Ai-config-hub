# UI Brief 模板

新建、大幅重设计、视觉方向不明确，或用户要求**设计先行**时使用。先 Design Read 与方向，再结构和实现。保持短：多数任务 8–20 行正文足够；本模板字段按需删减。

## Design Read

- 一行读法：Reading this as: … for …，… 语气，偏 …；主轨道 product | marketing | hybrid
- 题材（subject）与单一工作（single job）：
- 受众与情境：
- 参考信号（站/截图/竞品/品牌资产）：
- 安静约束（a11y / 合规 / 信任等）：

## 轨道与旋钮

- 主轨道：product / marketing / hybrid（hybrid 时注明分区）
- Dials：VARIANCE= · MOTION= · DENSITY=（理由一句话）
- 命名视觉方向：
- 一个 signature（美学风险）及为何服务题材：
- 刻意避免的 AI / 模板套路：

## 具体视觉动作（3–5）

- 字体：
- 颜色与表面：
- 空间 / 密度：
- 构图：
- 动效 / 细节：

## 目标界面

- 路由 / 组件 / 文件：
- 用户目标与主操作：
- 次操作 / 危险操作：

## 信息架构

1. 主内容：
2. 辅助内容：
3. 元信息：
4. 操作：

## 状态与响应（product 必填；marketing 按需）

- Loading / Empty / Error / Success / Disabled：
- 长内容 / 权限：
- 关键断点行为：

## 可访问性备注

- 键盘路径、label/错误关联、focus、对比度、动效风险：

## 工程约束

- 复用：已有组件 / token / 模式：
- 不新增依赖：是 / 例外（需用户同意）：
- 验证计划：命令 + 浏览器路由：

## 确认闸门

- [ ] 用户确认 brief 后再写实现（设计先行档）
- [ ] 或：brief 仅作实现自检，用户已授权直接落地

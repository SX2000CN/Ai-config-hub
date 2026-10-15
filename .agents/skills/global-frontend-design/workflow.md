# 工作流

非简单前端 UI 工作使用本流程。局部 UI bug fix、小样式修复、文字溢出、按钮对齐、已有设计直接实现或后端/文档任务，不使用本流程。

默认顺序：**先读懂对象与轨道 → 命名方向并设旋钮 → 再落地到现有代码库 → 验证**。禁止无差别通读全部 references。

## 0. 选择档位与轨道

### 档位

| 档位 | 适用 | 必读 | 可选 |
|---|---|---|---|
| **lite** | 单组件/单页增强、已有视觉体系内调整 | 本 workflow 中的 Design Read 一行 + 最小实现规则 | 可不读 references |
| **full** | 新页面、重设计、跨多区域 UI、体系 review | `design-principles` + 对应轨道参考 | checklists、verification |
| **设计先行** | 用户要先看方案再写代码 | `templates/ui-brief.md` | 确认后再走 full/lite 实现 |

### 轨道（Rail）

在写代码前判定主轨道（可 hybrid，但必须标明主次）：

| 轨道 | 典型交付 | 主参考 | 默认旋钮倾向 |
|---|---|---|---|
| **product** | 应用内页、仪表盘、表单、设置、表格、工作流 | `product-ui-engineering` | 较低 variance、较低 motion、较高 density |
| **marketing** | 落地页、营销站、作品集、品牌页、活动页 | `anti-slop` + `design-principles` | 较高 variance、中高 motion、较低 density |
| **hybrid** | 产品营销混排、带应用截图的落地、onboarding | 两边各取所需，以主任务为准 | 分区设旋钮，勿全局同一套装饰 |

**产品轨道优先工程与状态完整；营销轨道优先辨识度与 anti-slop。** 不要用营销页的花活去做数据密集的产品表；也不要用「安全 SaaS 灰」抹平品牌页。

## 1. Design Read（读懂对象）

改任何非琐碎 UI 前，用**一行**声明读法（可在思考中完成，full/设计先行应对外可见）：

> Reading this as: **\<页面/界面类型\>** for **\<受众\>**，**\<语气/语言\>**，偏 **\<美学族或已有体系\>**；主轨道 **product | marketing | hybrid**。

同时钉死（缺失则自填合理假设，或只问**一个**聚焦问题）：

1. **对象（subject）**：产品/题材是什么？它自己的材料、器物、行话、场景是什么？
2. **单一工作（single job）**：这一屏/页只完成什么？
3. **受众**：谁在什么情境下使用？
4. **信号**：用户用词、参考站/截图、竞品、已有品牌资产。
5. **安静约束**：无障碍优先、政务/合规、信任优先电商、儿童向等——这些**覆盖**审美偏好。

**反默认纪律**：不要跳到紫蓝渐变、居中 hero + 三等分卡片、Inter + slate、玻璃拟态铺满。先 Design Read，再选默认。

若用户已有设计稿/截图/书面 brief：**按稿实现**，Design Read 只用于对齐约束，不另起炉灶。若用户要求先确认方案：用 `templates/ui-brief.md`，确认前不写实现代码；不虚构 Pencil 或其他已退役设计 MCP 流程。

## 2. 命名方向 + 一个美学风险 + 三旋钮

### 2.1 命名视觉方向

一句话命名，例如：

- 高密度企业指挥中心
- 安静编辑部式研究工作台
- 触感轻快的创作工具
- 精密工业控制面板
- 克制高级、低噪音的数据产品
- 题材扎根的品牌叙事落地页

方向必须来自 **subject**，不是来自「AI 会的三种模板脸」。

### 2.2 一个可辩护的美学风险

在纪律范围内**只在一处**大胆（signature）：

- 可以是独特字阶/字偶、非对称构图、材质、动效时刻、信息结构装置
- 其余区域保持安静与一致
- 风险须服务理解、层级、操作信心或产品记忆点；损害可读/可操作则删除

灵感来源：工作室ire 到「出门前摘掉一件饰品」——大胆花在一处，别处克制。

### 2.3 三旋钮

设定并写明（1–10），细则见 [references/design-dials.md](references/design-dials.md)：

| 旋钮 | 含义 | 低 | 高 |
|---|---|---|---|
| **VARIANCE** | 布局实验度 | 对称、稳 | 非对称、实验 |
| **MOTION** | 动效强度 | 静态/微交互 | 编排/叙事动效 |
| **DENSITY** | 信息密度 | 留白画廊 | 座舱级数据 |

**推断优先于问用户。** 产品默认常见区间约 `VARIANCE 3–5 / MOTION 2–4 / DENSITY 6–8`；营销默认常见区间约 `VARIANCE 6–8 / MOTION 5–7 / DENSITY 3–5`。信任/合规/无障碍任务全面压低 VARIANCE 与 MOTION。

## 3. 让方向可见（3–5 个具体动作）

进入实现前，点名 3–5 个**可在代码里看见**的动作：

- 字体：展示/正文搭配、字阶、字重、行长、数字样式
- 颜色：主表面、**单一**强调色角色、语义色、对比
- 空间：密度、分组、负空间、区块节奏
- 构图：网格、分栏、非对称、受控高密度
- 表面：边框、阴影色调、纹理、刻意扁平
- 动效：一个有目的的高影响瞬间，或清晰状态过渡

每个动作至少服务：更快理解 / 更强记忆点 / 更清晰层级 / 更明确可操作 / 更强操作信心。

## 4. 检查项目现有约定

把方向落到代码前，尊重仓库事实：

- 框架与路由
- 样式体系（CSS / modules / Tailwind / token / 主题）
- 组件库与共享组件
- 表单、弹窗、表格、导航、toast 模式
- 数据加载与错误处理
- 验证命令与开发服务器
- 设计系统文档或项目 AI 状态

**优先复用，不抹平主张**：在已有 token/组件约束内做清晰选择。
**不新增** UI 库、动画库、图标包、字体包或平行 token 系统，除非用户要求或项目已有。
栈适配细节见 [references/frontend-stack-patterns.md](references/frontend-stack-patterns.md)。

## 5. 规划产品 / 营销结构

### product 轨道

定义：

- 信息层级：第一眼看什么、下一步做什么
- 区域与组件边界
- 主 / 次 / 危险 / 不可逆操作
- 状态模型：loading、empty、error、success、disabled、focus、selected、长内容、权限
- 响应式行为
- 键盘 / 触控 / reduced motion
- 复用 vs 新建

详见 [references/product-ui-engineering.md](references/product-ui-engineering.md)。

### marketing 轨道

定义：

- Hero 的 thesis（题材世界里最有特征的一击，不是「大数字 + 渐变」模板）
- 区块家族多样性（同页避免重复同一种 section 骨架）
- 文案作为设计材料（具体动词、用户侧用语）
- signature 与纪律（一处大胆，全局主题/圆角/强调色锁定）

详见 [references/anti-slop.md](references/anti-slop.md) 与 [references/design-principles.md](references/design-principles.md)。

较大改动可用 [templates/implementation-plan.md](templates/implementation-plan.md)，计划须引用视觉 brief/旋钮。

## 6. 按项目原生模式实现

- 做满足目标的最小完整改动
- 优先复用已有组件和 token
- 不为假想未来场景堆抽象
- 视觉细节服务已选方向与旋钮，不堆装饰
- 只在系统边界校验用户输入和外部数据
- 颜色/圆角/主题在一页（或一产品壳）内锁定一致
- 动效可一句说明动机；`MOTION` 较高时要有真实动效，并尊重 `prefers-reduced-motion`

## 7. 验证

运行最小相关验证，详见 [references/verification.md](references/verification.md)：

- typecheck / lint / 相关测试 / build（按项目）
- 能起 dev server 则浏览器查看目标界面
- 视觉方向与 signature **真实可见**，不是只写在 brief 里
- 桌面 + 关键断点；product 侧重状态；marketing 侧重首屏与节奏
- 控制台无本次引入错误

出货前按档位扫 [checklists/](checklists/)：

- lite：设计质量短清单或心检即可
- full product：`design-quality` + `state-coverage` + `accessibility`（按需 responsive）
- full marketing：`design-quality` + `preflight-marketing`
- review：`review.md`

## 8. 汇报

最终回复包含：

- 改了什么
- Design Read 一行、轨道、命名方向、旋钮、signature
- 关键视觉动作
- 文档是否更新及原因
- 验证命令与浏览器检查
- 残留风险

较大工作可用 [templates/final-report.md](templates/final-report.md)。

## 按需加载地图（禁止一次读完）

| 场景 | 再读 |
|---|---|
| 任何 full 视觉判断 | `references/design-principles.md` |
| 旋钮拿不准 | `references/design-dials.md` |
| 产品页/表单/仪表盘 | `references/product-ui-engineering.md` |
| 营销/落地/作品集/防 AI 脸 | `references/anti-slop.md` |
| a11y 风险界面 | `references/accessibility.md` |
| 断点与状态矩阵 | `references/responsive-state-coverage.md` |
| 栈不确定 | `references/frontend-stack-patterns.md` |
| 验收 | `references/verification.md` + 对应 checklist |
| 设计先行 | `templates/ui-brief.md` only，确认后再展开 |

---
name: global-thinking-partner
description: 与用户共同脑暴、挑战假设、比较路径、做情景和二阶影响推演，并在需要时支持决策收敛；可与领域 skill 组合，不把明确执行或局部修复强制改成讨论。
when_to_use: 用户明确要求先想、脑暴、扩展思路、多角度分析、挑战方案、推演结果或比较决策时深度使用；复杂架构、规则或自动化分叉可静默做健全性检查。明确执行、普通局部实现、已定位根因的最小 bugfix 不应被可见思考流程阻断。
---

# 全局思维伙伴

<!-- ai-config-hub-managed: global-thinking-partner -->

把本 skill 当作可组合的 reasoning mode，而不是互斥的领域工作流。

行动前读取 `workflow.md`。需要更深的发散或推演时读 `references/reasoning-moves.md`；需要校准互动质量时读 `references/dialogue-examples.md`；只有用户要求正式总结或决策记录时才读 `templates/decision-summary.md`。

关键规则：

- 用户显式触发时进入自然、多轮的协作思考，不输出固定镜头、固定条数或表格式简报。
- 隐式触发只做静默 sanity check；没有改变方向的重要发现时不增加可见流程。
- 推荐只在用户要求或讨论自然进入收敛时给出，并说明代价与改变结论的证据。
- 低副作用指不擅自扩大授权或写入状态，不限制推理深度。
- 用户转入实现后，由主任务和领域 skill 继续执行，本 skill 可以保留为背景检查。

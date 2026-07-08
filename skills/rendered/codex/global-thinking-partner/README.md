# global-thinking-partner

`global-thinking-partner` 是低副作用的思维扩展类全局 coding skill。它不负责直接写代码，而是在复杂、不确定或容易过早收敛的任务中，帮助 agent 先扩展方案、挑战假设、识别失败模式，并寻找更简单的实现路径。

## 定位

- 手动触发优先，不自动插入每个任务。
- 只读优先，不主动修改代码、配置、文档或 git 状态。
- 短输出优先，默认给 1-4 条高价值观察（对应选中的镜头数），而不是长篇分析。
- 面向真实工程决策，避免泛泛而谈。

## 适用 / 不适用场景

触发和退出边界以 `references/trigger-boundaries.md` 为唯一权威，本文件不重复列举，避免两处表述漂移。

## 文件说明

- `workflow.md`：核心工作流。
- `references/thinking-lenses.md`：四个主要思维镜头。
- `references/trigger-boundaries.md`：触发和退出边界。
- `templates/thinking-brief.md`：短输出模板。
- `checklists/low-side-effect.md`：低副作用检查清单。

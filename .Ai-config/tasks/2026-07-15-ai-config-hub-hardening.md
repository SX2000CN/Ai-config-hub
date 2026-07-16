# 工作任务：ai-config-hub 全面修复与加固

任务 ID：2026-07-15-ai-config-hub-hardening
创建时间：2026-07-15
更新时间：2026-07-15
状态：已关闭
当前活动：否

## 目标

修复 context-thread 正确性和兼容性缺陷，加固 render/check/sync 与 runtime 部署安全，统一项目规则术语和事实源，并补齐自动化验证与 Windows CI。

## 背景和当前上下文

项目分析确认了 Git 干净切换后索引漏同步、Node 版本声明不一致、搜索过滤语义错误、readOnly 未实现、Apply 缺少原子回滚、配置清单重复和文档状态漂移等问题。用户已确认执行完整治理，但不执行任何用户级 `-Apply`，不提交、不推送。

当前工作树已有未提交改动，涉及 context-thread CLI 调用说明、global-context-thread workflow 和 MCP 未初始化错误提示；这些改动必须保留并纳入最终实现。

## 最近结论

- 已完成引擎、PowerShell 管线、规则/skills 文档、项目状态和 Windows CI 的全面修复。
- context-thread `0.9.5` 与 local-webfetch `1.0.1` 统一支持 Node.js `>=22.19.0 <25.0.0`。
- 所有用户级同步均改为 preflight-first 的 staging/备份/回滚事务，并通过临时 `UserHome` Apply 与失败回滚测试。

## 已确认事实

- context-thread 通过 `git_state_v1` 保存 HEAD 和脏路径基线，覆盖分支切换、提交、撤销和未跟踪删除。
- `check-all.ps1` 已覆盖 render 一致性、三类 check、18 个引擎测试、local-webfetch 语法、同步安全、全部 dry-run、敏感扫描和 `git diff --check`。
- `config/managed-assets.psd1` 是规则、五个 skills、MCP group、runtime 和用户相对路径的统一清单。
- 根 `AGENTS.md` 已作为 Codex 薄入口，根 `CLAUDE.md` 继续作为本仓库项目特例的 canonical 事实源。

## 已尝试 / 已排除

- 已运行现有 context-thread 测试：4 个测试文件、6 个测试通过，但覆盖不足。
- 已确认本机 Node.js 为 v24.15.0。
- npm 在线查询不可用；通过本机 npm 离线缓存确认两个浏览器 MCP 的锁定版本。

## 当前卡点

无，任务已完成并关闭。

## 关系索引

| 对象 | 当前状态 | 依赖 / 影响 | 证据 | 下一步 |
|---|---|---|---|---|
| context-thread engine | 已完成 | 索引、搜索、只读和版本边界已加固 | 8 个测试文件、18 个用例通过 | 按需维护 |
| render/check/sync 管线 | 已完成 | 用户级写入具备 preflight、staging、备份、并发保护和回滚 | `scripts/check-all.ps1` 与同步安全测试通过 | 真实 Apply 仍需用户确认 |
| 规则与 skills | 已完成 | F/V 术语、CLI 路径约束和 rendered 内容一致 | 三类 render/check 通过 | 按 manifest 显式升级 |
| 项目文档和状态 | 已完成 | README、长期文档、CI、CHANGELOG 和接手状态已刷新 | 文档检查与 `git diff --check` 通过 | 无 |

## 下一步最小动作

1. 无；后续若要把 dry-run 中列出的用户级变化实际同步，必须另行确认并执行对应 `-Apply`。

## 验证状态

- 正常 render 三类产物成功，随后 `scripts/check-all.ps1` 完整通过。
- context-thread：8 个测试文件、18 个用例通过；Node 版本边界、Git 状态、过滤交集、只读写拒绝和版本一致性均有回归覆盖。
- PowerShell：Windows PowerShell 5.1 全脚本解析通过；同步安全测试覆盖临时 Home Apply、唯一备份、类型冲突、并发目标、manifest 边界、Pencil 成功替换和失败回滚。
- runtime、规则、skills、MCP 对真实用户目录的 dry-run 均完成，明确列出待更新项但未应用。
- local-webfetch `node --check`、全仓高置信敏感信息扫描和 `git diff --check` 通过；普通 token 文本仅产生预期 warning。

## 残留风险

- 本次按约束未执行真实用户级 `-Apply`；dry-run 显示规则、global-context-thread skill 和 MCP 配置存在待同步差异。
- 后续任何真实 Apply 都会重新运行完整 preflight，并为该次事务创建独立备份。
- Codex MCP 合并器按受控 table section 工作，并非通用 TOML parser；当前生成格式、常见旧格式和行尾注释已有回归覆盖，非常规 quoted table key 或 array-of-table 需先人工整理。

## 相关文件

- `tools/context-thread-engine/`：代码图谱引擎。
- `scripts/`：渲染、检查、同步和 runtime 分发。
- `rules/`、`skills/`、`tool-configs/`：配置事实源和 rendered 产物。
- `docs/`、`README.md`、`CHANGELOG.md`：长期维护文档。

## 不要重复

- 不要执行用户级 `-Apply`。
- 不要 reset、checkout 或覆盖现有未提交改动。
- 不要把旧风险分级术语继续传播到新文档和 rendered skill。

## 关闭依据 / 最终结果

计划内引擎、配置管线、同步安全、文档、版本和 CI 项均已实现；完整预检、隔离 Apply/回滚测试、全部 dry-run 和索引验证通过，且未执行真实用户级 Apply、提交或推送。任务于 2026-07-15 关闭。

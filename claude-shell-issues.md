# Claude Code 双 Shell 环境问题报告

> 来源：在 Windows 11 (PowerShell 5.1 + Git Bash) 环境下使用 Claude Code 进行实际开发任务时记录的系统性问题。
> 日期：2026-07-08

---

## 环境背景

Claude Code 在这台机器上同时挂载了多个"执行"工具，但底层解释器不同：

| 工具 | 底层解释器 | 语法 |
|---|---|---|
| PowerShell 工具 | `powershell.exe`（Windows PowerShell **5.1**） | PowerShell |
| Bash 工具 | Git Bash `/usr/bin/bash` | POSIX sh |
| Monitor 工具 | `/usr/bin/bash`（eval） | POSIX sh |
| 后台任务（run_in_background） | 取决于发起它的工具 | 对应工具的语法 |

这些工具在"发起"和"看结果"上外观几乎一致，但语言不同、报错可见性天差地别。

---

## 问题一：语法混用直接报错（可见，但频繁）

### 现象
模型在 PowerShell 工具里写了 Unix 语法，或在 Bash/Monitor 里写了 PowerShell 语法，导致命令执行失败。

### 实测证据

```
# Bash 里写 PowerShell 赋值
$ $env:FOO = "bar"
→ /usr/bin/bash: line 1: :FOO: command not found

# PowerShell 里用 Unix 命令
> echo "hello" | tail -1
→ tail : The term 'tail' is not recognized as the name of a cmdlet...

# PowerShell 5.1 里用 && 操作符
> echo "x" && echo "y"
→ The token '&&' is not a valid statement separator in this version.
```

### 高频混淆对照表

| 意图 | Bash | PowerShell 5.1 |
|---|---|---|
| 取最后 N 行 | `tail -n N` | `Select-Object -Last N` |
| 条件链（A 成功才执行 B） | `A && B` | `A; if ($?) { B }` |
| 环境变量 | `$VAR` | `$env:VAR` |
| 丢弃错误 | `2>/dev/null` | `2>$null` |
| 文本过滤 | `grep` | `Select-String` |
| 查文件是否存在 | `[ -f file ]` | `Test-Path file` |

### 严重程度
**中**。报错可见，模型能读到并纠正，但反复打断节奏，浪费 turn。

---

## 问题二：Monitor 脚本失败——伪装成"模型卡死"（最高危）

### 现象
Monitor 工具底层用 `/usr/bin/bash` eval 执行脚本。当脚本语法错误（如使用了 PowerShell 语法），脚本**第一行即崩溃**，不产生任何 stdout 事件。模型启动 Monitor 后交出控制权等待"事件通知"，事件永远不来，模型**永久停住**，只能靠用户手动发消息才能唤醒。

### 实测证据

```
# 向 Monitor 传入 PowerShell 语法
script: $x = "test"; while ($true) { Write-Output $x; Start-Sleep 1 }

# Monitor 输出文件内容：
[stderr] /usr/bin/bash: eval: line 1: syntax error near unexpected token `{'
/usr/bin/bash: eval: line 1: `$x = "test"; while ($true) { Write-Output $x; Start-Sleep 1 }'

# 模型行为：
→ 启动 Monitor 后结束发言，进入等待状态
→ 等待事件通知，无任何事件产生
→ 界面上与"模型 API 挂掉/中断"完全无法区分
→ 只有用户手动发消息才能继续
```

### 用户实际体验
> "Monitor / 后台脚本报错我甚至都看不到报错，只以为模型 API 出问题了中断了。"

### 严重程度
**最高**。一个简单的语法错误被放大成"服务故障"的假象，且无任何可见反馈。

---

## 问题三：异步等待模式本身的脆弱性（高危）

### 现象
模型频繁使用"启动后台任务 → 结束发言 → 等通知"模式，即使脚本语法正确，这个模式也有系统性风险：
- 通知慢 → 模型长时间静止，外观像死机
- 通知丢失 / 脚本静默失败 → 模型**永久停住**
- 用户无法判断当前是"正在等"还是"已经死了"

### 本次任务实际发生次数
本次任务中，几乎每个后台任务后模型都只说一句"等待通知"就结束发言，导致反复出现"模型停下不动"的观感。用户多次追问"你在做什么""你是不是上下文满了"。

### 严重程度
**高**。影响用户信任，造成不必要的中断和打扰。

---

## 问题四：后台任务 PATH 环境与前台不一致（中危）

### 现象
前台 PowerShell 会话刷新了 PATH（新安装的 Go/bun），但后台任务（`run_in_background`）启动时继承的是旧环境，新安装的 CLI 工具**在后台任务里找不到**。

### 实测证据

```
# 前台：安装 Go 后刷新 PATH 可以用
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ...
→ go version go1.26.5 windows/amd64  ✓

# 后台任务里直接用 go：
→ go : The term 'go' is not recognized ...  ✗

# 解决：后台任务里用完整路径
& "C:\Program Files\Go\bin\go.exe" ...  ✓
```

### 严重程度
**中**。报错可见，但会导致多次无谓重试。

---

## 改进提议

### 提议 1（最高优先级）：Monitor 脚本语法错误必须同步返回

**现状**：Monitor 脚本 eval 失败时，错误写入 stderr/输出文件，但模型已进入"等待事件"状态，永远不会主动去读该文件。

**建议**：
- Monitor 工具在启动时先做 `bash -n <script>`（仅语法检查），失败则**同步返回错误**给模型，不进入异步等待状态
- 或：区分"脚本启动失败"和"脚本运行中无事件"两种状态，前者立刻通知模型

---

### 提议 2（最高优先级）：约束模型的异步行为——减少无谓等待

在 CLAUDE.md 或系统提示中加入规则：

```
# 关于后台任务与 Monitor
- 短命令（<30s）优先前台同步执行，直接拿结果继续
- 启动后台任务后，不要只说"等待通知"结束发言
  → 应立刻 Read 输出文件，推进至少下一步，或给用户中间进度
- 能用 Read/Glob/Grep 专用工具完成的，不要用 shell
  → 专用工具同步、跨平台、报错立即可见
```

---

### 提议 3（高优先级）：固化双 Shell 语法规则

在 CLAUDE.md 中加入：

```
# 双 Shell 环境（Windows 11）
- PowerShell 工具：powershell.exe 5.1，使用 PowerShell 语法
- Bash 工具 / Monitor：/usr/bin/bash，必须使用 POSIX sh 语法
- Monitor 工具底层是 Bash，绝不传入 PowerShell 代码

PowerShell 5.1 限制：
- 不支持 &&（用 ; if ($?) {} 替代）
- 不支持 tail/grep/head（用 Select-Object/Select-String/Get-Content 替代）
- 没有 /dev/null（用 $null）
```

---

### 提议 4（中优先级）：后台任务 PATH 一致性

在 CLAUDE.md 中加入：

```
# 后台任务环境
- 后台任务不继承刚安装软件的新 PATH
- 刚安装的 CLI 工具，在后台任务里必须用完整可执行路径
- 或：后台任务开头显式刷新 PATH：
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + ...
```

---

### 提议 5（中优先级）：优先专用工具，减少 Shell 依赖

```
# 工具选择优先级
1. 读文件 → Read（不用 cat/Get-Content）
2. 搜文件 → Glob（不用 find/Get-ChildItem -Recurse）
3. 搜内容 → Grep（不用 grep/Select-String）
4. 以上工具搞不定，再用 Shell
→ 专用工具：同步执行、跨平台一致、报错立即在当前 turn 可见
```

---

## 优先级汇总

| # | 问题 | 优先级 | 影响 |
|---|---|---|---|
| 2 | Monitor 脚本失败伪装成模型卡死 | 🔴 最高 | 用户以为服务故障，信任损失大 |
| 3 | 异步等待模式导致模型反复"停住" | 🔴 最高 | 严重影响用户体验和效率 |
| 1 | PowerShell/Bash 语法混用报错 | 🟠 高 | 频繁打断任务节奏 |
| 4 | 后台任务 PATH 环境不一致 | 🟡 中 | 引发无谓重试 |
| 5 | 过度依赖 Shell 替代专用工具 | 🟡 中 | 增加跨平台风险 |

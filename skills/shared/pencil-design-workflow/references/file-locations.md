# Pencil 设计文件位置

Pencil 产物应保存在项目内可持续迭代的位置，不放在临时目录。

## 默认目录

```text
designs/pencil/<slug>/
```

`<slug>` 使用页面、功能或设计对象名称，例如：

- `dashboard`
- `settings-page`
- `landing-page`
- `pricing-section`
- `agent-config-panel`

## 默认文件

```text
designs/pencil/<slug>/design.pen
designs/pencil/<slug>/design-v2.pen
designs/pencil/<slug>/exports/design.png
designs/pencil/<slug>/exports/design-v2.png
```

如果需要记录设计输入，可使用：

```text
designs/pencil/<slug>/brief.md
```

`brief.md` 只记录可公开的设计目标、状态覆盖、用户确认和交接说明，不写真实凭证、生产数据或敏感客户信息。

## 项目已有约定优先

如果目标项目已有以下目录或文档约定，优先遵循项目现有约定：

- `design/`
- `designs/`
- `docs/design/`
- `figma/`
- `assets/design/`

采用项目现有约定时，在回复中说明实际保存位置。

## 不推荐位置

- 不把可交付 `.pen` 长期放在系统临时目录。
- 不把 `.pen` 放进源码组件目录，例如 `src/components/`，除非项目已有明确设计资产约定。
- 不把导出图散落在项目根目录。
- 不把真实密钥、生产账号、客户隐私数据写进设计稿或截图。

## 覆盖和版本

默认使用版本化输出：

- `design.pen`
- `design-v2.pen`
- `design-v3.pen`

只有用户明确要求覆盖，或当前任务明确是原地更新时，才使用相同 `--in` / `--out` 路径覆盖已有 `.pen`。

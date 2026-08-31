# TOOLS.md - 本地说明

各个 Skill 会定义工具的使用方式；这个文件记录只属于你当前环境的具体信息。

---

## 芯片设计工具链

### 编辑器
- **本地代码/文档编辑** — VS Code（本地）

### 图表
- **流程图、状态图和模块图** — 使用自包含 SVG，并通过 Playwright 导出 PNG
  - 输出格式：SVG + PNG 双格式
  - SVG 要求：CSS 嵌入 SVG 内部；颜色使用固定十六进制值（不要使用 CSS 变量）；`viewBox` 应完整覆盖所有内容，避免文字或连线重叠
  - Playwright 浏览器安装：`npx playwright install chromium`
- **时序图** — `wavedrom-cli`
  - 输出格式：PNG，分辨率为 2K（≥ 2560×1440）
  - 输入格式：JSON 格式的 WaveDrom 描述文件

### 文档
- **参考文档（`.docx`）生成** — `pandoc` + `pandoc-crossref`
  - 输入：Markdown（便于编写，代码块占比少）
  - `pandoc-crossref`：处理交叉引用、图表自动编号和公式
  - 参考模板（`.docx`）控制输出文档的字体、页边距、表格样式等格式
  - `pandoc` 命令示例：

```bash
pandoc input.md -o output.docx \
  --from markdown+auto_identifiers \
  --filter pandoc-crossref \
  --reference-doc=template.docx \
  --number-sections \
  --toc
```

  **参考模板既可以是 `.docx` 文件，也可以是 `.md` 文件，具体取决于任务的输入。**

### 终端代理
- 执行终端命令前，先检查代理环境变量（`$https_proxy` / `$all_proxy`）
- 如果配置了代理，下载类操作（如 `curl`、`brew`、`pip` 等）应使用代理，以提高速度

### 仿真与验证

主机地址、用户名、凭据、License 和工具安装路径属于本机私有信息，写入工作区根目录的 `TOOLS.local.md`。该文件不会进入版本控制。SSH 优先使用 `~/.ssh/config` 中的主机别名和密钥认证，不在 Markdown 中保存密码。

- **仿真工具** — Synopsys VCS（远程服务器）
  - 连接方式：SSH
  - 服务器：见 `TOOLS.local.md` 中的 SSH 主机别名
  - 路径：见 `TOOLS.local.md`
- **波形查看工具** — Synopsys Verdi（远程服务器）
  - 连接方式：SSH X11 转发 → Mac XQuartz
  - 服务器：同上
  - 路径：见 `TOOLS.local.md`
  - 波形格式：FSDB
  - X11 转发：在目标 Mac 的 `~/.ssh/config` 中按需配置 `ForwardX11 yes`
- **综合工具** — Synopsys Design Compiler
  - 路径：见 `TOOLS.local.md`
- **Lint 工具** — Synopsys SpyGlass
  - 路径：见 `TOOLS.local.md`
- **License 文件路径** — 见 `TOOLS.local.md`

---

## 模型路由策略

- **日常对话和普通任务** → 建议使用 `deepseek/deepseek-v4-pro`
- **复杂代码编写和代码审查** → 可使用已验证且符合工作规范的编码模型
  - 适用场景：编写 RTL/SystemVerilog 模块、复杂 Python 脚本、大规模重构和代码审计

最终默认模型以目标机器的 `openclaw config get agents.defaults.model.primary` 为准，不在 workspace 中硬编码。

---

## 为什么要单独记录？

Skill 是共享的；这个文件记录的是你当前环境的专属配置。将两者分开，可以在更新 Skill 时保留本地环境信息，也能在共享 Skill 时避免暴露你的基础设施细节。

## 相关文档

- [Agent 工作区](/concepts/agent-workspace)

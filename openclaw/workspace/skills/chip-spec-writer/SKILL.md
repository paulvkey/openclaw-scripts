---
name: "chip-spec-writer"
description: "Chip design spec (.docx): SVG+Playwright diagrams, FSM/timing, RTL. Pre-workflow, signal-type rules, anti-pattern checklist."
user-invocable: true
---

# Chip Spec Writer

生成专业的芯片设计规格文档（Word .docx 格式）。涵盖架构设计规格、详细设计规格和验证计划，适用于各类芯片模块。

## When to Use

- 用户要求创建芯片/模块设计规格文档
- 用户需要架构文档、详细设计文档或验证计划
- 用户需要模块框图、FSM 状态转移图或时序图
- 用户需要 UVM testbench 结构或验证规划文档

---

# Pre-Workflow: 材料收集（必须的第一步）

绘制任何图表或编写任何章节之前，必须收集所有可用材料：

## 必需文档

| 文档 | 提取内容 | 缺失时 |
|---|---|---|
| 功能规格 (.docx/.md) | 操作流程、触发条件、状态描述、时间约束 | → 提示用户提供 |
| 寄存器文件 (.xls/.xlsx) | 寄存器地址、位域、默认值、访问类型 | → 提示用户提供 |
| 接口描述 (.xls/.xlsx) | 信号名、方向、位宽、默认值、时钟域 | → 提示用户提供 |
| 已有参考图 (.pdf/.png) | 时序图风格、画法、信号标注方式 | → 有则直接使用 |

**重要**: 任何文档缺失时，立即停下来提示用户。不猜信号位宽、默认值或时序关系。

## 参数提取清单

开始生成任何图表或文档前，确认填写：

```
□ 所有信号名、方向、位宽（来自接口文档）
□ 所有信号默认值（来自接口文档）
□ 所有寄存器地址、位域、复位值（来自寄存器文件）
□ 所有时序约束：setup/hold、超时、脉宽（来自规格）
□ 所有 FSM 状态和转移条件（来自规格）
□ 所有操作时序（来自规格：软件流程、硬件流程）
```

---

# 图表工具规范

## 流程图 & 状态图 & 模块图 → SVG + Playwright

- 输出格式: SVG + PNG 双格式
- SVG 自包含：CSS 嵌入 SVG 内部 `<style>` 标签，不引用外部样式表
- 颜色用固定十六进制值（如 `#3b82f6`），不用 CSS 变量（`var(--xxx)`）
- viewBox 装下全部内容，避免文字/连线重叠
- 使用 Playwright `full_page=True` 导出完整无截断 PNG

### SVG 强制规则

- 背景: `<rect width="100%" height="100%" fill="#fafbfc"/>`
- 每个用作线的 `<path>` 必须有 `fill="none"`
- Marker 使用 `<polygon>` 不用 `<path>`
- 不用 CSS 变量，用显式十六进制颜色
- 不用 `fill-opacity`，用显式浅色
- `orient="auto"`（不用 `auto-start-reverse`）
- `&&` 写为 `&amp;&amp;`
- 暗黑模式通过 `@media (prefers-color-scheme: dark)` 适配，颜色同样用固定值

### 常见错误

1. ❌ CSS 使用变量（`var(--xxx)`） → 部分渲染器显示黑色，必须用固定十六进制值
2. ❌ `<path>` 缺少 `fill="none"` → 渲染为实心黑色
3. ❌ Marker 内用 `<path>` → 改用 `<polygon>`
4. ❌ viewBox 太小 → 文字/连线重叠或被裁切
5. ❌ CSS 写在外部文件 → 独立 SVG 文件样式丢失

### Playwright 导出

生成 SVG 后，用 Playwright 导出完整 PNG：

```bash
npx playwright screenshot --full-page diagram.svg diagram.png
```

或用 Python/Node 脚本控制 viewport、等待渲染完成。`full_page=True` 保证内容完整不截断。

## 时序图 → wavedrom-cli

- 输出格式: PNG，分辨率 2K（≥ 2560×1440）
- 输入: JSON 格式的 WaveDrom 描述文件
- 生成命令:

```bash
npx wavedrom-cli -i timing.json -p timing.png --scale 2
```

### WaveDrom JSON 模板

```json
{
  "signal": [
    {"name": "clk",           "wave": "P........", "period": 2},
    {"name": "init_start",    "wave": "0.1.0....", "node": "..A"},
    {"name": "spine_reset_n", "wave": "0........", "node": "....B"},
    {"name": "tsv_tm[428:1]", "wave": "x.x.2...x", "data": ["valid"]},
    {"name": "init_done",     "wave": "0.......1"},
    {"name": "FSM",           "wave": "2.2..2..2", "data": ["IDLE","INIT_RESET","INIT_WAIT","READY"]}
  ],
  "edge": ["A->B init_spine_reset_time"],
  "config": {"hscale": 2}
}
```

**注意**: 时序图也可用 SVG/HTML 自包含格式，确保暗黑模式正常显示（见下方 SVG 规范）。

---

# 时序图 SVG 规范（自包含 HTML 方式）

若选择 SVG/HTML 方式生成时序图，遵循以下规范。

## 前置：事件表（必须——不可跳过）

编写任何 SVG 元素之前，为每个时序场景建立 T0..Tn 事件表：

```
场景: <名称> (<软件/硬件流程>)

T0: <触发条件>
    signal_A = <默认值> → <新值>   # 原因 / 来源
    signal_B = <默认值>              # 保持默认
    FSM: <状态A> → <状态B>

T1: <条件>
    signal_A = <值>
    signal_B = <默认值> → <有效值>  # 原因
```

**规则**:
1. 每个信号在每个 T-标记处都必须有状态（即使不变，写"保持 <值>"）
2. 默认值必须来自接口/寄存器文档，不猜
3. 中间状态必须显示，不跳过
4. 不确定的转移时刻，标记并问用户

## 信号类型与绘制规则

### A 型: 单比特控制信号（默认=0，脉冲型）

```xml
<!-- init_start: center=196, LOW=206, HIGH=186 -->
<polyline points="220,206 260,206 260,186 300,186 300,206 870,206"
     stroke="#3b82f6" stroke-width="2" fill="none"/>
```

### B 型: 单比特状态信号（默认=0，上升到1）

```xml
<!-- init_done_flag: center=490, LOW=500, HIGH=480 -->
<polyline points="220,500 650,500 650,480 870,480"
     stroke="#10b981" stroke-width="2" fill="none"/>
```

### C 型: 单比特状态信号（默认=1，操作期间为0，之后恢复1）

```xml
<polyline points="220,516 270,516 270,536 565,536 570,516 870,516"
     stroke="#10b981" stroke-width="2" fill="none"/>
```

### D 型: 总线信号（>1 位）

- 转换区（NULL/未知）: **灰色填充** `#e2e8f0`，全宽
- 有效区（已知数据）: **黄色填充** `#fef3c7`，内部居中标注值
- **禁止** 交叉斜线或"X"标记
- **禁止** 细边框线

```xml
<rect x="220" y="358" width="190" height="48" fill="#e2e8f0" stroke="none"/>
<rect x="410" y="358" width="250" height="48" fill="#fef3c7" stroke="#fcd34d" stroke-width="1.5"/>
<text x="535" y="386" text-anchor="middle" font-size="10" font-weight="700" fill="#92400e">tsv_tm_valid</text>
<rect x="660" y="358" width="210" height="48" fill="#e2e8f0" stroke="none"/>
```

### E 型: FSM 状态

- **一条连续 `<polyline>`** 贯穿整个波形宽度
- 状态名标签在线上方 8px，font-size=9，font-weight=700
- 状态边界处加刻度线

```xml
<polyline points="220,576 870,576" stroke="#64748b" stroke-width="2" fill="none"/>
<text x="237" y="568" text-anchor="middle" font-size="9" font-weight="700" fill="#64748b">IDLE</text>
<line x1="260" y1="572" x2="260" y2="580" stroke="#64748b" stroke-width="1.5"/>
```

### F 型: 时钟

```xml
<polyline points="220,86 270,86 270,114 300,114 300,86 ..."
     stroke="#94a3b8" stroke-width="1.5" fill="none"/>
```

## 高低电平坐标约定

```
center_y = 信号行基线
LOW  (0) → y = center_y + 10
HIGH (1) → y = center_y - 10
```

默认=0 的信号，第一个 y 坐标 = center_y + 10（LOW）。
默认=1 的信号，第一个 y 坐标 = center_y - 10（HIGH）。

## 时序标注要求

每张时序图必须包含：

1. **脉宽标注**: 物理时间 + 周期数
   - `init_spine_reset_time = 20ms (8,000,000 cycles @ 400MHz)`
2. **setup/hold 标注**: 最小值 + 周期分数
   - `setup ≥ 1ns (0.4 cycle @ 400MHz)`
3. **寄存器默认值**: 底部注释行
4. **关键时间点说明**: T-标记对应的操作说明

## 暗黑模式支持（必须）

SVG/HTML 图表必须自包含，且在暗黑模式下正常显示。使用固定十六进制颜色值：

```html
<style>
  @media (prefers-color-scheme: dark) {
    .bg { fill: #1e2433; }
    .label { fill: #e2e8f0; }
    .grid { stroke: #334155; }
  }
</style>
```

---

# 导出规范

## 工具选择

| 图表类型 | 主工具 | 备用 |
|---------|-------|------|
| 状态图/流程图/模块图 | SVG + Playwright → SVG + PNG 双格式 | PlantUML → 2K PNG |
| 时序图 | wavedrom-cli → 2K PNG | SVG/HTML + Playwright 截图 |

## Python 环境

所有 Python 脚本使用当前环境中的 Python 3：
```bash
python3
```

如需固定依赖版本，在项目虚拟环境中安装并记录版本，不绑定某台 Mac 的 Homebrew 或 conda 绝对路径。

## Playwright 导出

用 Playwright 将 SVG/HTML 导出为完整 PNG：

```bash
npx playwright screenshot --full-page diagram.svg diagram.png
```

或用 Python 脚本控制 viewport、等待渲染完成后截图：

```python
from playwright.sync_api import sync_playwright
import os

def export_svg_to_png(svg_path: str, output_png: str, width: int = 2560, height: int = 1440):
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": width, "height": height})
        page.goto(f"file://{os.path.abspath(svg_path)}")
        page.wait_for_load_state("networkidle")
        page.screenshot(path=output_png, full_page=True)
        browser.close()

export_svg_to_png("diagram.svg", "diagram.png")
```

要点：
- viewport 设为 2560×1440（2K）
- `wait_for_load_state("networkidle")` 确保 SVG 渲染完成
- `full_page=True` 避免内容截断
- 不依赖 macOS 系统工具，跨平台可用

---

# 架构图规范

## 箭头方向规则

箭头必须从源指向目标。

### 反馈线（虚线）

```xml
<!-- 反馈: Timer → FSM (cnt_done). 箭头指向左（FSM 方向） -->
<path d="M 680 180 L 635 180" stroke="#cbd5e1" stroke-width="1.2"
      stroke-dasharray="6 4" fill="none"/>
<line x1="635" y1="180" x2="630" y2="180" stroke="#cbd5e1"
      stroke-width="1.2" marker-end="url(#arr-status)"/>
```

marker 段的 x1→x2 方向 = 信号流方向：
- x1 > x2 → 箭头向左
- x1 < x2 → 箭头向右

### 标准线型

| 类型 | Stroke | Width | Dash | Marker |
|------|--------|-------|------|--------|
| 地址/控制 | `#334155` | 2.5 | none | `#334155` |
| 写控制 | `#3b82f6` | 1.5 | none | `#3b82f6` |
| 读控制 | `#d97706` | 1.5 | none | `#d97706` |
| 状态 | `#94a3b8` | 1.5 | none | `#94a3b8` |
| 反馈（虚线）| `#cbd5e1` | 1.2 | `6 4` | `#94a3b8` |
| 错误路径 | `#dc2626` | 2 | none | `#dc2626` |

### SVG 强制规则

- 背景: `<rect width="100%" height="100%" fill="#fafbfc"/>`
- 每个用作线的 `<path>` 必须有 `fill="none"`
- Marker 使用 `<polygon>` 不用 `<path>`
- 不用 CSS 变量，用显式十六进制颜色
- 不用 `fill-opacity`，用显式浅色
- `orient="auto"`（不用 `auto-start-reverse`）
- `&&` 写为 `&amp;&amp;`
- 不用 `sips`（marker 会失效）

### 常见错误

1. ❌ `<path>` 缺少 `fill="none"` → 渲染为实心黑色
2. ❌ 使用 CSS 变量 → 部分渲染器显示黑色
3. ❌ Marker 内用 `<path>` → 改用 `<polygon>`
4. ❌ 虚线反馈箭头指向源而非目标
5. ❌ 总线用单线绘制 → 用填充色带（灰→黄→灰）
6. ❌ FSM 状态分段绘制 → 用单条 polyline
7. ❌ 总线过渡区用交叉斜线 → 纯灰色填充
8. ❌ 未读接口文档就猜信号位宽

---

# 文档规范

## 版本化（必须）

每次迭代**新建文件**，文件名包含版本号，保留所有历史版本便于比对差异。**不覆盖旧版本文件。**

### 版本号命名规则

```
<模块名>_<文档类型>_v<主版本>.<次版本>.docx

示例：
  ahb2axi_design_v1.0.docx      ← 初始版本
  ahb2axi_design_v1.1.docx      ← 小幅修订（章节补充、描述修正）
  ahb2axi_design_v2.0.docx      ← 重大变更（架构调整、接口变更）
```

版本号规则：
- **主版本**（x.0）: 架构/接口重大变更
- **次版本**（x.y）: 内容补充、修正、优化

### 修订记录要求

每次生成新版本，**必须**在文档第 1 章（修订记录）新增一行，并注明：

| 版本 | 日期 | 作者 | 修订内容 |
|------|------|------|---------|
| v1.0 | 2026-06-04 | 张颖 | 初始版本 |
| v1.1 | 2026-06-12 | 张颖 | 补充 FSM 状态转移条件，修正端口默认值 |

python-docx 写法：
```python
# 修订历史表：每次新版本追加一行，保留所有历史行
rev_table = doc.tables[0]  # 假设第一个表格为修订历史
row = rev_table.add_row()
row.cells[0].text = "v1.1"
row.cells[1].text = "2026-06-12"
row.cells[2].text = "张颖"
row.cells[3].text = "补充 FSM 状态转移条件，修正端口默认值"
```

## 封面

第一页为独立封面——无章节编号。仅文档名称，垂直水平居中。封面不包含版本、日期、状态等元数据。

```python
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(250)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run('<文档标题>')
r.bold = True; r.font.size = Pt(22); r.font.name = 'Times New Roman'
r.font.color.rgb = RGBColor(0, 0, 0)
doc.add_page_break()
```

元数据（版本、日期、状态）放修订历史表，不放封面。

## 章节编号

封面无编号，之后从 `1 修订记录` 开始：`1 修订记录`、`2 概述`、`2.1 功能描述`、`3 顶层模块` 等。

## 端口表

顶层端口表必须包含 5 列：**信号名 | 方向 | 位宽 | 默认值 | 描述**

默认值来自接口文档。时钟/复位使用"NA"。

## 写作风格（去 AI 化）

- 直接、简洁。不用"旨在""此外""确保""扮演关键角色""核心""关键"
- 用"是/有/做"代替"充当/扮演/服务于"
- 短段落，一段一个意思。不用破折号
- 不堆砌形容词，不写模糊描述

## 格式（python-docx）

- 字体: Times New Roman（正文），黑体（标题）
- 表格: 表头 `#D9D9D9`，`Table Grid` 样式
- 代码: Courier New 6-7pt，1.0 行间距
- 页面: A4（21cm×29.7cm），2cm 页边距
- 图表: PNG 5.2-5.8 英寸宽

---

# 文档结构

1. **封面** — 文档名称，居中
2. **修订历史** — 完整版本表（每次新版本必须追加）
3. **概述** — 目的、设计参数、关键决策
4. **顶层模块** — 框图、模块层次表、端口表（含默认值）、例化
5. **模块详情** — 每个 L1 模块：描述、接口、关键 RTL
6. **FSM 设计** — 状态编码、状态转移图、转移条件（全部，含等待循环和 OR）、核心 RTL
7. **时序图** — 见图表工具规范
8. **集成指南** — 编码顺序、SDC 约束、验证项
9. **附录** — 时序检查清单、参考文档

---

# 完整工作流

```
1. 材料收集
   ├── 读取所有提供的文档（规格、寄存器文件、接口文档）
   ├── 检查缺失文档 → 立即提示用户
   └── 提取所有参数（信号、默认值、时序、状态）

2. 设计阶段
   ├── 为每个时序场景建立事件表
   ├── 设计 FSM 状态/转移、模块层次
   └── 对每个信号按类型分类（A/B/C/D/E/F）

3. 图表生成
   ├── 流程图/状态图/模块图 → 自包含 SVG（CSS 嵌入、固定颜色、viewBox 完整）
   ├── SVG → Playwright 导出完整 PNG（full_page=True）
   ├── 时序图 → wavedrom-cli → 2K PNG（备用: SVG/HTML + Playwright）
   ├── 运行验证清单
   └── 获得用户预览确认

4. 导出验证
   ├── SVG 自包含检查：CSS 嵌入、固定颜色、无 CSS 变量
   ├── viewBox 检查：内容完整、无文字/连线重叠
   ├── PNG 导出完整无截断（full_page=True）
   └── 暗黑模式正常显示

5. 文档生成
   ├── 确定版本号（主版本.次版本）
   ├── 新建版本文件，文件名含版本号（不覆盖旧版）
   ├── 修订历史表追加新版本行（版本、日期、作者、修订内容）
   ├── 按编号章节构建 .docx
   ├── 包含端口表（含默认值）
   └── 开放供用户审查
```

## SVG 导出验证清单

```
□ CSS 全部嵌入 SVG 内部 `<style>` 标签，无外部引用
□ 颜色用固定十六进制值，无 CSS 变量（var(--xxx)）
□ viewBox 包含全部内容，无文字/连线重叠
□ Playwright full_page=True 导出，PNG 完整无截断
□ 暗黑模式 @media (prefers-color-scheme: dark) 正常，颜色用固定值
```

## 时序图验证清单（导出前）

```
□ 所有信号在事件表中每个 T-标记均有状态
□ 默认值与接口/寄存器文档一致
□ 默认=0 的信号起点在 LOW（center_y + 10）
□ 默认=1 的信号起点在 HIGH（center_y - 10）
□ 总线信号用填充色带（灰→黄→灰），无交叉线，无"X"
□ FSM 状态为单条连续 polyline，无断点
□ 所有 polyline 连续，无断段
□ 脉宽标注：物理时间 + 周期数 @ 工作频率
□ setup/hold 时间包含周期数换算
□ 信号间时序关系与规格操作时序一致
□ 保留中间状态，无跳过
□ 信号位宽与接口文档一致
```

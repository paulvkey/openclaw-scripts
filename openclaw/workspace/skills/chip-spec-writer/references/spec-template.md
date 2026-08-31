# Spec Document Template

## Standard Sections

### 1. Cover Page
- Project title (Chinese + English)
- Version, date, status
- Protocol(s), data width, address width
- Key design parameters

### 2. Revision History
- Table: Version | Date | Author | Description

### 3. Overview (文档说明)
- 3.1 用途 (Purpose & Scope)
- 3.2 读者 (RTL designers, verification, STA, integration)
- 3.3 设计参数汇总 (Design Parameters table: name, default, description)
- 3.4 几个设计决策 (Key design decisions, bullet list)

### 4. Top-Level Module
- 4.1 模块框图 (Architecture block diagram — embed PNG)
- 4.2 模块层次 (Hierarchy table: Level, Module, Filename, Function — Top/L1/L2)
- 4.3 L1 写分支内部结构 (Write branch diagram + text)
- 4.4 L1 读分支内部结构 (Read branch diagram + text)
- 4.5 顶层端口 (Port list table: name, direction, width, description)
- 4.6 顶层例化模板 (Instantiation code)

### 5. Module Details
For each L1/L2 module:
- Function description (1-2 paragraphs)
- Interface signal table (name, direction, width, description)
- Key RTL code blocks

### 6. FSM Design (if applicable)
- 6.1 状态编码 (State encoding table)
- 6.2 状态转移图 (State transition diagram — embed PNG, also reference HTML)
- 6.3 转移条件表 (Transition condition table — must include ALL conditions including wait loops and OR conditions)
- 6.4 FSM 全部端口 (FSM port list table)
- 6.5 FSM 核心 RTL (Core FSM code)

### 7. Timing Diagrams
- Cycle-accurate ASCII with T0..Tn markers
- Show clock, all relevant signals, FSM state at each Tn
- Annotate key timing points at bottom

### 8. Error Handling
- Response mapping table
- Timeout protection RTL

### 9. Integration Guide
- 9.1 编码顺序 (Coding order: sequence, level, module, filename, estimated lines)
- 9.2 SDC constraints (code block)
- 9.3 验证项 (Verification items, bullet list)

### 10. Appendix
- Timing checklists
- Reference documents (numbered list `[1] [2] ...`)

## Python-docx Boilerplate

```python
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = Document()

# Page setup
for section in doc.sections:
    section.page_width = Cm(21)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2.0)
    section.bottom_margin = Cm(2.0)
    section.left_margin = Cm(2.0)
    section.right_margin = Cm(2.0)

# Styles — Normal
style = doc.styles['Normal']
style.font.name = 'Times New Roman'
style.font.size = Pt(10)
style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')

# Styles — Headings
for lvl in range(1, 5):
    hs = doc.styles[f'Heading {lvl}']
    hs.font.name = 'Times New Roman'
    hs.font.color.rgb = RGBColor(0, 0, 0)
    hs.element.rPr.rFonts.set(qn('w:eastAsia'), '黑体')
    hs.font.size = Pt({1: 15, 2: 12.5, 3: 11, 4: 10}[lvl])
```

## Table Helper

```python
def tbl(doc, headers, rows, col_widths=None, fs=8):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = 'Table Grid'
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, h in enumerate(headers):
        c = table.rows[0].cells[i]; c.text = ''
        p = c.paragraphs[0]; p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h); r.bold = True; r.font.size = Pt(fs); r.font.name = 'Times New Roman'
        sh = OxmlElement('w:shd'); sh.set(qn('w:fill'), 'D9D9D9'); sh.set(qn('w:val'), 'clear')
        c._tc.get_or_add_tcPr().append(sh)
    for ri, rd in enumerate(rows):
        for ci, ct in enumerate(rd):
            c = table.rows[ri + 1].cells[ci]; c.text = ''
            p = c.paragraphs[0]; r = p.add_run(str(ct))
            r.font.size = Pt(fs); r.font.name = 'Times New Roman'
    if col_widths:
        for row in table.rows:
            for i, w in enumerate(col_widths):
                row.cells[i].width = Cm(w)
    doc.add_paragraph()
    return table
```

## Code Block Helper

```python
def code(doc, text, fs=7):
    for line in text.strip().split('\n'):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.0
        r = p.add_run(line)
        r.font.name = 'Courier New'
        r.font.size = Pt(fs)
```

## Para / Bullet Helpers

```python
def para(doc, text):
    doc.add_paragraph(text)

def bullet(doc, text):
    doc.add_paragraph(text, style='List Bullet')
```

## Writing Style Rules

### Never use these words/phrases:
- 旨在, 此外, 确保, 扮演关键角色, 核心枢纽, 关键, 显著
- 服务于, 充当, 体现了, 标志着
- 值得注意的是, 需要特别关注的是
- 在...过程中, 通过...的方式
- 业界认为, 据分析, 专家指出

### Always use:
- "是/有/做" instead of "充当/扮演/服务于"
- Short paragraphs, one idea each
- Direct statements: "它给出了..." not "本文档旨在为...提供..."
- Specific details over vague claims
- Simple construct: "主要做三件事" not "关键功能包括..."

## RTL Coding — Address Decoding Pitfall

When implementing register files accessed via a bus (APB, AHB, etc.), the bus address is typically byte-addressed (`PADDR`), but the internal register address used in the register file is word-aligned (`PADDR[9:2]`). The `define` macros in header files usually use byte offsets (`8'h00, 8'h04, ...`).

**DO NOT use these `define` macros directly in the register file's case statements.**
Instead, use word-aligned numeric values:

```verilog
// WRONG: defines are byte-aligned, reg_addr_i is word-aligned
case (reg_addr_i)
    `REG_CTRL: ...  // 8'h00 works by coincidence
    `REG_CFG:  ...  // 8'h04 != reg_addr_i (which is 1)
endcase

// CORRECT: use word-aligned addresses
case (reg_addr_i)
    8'd0:  ctrl_reg = ...  // offset 0x00
    8'd1:  cfg_reg  = ...  // offset 0x04
    8'd63: id_reg   = ...  // offset 0xFC
endcase
```

Also ensure the address error check (`addr_invalid`) uses the same word-aligned addressing scheme.

# Diagram Conventions for Chip Spec Documents

## Renderer Choice

| Renderer | Markers | CSS Vars | Output | Use? |
|----------|---------|----------|--------|------|
| `sips` (CoreSVG) | ❌ ignored | ❌→black | RGBA, transparent bg | **NO** |
| `qlmanage` (WebKit) | ✅ full | ✅ via `<style>` | square thumbnail | **YES** |
| Browser (Chrome/Safari) | ✅ | ✅ | screenshot | Preview only |

**Always use `qlmanage -t -s 2800` for PNG export.** Then crop with PIL and composite onto `#fafbfc` background if the output is RGBA.

## SVG Rules

### Required on every `<path>` used as line/arrow
```xml
<path d="..." stroke="#xxx" stroke-width="N" fill="none" marker-end="url(#...)" />
```
Without `fill="none"`, SVG defaults to `fill="#000000"` — entire path interior renders as solid black.

### Markers — use `<polygon>`, NOT `<path>`
```xml
<!-- CORRECT -->
<marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerW="7" markerH="7" orient="auto">
  <polygon points="0,0 10,5 0,10" fill="#334155"/>
</marker>

<!-- WRONG — some renderers ignore <path> inside <marker> -->
<marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerW="7" markerH="7" orient="auto">
  <path d="M 0 0 L 10 5 L 0 10 z" fill="#475569"/>
</marker>
```

### Background and border
```xml
<!-- Background MUST be a <rect>, not CSS style on <svg> -->
<rect width="100%" height="100%" fill="#fafbfc"/>

<!-- Outer border -->
<rect x="10" y="56" width="W" height="H" rx="12" fill="none" stroke="#334155" stroke-width="2.5"/>
```

### XML compliance
- `&&` must be `&amp;&amp;` before any XML parsing
- Self-closing tags: `<rect ... />` not `<rect ... >`
- Quote all attribute values

### Self-loops — MUST use these coordinates rules
Self-loop arrows curve from and back to the SAME physical edge of the node.

```xml
<!-- Right-side self-loop on node at x=100..320, y=336..400 -->
<path d="M 320 352 C 370 352, 370 384, 320 384" class="edge-loop" marker-end="url(#arr-loop)"/>
```
The start y (352) and end y (384) must both be **within the node's y-range** (336..400).

**Common mistake**: start/end y outside node bounds → arrow appears disconnected.

### OR conditions on transition labels
For self-loops with OR conditions, use vertical layout:
```xml
<text x="342" y="480" class="small">!burst_done</text>
<text x="342" y="494" class="small" style="font-weight:700;">||</text>
<text x="342" y="508" class="small">burst_done && WREADY==0</text>
```
The `||` gets its own line, centered between the two condition lines. All three lines share the same x coordinate.

### Signal labels with potential overlap
- Push signal labels toward bus sidebars (x=860 for AXI bus at x=940)
- Internal labels (like `R→HRDATA` inside a module box) should be at the BOTTOM of the box (y = box_bottom - 4)
- If an internal arrow crosses a text area, move the arrow to y above/below the text line

## Color Palette (All Explicit Hex — NO CSS vars)

| Usage | Fill | Stroke |
|-------|------|--------|
| Idle/control state | `#dcfce7` or `#d9f99d` | `#86efac` |
| Address capture | `#e2e8f0` | `#94a3b8` |
| Write branch zone | `#eff6ff` | `#bfdbfe` |
| Write module | `#dbeafe` | `#93c5fd` |
| Read branch zone | `#fffbeb` | `#fde68a` |
| Read module | `#fef3c7` | `#fcd34d` |
| Error state | `#fecaca` | — |
| AXI/AHB bus bars | `#f1f5f9` | `#cbd5e1` |
| Legend bg | `#f8fafc` | `#e2e8f0` |
| Scoreboard/Coverage | `#e2e8f0` | `#64748b` |
| SVA module | `#fecaca` | `#f87171` |
| Background | `#fafbfc` | — |
| Outer border | `none` | `#334155` |

## Connection Line Styles

| Type | Stroke | Width | Dash | Marker fill |
|------|--------|-------|------|-------------|
| Address/control (main) | `#334155` | 2.5 | none | `#334155` |
| Write ctrl | `#3b82f6` | 1.5 | none | `#3b82f6` |
| Read ctrl | `#d97706` | 1.5 | none | `#d97706` |
| Status | `#94a3b8` | 1.5 | none | `#94a3b8` |
| Feedback (dashed) | `#cbd5e1` | 1.2 | `6 4` | `#94a3b8` |
| Internal flow | `#94a3b8` | 1.5 | none | `#94a3b8` |
| Error path | `#dc2626` | 2 | none | `#dc2626` |
| Wait loop (self) | `#94a3b8` | 1.6 | none | `#94a3b8` |

**Dashed line arrow fix**: dashed stroke-dasharray sometimes clips the last dash, making the marker-end invisible. Fix by adding a separate solid segment at the very end:
```xml
<path d="M 775 352 L 775 396 L 850 396 L 850 216 L 610 216" stroke="#cbd5e1" stroke-width="1.2" stroke-dasharray="6 4" fill="none"/>
<line x1="610" y1="216" x2="600" y2="216" stroke="#cbd5e1" stroke-width="1.2" marker-end="url(#arr-dash)"/>
```

## Text Conventions in SVG

| Element | font-size | font-weight | fill |
|---------|-----------|-------------|------|
| Title | 18-20px | 700 | `#0f172a` |
| Section label (write) | 13px | 700 | `#2563eb` |
| Section label (read) | 13px | 700 | `#d97706` |
| Module name (write) | 13px | 700 | `#1e40af` |
| Module name (read) | 13px | 700 | `#92400e` |
| Module name (neutral) | 13px | 700 | `#475569` or `#1e293b` |
| Sub-text | 9px | — | `#64748b` |
| Signal labels | 8px | — | `#64748b` |
| Wait condition | 10px | 600 | `#5b6475` |

## Legend

- Box: `fill="#f8fafc" stroke="#e2e8f0" stroke-width="1"`
- Position: **bottom of diagram**, fully within outer border, below all modules
- Height: **52-54px** for single row, **72-80px** for two rows
- Width: **at least 280px** to fit 4-5 items with text
- **Must verify**: all text x-coordinates fall within `legend_x + 20` to `legend_x + legend_width - 10`
- 2-column layout preferred for space efficiency

## Export Workflow (exact steps)

```python
import re, subprocess
from PIL import Image
import numpy as np

# 1. Extract SVG from HTML
with open(html_path) as f:
    html = f.read()
match = re.search(r'(<svg\b.*?</svg>)', html, re.DOTALL)
svg = match.group(1)

# 2. Fix XML: escape &&, remove CSS var references
svg = svg.replace('&&', '&amp;&amp;')
# (CSS vars should already be explicit in the SVG — see rules above)

# 3. Write standalone .svg, render with qlmanage
with open('/tmp/diagram.svg', 'w') as f:
    f.write(svg)
subprocess.run(['qlmanage', '-t', '-s', '2800', '-o', '/tmp', '/tmp/diagram.svg'], capture_output=True)

# 4. Crop to content + pad, composite if RGBA
img = Image.open('/tmp/diagram.svg.png')
arr = np.array(img)
gray = np.mean(arr[:,:,:3], axis=2)
content = (gray < 245) | (gray > 252)
rows, cols = np.any(content, axis=1), np.any(content, axis=0)
t, b = np.where(rows)[0][[0,-1]]; l, r = np.where(cols)[0][[0,-1]]
cropped = img.crop((l-12, t-12, r+12, b+12))

# 5. If RGBA, composite onto background
if cropped.mode == 'RGBA':
    bg = Image.new('RGB', cropped.size, (250, 251, 252))  # #fafbfc
    bg.paste(cropped, mask=cropped.split()[3])
    bg.save(output_path, 'PNG')
else:
    cropped.save(output_path, 'PNG')
```

## Common Pitfalls (Checklist Before Export)

- [ ] Every `<path>` has `fill="none"`?
- [ ] All colors are explicit hex (no `var(--xxx)`)?
- [ ] No `fill-opacity` anywhere?
- [ ] All markers use `<polygon>`?
- [ ] Self-loop start/end y within node y-range?
- [ ] Legend fully within border, all text inside?
- [ ] Signal labels not overlapping module text?
- [ ] Dashed lines have a solid segment at end for marker?
- [ ] `&&` escaped as `&amp;&amp;`?
- [ ] Preview approved by user before exporting?

## RTL Coding — Pitfalls to Avoid

1. **AXI handshake outputs**: always `always @(*)` from current `state`, never registered from `next_state`. Using `next_state` causes WLAST to miss the final beat because `next_state` has already advanced to S_WR_RESP.
2. **Register address decoding**: internally addresses are word-aligned (`PADDR[9:2]`), not byte-aligned. Header `defines use byte offsets. Use numeric values in case statements.
3. **Parameter ordering**: base params first, derived params after (e.g. `AXI_STRB_WIDTH = AXI_DATA_WIDTH/8`).
4. **WSTRB function**: generalize with $clog2(AXI_STRB_WIDTH) for non-32-bit buses.

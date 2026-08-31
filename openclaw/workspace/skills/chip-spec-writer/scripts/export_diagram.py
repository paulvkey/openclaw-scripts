#!/usr/bin/env python3
"""
Export SVG diagram from HTML file to PNG.
Usage: python3 export_diagram.py <input.html> <output.png>
"""
import re, sys, subprocess, os

def export_diagram(html_path, output_path):
    with open(html_path) as f:
        html = f.read()

    match = re.search(r'(<svg\b.*?</svg>)', html, re.DOTALL)
    if not match:
        print(f"ERROR: No SVG found in {html_path}")
        return False

    svg = match.group(1).replace('&&', '&amp;&amp;')

    svg_file = f'/tmp/_diagram_export_{os.getpid()}.svg'
    with open(svg_file, 'w') as f:
        f.write(svg)

    subprocess.run(['qlmanage', '-t', '-s', '2800', '-o', '/tmp', svg_file],
                   capture_output=True)

    thumb = f'{svg_file}.png'
    if not os.path.exists(thumb):
        print(f"ERROR: qlmanage failed")
        return False

    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        print("ERROR: PIL/numpy not available")
        return False

    img = Image.open(thumb)
    arr = np.array(img)
    gray = np.mean(arr[:,:,:3], axis=2)
    cm = (gray < 245) | (gray > 252)
    rows, cols = np.any(cm, axis=1), np.any(cm, axis=0)

    if rows.any() and cols.any():
        t, b = np.where(rows)[0][[0, -1]]
        l, r = np.where(cols)[0][[0, -1]]
        pad = 12
        cropped = img.crop((
            max(0, l - pad),
            max(0, t - pad),
            min(arr.shape[1], r + pad),
            min(arr.shape[0], b + pad)
        ))
        cropped.save(output_path, 'PNG')
    else:
        img.save(output_path, 'PNG')

    os.remove(svg_file)
    os.remove(thumb)
    print(f"OK: {output_path} ({cropped.size if rows.any() else img.size})")
    return True

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.html> <output.png>")
        sys.exit(1)
    export_diagram(sys.argv[1], sys.argv[2])

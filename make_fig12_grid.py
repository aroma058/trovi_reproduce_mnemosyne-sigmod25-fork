"""Combine the 12 panels of Figure 12 (Fig12-a.pdf ... Fig12-l.pdf) into one PNG.

Layout (same order as the paper):
  row 1: (a) (b) (c)  read bytes,   uniform, Z = 0, 0.5, 1
  row 2: (d) (e) (f)  read bytes,   normal,  Z = 0, 0.5, 1
  row 3: (g) (h) (i)  read latency, uniform, Z = 0, 0.5, 1
  row 4: (j) (k) (l)  read latency, normal,  Z = 0, 0.5, 1

Usage: python3 make_fig12_grid.py <folder with Fig12-*.pdf> <output.png>
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

src_dir, out_path = sys.argv[1], sys.argv[2]
rows = [["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"], ["j", "k", "l"]]
row_labels = ["Read bytes\nuniform", "Read bytes\nnormal",
              "Read latency\nuniform", "Read latency\nnormal"]
col_labels = ["Z = 0.0", "Z = 0.5", "Z = 1.0"]

tmp = tempfile.mkdtemp()
panels = {}
for row in rows:
    for letter in row:
        pdf = os.path.join(src_dir, f"Fig12-{letter}.pdf")
        png_base = os.path.join(tmp, letter)
        subprocess.run(["pdftoppm", "-png", "-r", "60", "-singlefile", pdf, png_base], check=True)
        panels[letter] = Image.open(png_base + ".png").convert("RGB")

cell_w = max(p.width for p in panels.values())
cell_h = max(p.height for p in panels.values())
try:
    font = ImageFont.load_default(size=26)
except TypeError:  # older Pillow
    font = ImageFont.load_default()
left, top = 190, 50
grid = Image.new("RGB", (left + 3 * cell_w, top + 4 * cell_h), "white")
draw = ImageDraw.Draw(grid)

for c, label in enumerate(col_labels):
    draw.text((left + c * cell_w + cell_w // 2 - 45, 12), label, fill="black", font=font)
for r, row in enumerate(rows):
    draw.multiline_text((10, top + r * cell_h + cell_h // 2 - 30), row_labels[r], fill="black", font=font)
    for c, letter in enumerate(row):
        p = panels[letter]
        grid.paste(p, (left + c * cell_w + (cell_w - p.width) // 2,
                       top + r * cell_h + (cell_h - p.height) // 2))

grid.save(out_path)
print(f"Saved {out_path} ({grid.width} x {grid.height})")

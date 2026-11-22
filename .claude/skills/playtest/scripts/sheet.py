"""sheet.py OUT IMG... : tile up to 4 (or 6) frames into one labelled sheet."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

out, imgs = sys.argv[1], sys.argv[2:]
cols = 2 if len(imgs) <= 4 else 3
rows = (len(imgs) + cols - 1) // cols
W, H = (640, 360) if cols == 2 else (512, 288)
sheet = Image.new("RGB", (cols * W, rows * H))
d = ImageDraw.Draw(sheet)
for i, p in enumerate(imgs):
    im = Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)
    x, y = (i % cols) * W, (i // cols) * H
    sheet.paste(im, (x, y))
    d.rectangle([x, y, x + 150, y + 14], fill=(0, 0, 0))
    d.text((x + 3, y + 1), Path(p).stem, fill=(255, 255, 0))
sheet.save(out)

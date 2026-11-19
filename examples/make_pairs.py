"""Rasterize the final PDFs and assemble equally scaled, position-balanced A/B pairs.

Run after both versions of render.R from the same directory. Install pypdfium2
and Pillow in the Python environment used for document inspection.
"""
import json
import random
from pathlib import Path

import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont


def render_first_page(source):
    with pdfium.PdfDocument(source) as document:
        assert len(document) == 1, source
        page = document[0]
        bitmap = page.render(scale=2.0)
        result = bitmap.to_pil().convert("RGB")
        bitmap.close()
        page.close()
        return result


def header_font():
    for name in ("Arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size=21)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    comparisons = Path("comparisons")
    comparisons.mkdir(exist_ok=True)
    chart_names = ["plant-growth", "virginia-rates", "old-faithful"]
    rng = random.Random(41981)
    left_versions = ["baseline", "redesign", rng.choice(["baseline", "redesign"])]
    rng.shuffle(left_versions)
    mapping = {}
    for chart, left in zip(chart_names, left_versions):
        right = "redesign" if left == "baseline" else "baseline"
        images = []
        for version in (left, right):
            source = Path("figures", version, chart + ".pdf")
            preview = render_first_page(source)
            preview.save(source.with_name(chart + "-pdf-preview.png"))
            images.append(preview)
        assert images[0].size == images[1].size
        width, height = images[0].size
        gap, header, outer = 24, 38, 8
        canvas = Image.new("RGB", (2 * width + gap + 2 * outer, height + header + outer), "white")
        draw = ImageDraw.Draw(canvas)
        for index, image in enumerate(images):
            x = outer + index * (width + gap)
            draw.text((x + 8, 5), "AB"[index], fill="#25353A", font=header_font())
            canvas.paste(image, (x, header))
        separator = outer + width + gap // 2
        draw.line((separator, header, separator, height + header), fill="#D4DADB", width=1)
        canvas.save(comparisons / (chart + ".png"))
        mapping[chart] = {"A": left, "B": right}
    (comparisons / "answer-key.json").write_text(json.dumps(mapping, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

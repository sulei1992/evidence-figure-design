#!/usr/bin/env python3
"""Check the physical size of standalone SVGs and displayed PDF pages."""

import argparse
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


MM_PER_UNIT = {
    "mm": 1.0, "cm": 10.0, "q": 0.25, "in": 25.4,
    "pt": 25.4 / 72, "pc": 25.4 / 6, "px": 25.4 / 96, "": 25.4 / 96,
}
SVG_LENGTH = re.compile(r"([+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)([a-zA-Z]*)")


def finite_number(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError("expected a finite number")
    return number


def svg_dimension(value, name):
    match = SVG_LENGTH.fullmatch(value.strip())
    if not match or match[2].lower() not in MM_PER_UNIT:
        raise ValueError(f"SVG needs an absolute {name} on its root element (found {value!r})")
    millimeters = finite_number(float(match[1]) * MM_PER_UNIT[match[2].lower()])
    if millimeters <= 0:
        raise ValueError(f"SVG {name} must be positive")
    return millimeters


def svg_pages(path):
    root = ET.parse(path).getroot()
    if root.tag not in ("svg", "{http://www.w3.org/2000/svg}svg"):
        raise ValueError("root element is not SVG")
    # Inline CSS overrides the corresponding presentation attributes.
    lengths = {name: root.get(name, "") for name in ("width", "height")}
    for declaration in root.get("style", "").split(";"):
        name, _, value = declaration.partition(":")
        name = name.strip().lower()
        if name in lengths:
            lengths[name] = re.sub(r"\s*!important\s*$", "", value, flags=re.I)
    yield "SVG viewport", svg_dimension(lengths["width"], "width"), svg_dimension(lengths["height"], "height")


def pdf_pages(path):
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise ValueError("PDF checking requires pypdf in this Python environment") from exc

    with path.open("rb") as stream:
        reader = PdfReader(stream)
        if not reader.pages:
            raise ValueError("PDF has no pages")
        for index, page in enumerate(reader.pages, start=1):
            # Viewers show the intersection of the CropBox and the MediaBox.
            crop, media = page.cropbox, page.mediabox
            width = min(crop.right, media.right) - max(crop.left, media.left)
            height = min(crop.top, media.top) - max(crop.bottom, media.bottom)
            unit = finite_number(page.user_unit)
            if min(width, height, unit) <= 0 or page.rotation % 90:
                raise ValueError(f"invalid page geometry on page {index}")
            if page.rotation % 180:
                width, height = height, width
            scale = unit * MM_PER_UNIT["pt"]
            yield f"PDF page {index}", finite_number(width * scale), finite_number(height * scale)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", metavar="FILE", type=Path, nargs="+")
    parser.add_argument("--width-mm", type=finite_number, required=True)
    parser.add_argument("--height-mm", type=finite_number, required=True)
    parser.add_argument("--tolerance-mm", type=finite_number, default=0.25,
                        help="allowed difference per dimension in mm (default 0.25)")
    args = parser.parse_args()
    if min(args.width_mm, args.height_mm) <= 0 or args.tolerance_mm < 0:
        parser.error("dimensions must be positive and tolerance must be nonnegative")

    failed = False
    formats = {".svg": svg_pages, ".pdf": pdf_pages}
    for path in args.files:
        try:
            inspect = formats.get(path.suffix.lower())
            if inspect is None:
                raise ValueError("supported file types are PDF and SVG")
            for label, width, height in inspect(path):
                difference = max(abs(width - args.width_mm), abs(height - args.height_mm))
                passed = difference <= args.tolerance_mm + 1e-9
                result = "PASS" if passed else "FAIL"
                print(f"{result} {path} [{label}] {width:.3f} x {height:.3f} mm "
                      f"(expected {args.width_mm:g} x {args.height_mm:g} mm)")
                failed |= not passed
        except Exception as exc:
            # A malformed export must not suppress checks on the other inputs.
            print(f"FAIL {path}: {exc}", file=sys.stderr)
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())

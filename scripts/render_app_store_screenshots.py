#!/usr/bin/env python3
"""Render full-bleed Memory Spots App Store screenshots."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


CANVAS_SIZE = (1284, 2778)
RAW_NAMES = [
    "01-photo-notes.png",
    "02-memory-map.png",
    "03-route-detail.png",
    "04-review.png",
    "05-albums.png",
]

CAPTION_MARKERS = {
    "en": "Suggested App Store screenshot captions:",
    "ja": "Suggested Japanese App Store screenshot captions:",
}

PALETTE = {
    "cream": (255, 248, 231),
    "accent": (246, 201, 79),
    "accent_deep": (207, 85, 65),
    "glass": (18, 21, 22),
}


def font(size: int, *, bold: bool = False, locale: str = "en") -> ImageFont.FreeTypeFont:
    if locale == "ja":
        candidates = [
            (Path("/System/Library/Fonts/Hiragino Sans GB.ttc"), [2, 3, 0] if bold else [0, 1]),
            (Path("/System/Library/Fonts/Supplemental/AppleGothic.ttf"), [0]),
            (Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"), [6, 7, 4, 0] if bold else [0, 2]),
        ]
    else:
        candidates = [
            (Path("/System/Library/Fonts/HelveticaNeue.ttc"), [1, 2, 0] if bold else [0]),
            (Path("/System/Library/Fonts/SFNS.ttf"), [0]),
            (Path("/System/Library/Fonts/Helvetica.ttc"), [1, 0] if bold else [0]),
        ]

    for path, indices in candidates:
        if not path.exists():
            continue
        for index in indices:
            try:
                return ImageFont.truetype(str(path), size, index=index)
            except OSError:
                continue
    return ImageFont.load_default(size=size)


def parse_captions(metadata_path: Path, locale: str) -> list[tuple[str, str]]:
    if not metadata_path.exists():
        raise FileNotFoundError(f"metadata file not found: {metadata_path}")

    marker = CAPTION_MARKERS[locale]
    lines = metadata_path.read_text(encoding="utf-8").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == marker:
            start = i + 1
            break
    if start is None:
        raise ValueError(f"Could not find {marker!r}")

    captions: list[tuple[str, str]] = []
    current_title: str | None = None
    body_parts: list[str] = []

    def flush() -> None:
        nonlocal current_title, body_parts
        if current_title is not None:
            captions.append((current_title, " ".join(body_parts).strip()))
        current_title = None
        body_parts = []

    for line in lines[start:]:
        stripped = line.strip()
        if stripped in CAPTION_MARKERS.values() and stripped != marker:
            break
        if stripped.startswith("## "):
            break
        if not stripped:
            continue
        if stripped.startswith("- "):
            flush()
            current_title = stripped[2:].strip()
            continue
        if current_title is not None:
            body_parts.append(stripped)
    flush()

    if len(captions) != len(RAW_NAMES):
        raise ValueError(f"Expected {len(RAW_NAMES)} {locale} captions, found {len(captions)}")
    if any(not title for title, _ in captions):
        raise ValueError("Each screenshot caption must include a title")
    return captions


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize(
        (math.ceil(image.width * scale), math.ceil(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def contains_cjk(text: str) -> bool:
    return any(
        "\u3040" <= ch <= "\u30ff" or "\u3400" <= ch <= "\u9fff" or "\uf900" <= ch <= "\ufaff"
        for ch in text
    )


def text_width(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.ImageFont) -> int:
    bbox = draw.textbbox((0, 0), text, font=text_font)
    return bbox[2] - bbox[0]


def wrap_words(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    line = ""
    for word in words:
        trial = word if not line else f"{line} {word}"
        if text_width(draw, trial, text_font) <= max_width:
            line = trial
            continue
        if line:
            lines.append(line)
        line = word
    if line:
        lines.append(line)
    return lines


def wrap_cjk_balanced(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.ImageFont, max_width: int) -> list[str]:
    if text_width(draw, text, text_font) <= max_width:
        return [text]

    preferred_endings = ("を", "で", "に", "へ", "と", "が", "は", "も", "から", "まで", "して", "って")
    candidates: list[tuple[int, list[str]]] = []
    for split in range(3, len(text) - 2):
        first = text[:split]
        second = text[split:]
        first_width = text_width(draw, first, text_font)
        second_width = text_width(draw, second, text_font)
        if first_width <= max_width and second_width <= max_width:
            score = abs(first_width - second_width)
            if first.endswith(preferred_endings):
                score -= round(max_width * 0.42)
            if second.startswith(("一括", "地図", "復習", "まとめ")):
                score -= round(max_width * 0.28)
            candidates.append((score, [first, second]))
    if candidates:
        return min(candidates, key=lambda item: item[0])[1]

    lines: list[str] = []
    line = ""
    for ch in text:
        trial = f"{line}{ch}"
        if text_width(draw, trial, text_font) <= max_width:
            line = trial
            continue
        if line:
            lines.append(line)
        line = ch
    if line:
        lines.append(line)
    return lines


def wrap_text(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.ImageFont, max_width: int) -> list[str]:
    if contains_cjk(text) and " " not in text:
        return wrap_cjk_balanced(draw, text, text_font, max_width)
    return wrap_words(draw, text, text_font, max_width)


def fitted_lines(
    draw: ImageDraw.ImageDraw,
    text: str,
    *,
    start_size: int,
    min_size: int,
    max_width: int,
    max_lines: int,
    locale: str,
) -> tuple[ImageFont.ImageFont, list[str]]:
    for size in range(start_size, min_size - 1, -2):
        text_font = font(size, bold=True, locale=locale)
        lines = wrap_text(draw, text, text_font, max_width)
        if len(lines) <= max_lines:
            return text_font, lines
    text_font = font(min_size, bold=True, locale=locale)
    return text_font, wrap_text(draw, text, text_font, max_width)[:max_lines]


def line_height(text_font: ImageFont.ImageFont) -> int:
    bbox = text_font.getbbox("Ag")
    return bbox[3] - bbox[1]


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def draw_caption_panel(canvas: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle(box, radius=radius, fill=PALETTE["glass"] + (204,))
    draw.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 86), width=2)


def draw_caption(canvas: Image.Image, title: str, _subtitle: str, locale: str, index: int) -> None:
    draw = ImageDraw.Draw(canvas)
    is_hero = index == 0
    x = 58
    y = 112 if is_hero else 126
    max_width = 1120
    title_font, title_lines = fitted_lines(
        draw,
        title,
        start_size=122 if locale == "en" else 126,
        min_size=76 if locale == "en" else 78,
        max_width=max_width,
        max_lines=2,
        locale=locale,
    )

    gap = 14 if is_hero else 12
    text_height = len(title_lines) * line_height(title_font) + (len(title_lines) - 1) * gap
    panel = (34, y - 40, 1250, y + text_height + 54)
    draw_caption_panel(canvas, panel, radius=42)

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle((x, y - 22, x + 172, y - 9), radius=7, fill=PALETTE["accent"] + (245,))
    draw.rounded_rectangle((x + 184, y - 22, x + 246, y - 9), radius=7, fill=PALETTE["accent_deep"] + (230,))

    current_y = y
    for line in title_lines:
        draw.text(
            (x, current_y),
            line,
            font=title_font,
            fill=PALETTE["cream"] + (255,),
        )
        current_y += line_height(title_font) + gap


def render_one(source_path: Path, output_path: Path, title: str, subtitle: str, locale: str, index: int) -> None:
    source = Image.open(source_path).convert("RGB")
    canvas = cover_resize(source, CANVAS_SIZE).convert("RGBA")
    draw_caption(canvas, title, subtitle, locale, index)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_path, "PNG", optimize=True)


def paths_for_locale(repo: Path, locale: str, raw_dir: str | None, out_dir: str | None) -> tuple[Path, Path]:
    if raw_dir:
        raw = Path(raw_dir).expanduser().resolve()
    elif locale == "ja":
        raw = repo / "screenshots/app-store/ja/raw"
    else:
        raw = repo / "screenshots/app-store/raw"

    if out_dir:
        out = Path(out_dir).expanduser().resolve()
    elif locale == "ja":
        out = repo / "screenshots/app-store/ja/captioned"
    else:
        out = repo / "screenshots/app-store/captioned"
    return raw, out


def render_locale(args: argparse.Namespace, repo: Path, locale: str) -> None:
    raw_dir, out_dir = paths_for_locale(repo, locale, args.raw_dir, args.out_dir)
    metadata = Path(args.metadata).expanduser().resolve() if args.metadata else repo / "docs/APP_STORE_METADATA.md"
    captions = parse_captions(metadata, locale)

    missing = [name for name in RAW_NAMES if not (raw_dir / name).exists()]
    if missing:
        raise FileNotFoundError(f"Missing raw screenshots in {raw_dir}: {', '.join(missing)}")

    for index, (name, (title, subtitle)) in enumerate(zip(RAW_NAMES, captions)):
        output_path = out_dir / name
        render_one(raw_dir / name, output_path, title, subtitle, locale, index)
        print(f"wrote {output_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="Memory Spots repository root")
    parser.add_argument("--locale", choices=["all", "en", "ja"], default="en", help="Locale to render")
    parser.add_argument("--raw-dir", help="Override raw screenshot directory for a single locale")
    parser.add_argument("--out-dir", help="Override output directory for a single locale")
    parser.add_argument("--metadata", help="Metadata markdown path")
    args = parser.parse_args()

    repo = Path(args.repo).expanduser().resolve()
    locales = ["en", "ja"] if args.locale == "all" else [args.locale]
    if args.locale == "all" and (args.raw_dir or args.out_dir):
        print("--raw-dir and --out-dir can only be used with --locale en or --locale ja", file=sys.stderr)
        return 2

    try:
        for locale in locales:
            render_locale(args, repo, locale)
    except (FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

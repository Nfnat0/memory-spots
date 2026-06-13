#!/usr/bin/env python3
"""Render editorial English App Store screenshots for Memory Spots."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


CANVAS = (1284, 2778)
SCREEN_SIZE = (730, 1588)
REPO = Path(__file__).resolve().parents[1]
RAW_DIR = REPO / "screenshots/app-store/raw"
SEED_DIR = REPO / "MindPalace/Resources/SeedImages"
OUT_DIR = REPO / "screenshots/app-store/editorial"

COLORS = {
    "ivory": (255, 249, 236),
    "ivory_2": (250, 241, 220),
    "ink": (18, 24, 29),
    "muted": (86, 85, 76),
    "red": (215, 74, 58),
    "red_dark": (178, 58, 45),
    "teal": (112, 181, 179),
    "green": (99, 130, 78),
    "blue": (78, 131, 170),
    "gold": (235, 164, 61),
    "paper": (255, 253, 246),
}

SEED_IMAGES = [
    "1C16E944-A18E-4A3B-9651-B639C91F7F65.png",
    "B836C280-90F3-4FB8-AF21-6813FAEDE7E1.png",
    "606BAB1B-066D-4124-8E8B-45A5A9332613.png",
    "240C63AE-B4CF-4BE2-90BE-D450878B809F.png",
]


def font(size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        (Path("/System/Library/Fonts/HelveticaNeue.ttc"), [1, 2, 0] if bold else [0]),
        (Path("/System/Library/Fonts/SFNS.ttf"), [0]),
        (Path("/System/Library/Fonts/Helvetica.ttc"), [1, 0] if bold else [0]),
    ]
    for path, indexes in candidates:
        if not path.exists():
            continue
        for index in indexes:
            try:
                return ImageFont.truetype(str(path), size, index=index)
            except OSError:
                continue
    return ImageFont.load_default(size=size)


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


def contain_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = min(target_w / image.width, target_h / image.height)
    return image.resize(
        (math.floor(image.width * scale), math.floor(image.height * scale)),
        Image.Resampling.LANCZOS,
    )


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def paste_alpha(base: Image.Image, layer: Image.Image, xy: tuple[int, int]) -> None:
    base.alpha_composite(layer, xy)


def paste_rotated(base: Image.Image, layer: Image.Image, center: tuple[int, int], angle: float) -> None:
    rotated = layer.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    x = round(center[0] - rotated.width / 2)
    y = round(center[1] - rotated.height / 2)
    paste_alpha(base, rotated, (x, y))


def shadow(size: tuple[int, int], radius: int, offset: tuple[int, int], alpha: int) -> Image.Image:
    layer = Image.new("RGBA", (size[0] + abs(offset[0]) + 80, size[1] + abs(offset[1]) + 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    box = (40, 40, 40 + size[0], 40 + size[1])
    draw.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(30))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (offset[0], offset[1]))
    return out


def gradient_base() -> Image.Image:
    image = Image.new("RGBA", CANVAS, COLORS["ivory"] + (255,))
    draw = ImageDraw.Draw(image)
    for y in range(CANVAS[1]):
        t = y / CANVAS[1]
        r = round(COLORS["ivory"][0] * (1 - t) + COLORS["ivory_2"][0] * t)
        g = round(COLORS["ivory"][1] * (1 - t) + COLORS["ivory_2"][1] * t)
        b = round(COLORS["ivory"][2] * (1 - t) + COLORS["ivory_2"][2] * t)
        draw.line((0, y, CANVAS[0], y), fill=(r, g, b, 255))
    return image


def add_map_texture(canvas: Image.Image, opacity: int = 76, blur: int = 3) -> None:
    source = Image.open(RAW_DIR / "02-memory-map.png").convert("RGB")
    texture = cover_resize(source, CANVAS).convert("RGBA")
    texture = ImageEnhance.Color(texture).enhance(0.62)
    texture = ImageEnhance.Contrast(texture).enhance(0.82)
    if blur:
        texture = texture.filter(ImageFilter.GaussianBlur(blur))
    wash = Image.new("RGBA", CANVAS, (255, 249, 236, 168))
    texture.alpha_composite(wash)
    texture.putalpha(opacity)
    canvas.alpha_composite(texture)


def add_corner_photo(
    canvas: Image.Image,
    image_path: Path,
    center: tuple[int, int],
    size: tuple[int, int],
    angle: float,
    *,
    border: int = 22,
) -> None:
    photo = Image.open(image_path).convert("RGB")
    photo = cover_resize(photo, size)
    card = Image.new("RGBA", (size[0] + border * 2, size[1] + border * 2 + 30), (255, 255, 255, 255))
    card_draw = ImageDraw.Draw(card, "RGBA")
    card_draw.rectangle((border, border, border + size[0], border + size[1]), fill=(240, 236, 225, 255))
    card.paste(photo, (border, border))
    mask = rounded_mask(card.size, 18)
    card.putalpha(mask)
    card_shadow = shadow(card.size, 20, (16, 22), 55)
    group = Image.new("RGBA", card_shadow.size, (0, 0, 0, 0))
    group.alpha_composite(card_shadow, (0, 0))
    group.alpha_composite(card, (40, 40))
    paste_rotated(canvas, group, center, angle)


def draw_dashed_line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    *,
    fill: tuple[int, int, int, int],
    width: int,
    dash: int = 34,
    gap: int = 24,
) -> None:
    for start, end in zip(points, points[1:]):
        x1, y1 = start
        x2, y2 = end
        dx = x2 - x1
        dy = y2 - y1
        length = math.hypot(dx, dy)
        if length == 0:
            continue
        ux = dx / length
        uy = dy / length
        position = 0
        while position < length:
            segment = min(dash, length - position)
            sx = x1 + ux * position
            sy = y1 + uy * position
            ex = x1 + ux * (position + segment)
            ey = y1 + uy * (position + segment)
            draw.line((sx, sy, ex, ey), fill=fill, width=width)
            position += dash + gap


def add_route(canvas: Image.Image, points: list[tuple[int, int]], *, labels: bool = True) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw_dashed_line(draw, points, fill=COLORS["red"] + (185,), width=9)
    pin_font = font(33, bold=True)
    for index, (x, y) in enumerate(points, start=1):
        draw.ellipse((x - 35, y - 35, x + 35, y + 35), fill=COLORS["red"] + (238,), outline=(255, 255, 255, 235), width=8)
        draw.text((x, y - 2), str(index), font=pin_font, fill=(255, 255, 255, 255), anchor="mm")
        if labels:
            draw.ellipse((x - 18, y + 28, x + 18, y + 64), fill=COLORS["red"] + (85,))


def make_device(source_path: Path, screen_size: tuple[int, int] = SCREEN_SIZE) -> Image.Image:
    border = 36
    outer = (screen_size[0] + border * 2, screen_size[1] + border * 2)
    group = Image.new("RGBA", (outer[0] + 120, outer[1] + 120), (0, 0, 0, 0))
    group.alpha_composite(shadow(outer, 92, (18, 28), 110), (0, 0))

    device = Image.new("RGBA", outer, (0, 0, 0, 0))
    draw = ImageDraw.Draw(device, "RGBA")
    draw.rounded_rectangle((0, 0, outer[0] - 1, outer[1] - 1), radius=90, fill=(23, 25, 25, 255))
    draw.rounded_rectangle((8, 8, outer[0] - 9, outer[1] - 9), radius=82, outline=(255, 255, 255, 105), width=3)

    screenshot = Image.open(source_path).convert("RGB")
    screen = cover_resize(screenshot, screen_size).convert("RGBA")
    screen_mask = rounded_mask(screen_size, 60)
    screen.putalpha(screen_mask)
    device.alpha_composite(screen, (border, border))

    group.alpha_composite(device, (60, 60))
    return group


def draw_brand(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.ellipse((x, y, x + 50, y + 50), fill=COLORS["red"] + (255,))
    draw.ellipse((x + 16, y + 12, x + 34, y + 30), fill=COLORS["paper"] + (255,))
    draw.polygon([(x + 25, y + 46), (x + 13, y + 27), (x + 37, y + 27)], fill=COLORS["red"] + (255,))
    draw.text((x + 76, y + 5), "MEMORY SPOTS", font=font(34, bold=True), fill=COLORS["red"] + (255,))


def draw_heading(
    canvas: Image.Image,
    lines: list[tuple[str, tuple[int, int, int]]],
    subtitle: str,
    *,
    x: int = 72,
    y: int = 160,
    size: int = 96,
) -> None:
    draw = ImageDraw.Draw(canvas, "RGBA")
    headline_font = font(size, bold=True)
    line_gap = 6
    current_y = y
    for text, color in lines:
        draw.text((x, current_y), text, font=headline_font, fill=color + (255,))
        current_y += round(size * 1.02) + line_gap
    draw.rounded_rectangle((x, current_y + 16, x + 92, current_y + 23), radius=4, fill=COLORS["red"] + (255,))
    sub_font = font(37)
    max_width = 650
    words = subtitle.split()
    row = ""
    sub_y = current_y + 62
    for word in words:
        trial = word if not row else f"{row} {word}"
        if draw.textlength(trial, font=sub_font) <= max_width:
            row = trial
            continue
        draw.text((x, sub_y), row, font=sub_font, fill=COLORS["ink"] + (238,))
        sub_y += 48
        row = word
    if row:
        draw.text((x, sub_y), row, font=sub_font, fill=COLORS["ink"] + (238,))


def draw_callout(
    canvas: Image.Image,
    xy: tuple[int, int],
    accent: tuple[int, int, int],
    title: str,
    body: str,
) -> None:
    x, y = xy
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.ellipse((x, y, x + 72, y + 72), fill=accent + (235,))
    draw.ellipse((x + 20, y + 20, x + 52, y + 52), outline=(255, 255, 255, 245), width=4)
    title_font = font(34, bold=True)
    body_font = font(25)
    draw.text((x + 98, y - 3), title, font=title_font, fill=COLORS["ink"] + (255,))
    body_y = y + 49
    line = ""
    for word in body.split():
        trial = word if not line else f"{line} {word}"
        if draw.textlength(trial, font=body_font) <= 220:
            line = trial
            continue
        draw.text((x + 98, body_y), line, font=body_font, fill=COLORS["muted"] + (255,))
        body_y += 35
        line = word
    if line:
        draw.text((x + 98, body_y), line, font=body_font, fill=COLORS["muted"] + (255,))


def draw_study_card(canvas: Image.Image, box: tuple[int, int, int, int], title: str, chip: str) -> None:
    x1, y1, x2, y2 = box
    layer = Image.new("RGBA", (x2 - x1, y2 - y1), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.rounded_rectangle((0, 0, layer.width - 1, layer.height - 1), radius=36, fill=(255, 253, 246, 245), outline=(225, 213, 190, 220), width=2)
    draw.ellipse((32, 30, 86, 84), fill=COLORS["red"] + (235,))
    draw.text((59, 57), "2", font=font(31, bold=True), fill=(255, 255, 255, 255), anchor="mm")
    draw.text((110, 32), title, font=font(40, bold=True), fill=COLORS["ink"] + (255,))
    draw.rounded_rectangle((110, 93, 238, 132), radius=18, fill=(229, 241, 246, 255), outline=(170, 202, 216, 255), width=1)
    draw.text((174, 113), chip, font=font(20, bold=True), fill=COLORS["blue"] + (255,), anchor="mm")
    paste_alpha(canvas, layer, (x1, y1))


def add_background_photos(canvas: Image.Image) -> None:
    add_corner_photo(canvas, SEED_DIR / SEED_IMAGES[0], (1070, 165), (330, 235), -7)
    add_corner_photo(canvas, SEED_DIR / SEED_IMAGES[1], (1150, 650), (300, 420), 7)
    add_corner_photo(canvas, SEED_DIR / SEED_IMAGES[2], (1040, 2500), (350, 260), -8)


def render_01() -> Image.Image:
    canvas = gradient_base()
    add_map_texture(canvas, opacity=70, blur=4)
    add_background_photos(canvas)
    add_route(canvas, [(1010, 180), (970, 520), (1080, 880), (1030, 1330), (1120, 2040)], labels=True)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw_brand(draw, 72, 78)
    draw_heading(
        canvas,
        [("Turn places", COLORS["ink"]), ("into memory", COLORS["ink"]), ("paths", COLORS["red"])],
        "Place what you study inside scenes you already know.",
        y=212,
        size=104,
    )
    draw_callout(canvas, (74, 950), COLORS["green"], "Routes", "Build ordered paths with place photos.")
    draw_callout(canvas, (74, 1218), COLORS["blue"], "Notes", "Put key ideas inside each scene.")
    draw_callout(canvas, (74, 1490), COLORS["gold"], "Review", "Walk the route and recall.")
    phone = make_device(RAW_DIR / "04-review.png", (720, 1566))
    paste_rotated(canvas, phone, (900, 1712), -5)
    draw_study_card(canvas, (102, 2460, 502, 2642), "Cafe Corner", "Vocab Recall")
    return canvas


def render_02() -> Image.Image:
    canvas = gradient_base()
    add_map_texture(canvas, opacity=115, blur=1)
    add_route(canvas, [(190, 870), (410, 1070), (640, 1240), (870, 1450), (1040, 1790)], labels=True)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw_brand(draw, 72, 78)
    draw_heading(
        canvas,
        [("Map the route", COLORS["ink"]), ("your memory", COLORS["ink"]), ("follows", COLORS["red"])],
        "Every photo becomes a waypoint for recall.",
        y=194,
        size=98,
    )
    phone = make_device(RAW_DIR / "02-memory-map.png", (760, 1652))
    paste_rotated(canvas, phone, (642, 1710), 0)
    return canvas


def render_03() -> Image.Image:
    canvas = gradient_base()
    add_map_texture(canvas, opacity=54, blur=5)
    add_corner_photo(canvas, SEED_DIR / SEED_IMAGES[3], (1065, 640), (340, 260), 6)
    add_route(canvas, [(1030, 360), (970, 820), (1034, 1280), (928, 1750)], labels=False)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw_brand(draw, 72, 78)
    draw_heading(
        canvas,
        [("Switch themes", COLORS["ink"]), ("on the same", COLORS["ink"]), ("route", COLORS["red"])],
        "Use one familiar path for language, exams, and review.",
        y=190,
        size=94,
    )
    phone = make_device(RAW_DIR / "03-route-detail.png", (710, 1544))
    paste_rotated(canvas, phone, (770, 1730), 4)
    return canvas


def render_04() -> Image.Image:
    canvas = gradient_base()
    add_map_texture(canvas, opacity=60, blur=4)
    add_background_photos(canvas)
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw_brand(draw, 72, 78)
    draw_heading(
        canvas,
        [("Reveal answers", COLORS["ink"]), ("where they", COLORS["ink"]), ("live", COLORS["red"])],
        "Move scene by scene through what you placed.",
        y=190,
        size=98,
    )
    phone = make_device(RAW_DIR / "04-review.png", (760, 1652))
    paste_rotated(canvas, phone, (635, 1715), 0)
    return canvas


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    renders = [
        ("01-memory-path.png", render_01),
        ("02-memory-map.png", render_02),
        ("03-themes.png", render_03),
        ("04-review.png", render_04),
    ]
    for name, render in renders:
        output = OUT_DIR / name
        render().convert("RGB").save(output, "PNG", optimize=True)
        print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

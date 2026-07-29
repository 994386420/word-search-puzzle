#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
LAUNCH_LIGHT_BG = "#FFF0B8"
LAUNCH_DARK_BG = "#35172F"
FONT_PATHS = [
    Path("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"),
    Path("/System/Library/Fonts/SFNSRounded.ttf"),
    Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def save_webp(
    image: Image.Image,
    path: Path,
    *,
    lossless: bool = False,
    quality: int = 92,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(
        path,
        format="WEBP",
        lossless=lossless,
        quality=100 if lossless else quality,
        method=6,
        exact=lossless,
    )


def vertical_gradient(
    size: tuple[int, int],
    stops: list[tuple[float, str]],
) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    parsed = [(stop, hex_to_rgb(color)) for stop, color in stops]
    for y in range(height):
        t = y / max(1, height - 1)
        left = parsed[0]
        right = parsed[-1]
        for index in range(len(parsed) - 1):
            if parsed[index][0] <= t <= parsed[index + 1][0]:
                left = parsed[index]
                right = parsed[index + 1]
                break
        local_t = (t - left[0]) / max(0.0001, right[0] - left[0])
        color = tuple(lerp(left[1][i], right[1][i], local_t) for i in range(3))
        draw.line([(0, y), (width, y)], fill=color)
    return image


def rounded_rect_layer(
    size: tuple[int, int],
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int],
    shadow: tuple[int, int, int, int] | None = None,
    shadow_offset: tuple[int, int] = (0, 18),
    shadow_blur: int = 26,
) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    if shadow:
        shadow_layer = Image.new("RGBA", size, (0, 0, 0, 0))
        shadow_box = (
            box[0] + shadow_offset[0],
            box[1] + shadow_offset[1],
            box[2] + shadow_offset[0],
            box[3] + shadow_offset[1],
        )
        ImageDraw.Draw(shadow_layer).rounded_rectangle(
            shadow_box,
            radius=radius,
            fill=shadow,
        )
        layer.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(shadow_blur)))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=fill)
    return layer


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    text: str,
    fill: tuple[int, int, int, int],
    text_font: ImageFont.FreeTypeFont,
    y_nudge: float = 0,
) -> None:
    bounds = draw.textbbox((0, 0), text, font=text_font)
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    x = box[0] + (box[2] - box[0] - width) / 2 - bounds[0]
    y = box[1] + (box[3] - box[1] - height) / 2 - bounds[1] + y_nudge
    draw.text((x, y), text, font=text_font, fill=fill)


def star_points(cx: float, cy: float, outer: float, inner: float, points: int = 5):
    result = []
    for i in range(points * 2):
        radius = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / points
        result.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return result


def add_soft_glow(
    image: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int, int],
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = center
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius // 2)))


def draw_letter_tile(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    letter: str,
    fill: tuple[int, int, int, int],
    *,
    radius: float,
    text_font: ImageFont.FreeTypeFont,
    text_fill: tuple[int, int, int, int] = (255, 255, 255, 255),
    shadow: bool = True,
    shadow_fill: tuple[int, int, int, int] = (67, 112, 112, 35),
    outline_fill: tuple[int, int, int, int] = (255, 255, 255, 205),
) -> None:
    if shadow:
        shadow_box = (box[0], box[1] + radius * 0.18, box[2], box[3] + radius * 0.18)
        draw.rounded_rectangle(shadow_box, radius=radius, fill=shadow_fill)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline_fill, width=max(1, round(radius * 0.08)))
    draw_centered_text(draw, box, letter, text_fill, text_font, -radius * 0.03)


def draw_open_book(
    image: Image.Image,
    *,
    scale: float,
    offset: tuple[float, float],
    page_alpha: int = 255,
    dark: bool = False,
) -> None:
    ox, oy = offset
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    def p(x: float, y: float) -> tuple[float, float]:
        return (ox + x * scale, oy + y * scale)

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (*p(90, 292), *p(558, 404)),
        fill=(255, 196, 112, 48) if dark else (87, 102, 80, 42),
    )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(round(24 * scale))))

    cover = [
        p(96, 120),
        p(282, 82),
        p(334, 128),
        p(520, 86),
        p(570, 292),
        p(342, 342),
        p(288, 302),
        p(58, 338),
    ]
    draw.polygon(cover, fill=(103, 220, 221, 248) if dark else (126, 223, 216, 245))
    draw.line(
        [p(334, 128), p(342, 342)],
        fill=(255, 255, 255, 82) if dark else (14, 132, 143, 100),
        width=max(1, round(4 * scale)),
    )

    left_page = [
        p(104, 116),
        p(286, 84),
        p(328, 130),
        p(332, 318),
        p(286, 286),
        p(88, 316),
    ]
    right_page = [
        p(340, 130),
        p(518, 90),
        p(556, 292),
        p(344, 318),
    ]
    draw.polygon(left_page, fill=(255, 239, 193, min(page_alpha, 242)) if dark else (255, 249, 221, page_alpha))
    draw.polygon(right_page, fill=(255, 227, 178, min(page_alpha, 236)) if dark else (255, 242, 212, page_alpha))
    draw.line(
        [p(334, 130), p(340, 318)],
        fill=(255, 255, 255, 205),
        width=max(1, round(8 * scale)),
    )

    for y, color in [
        (162, (17, 207, 232, 180)),
        (206, (17, 207, 232, 130)),
        (250, (248, 139, 184, 130)),
    ]:
        draw.line([p(148, y), p(252, y + 13)], fill=color, width=max(2, round(8 * scale)))
    for y, color in [
        (164, (248, 139, 184, 160)),
        (210, (248, 139, 184, 125)),
        (254, (255, 184, 77, 150)),
    ]:
        draw.line([p(394, y + 12), p(502, y - 4)], fill=color, width=max(2, round(8 * scale)))

    draw.ellipse(
        (*p(318, 236), *p(356, 274)),
        fill=(255, 251, 230, 244),
        outline=(255, 169, 97, 150) if dark else (17, 132, 143, 145),
        width=max(1, round(3 * scale)),
    )
    image.alpha_composite(layer)


def draw_orbit(
    image: Image.Image,
    *,
    scale: float,
    box: tuple[float, float, float, float],
    color: tuple[int, int, int, int],
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    scaled_box = tuple(v * scale for v in box)
    for inset, alpha, width in [(0, color[3], 4), (18, round(color[3] * 0.48), 2)]:
        draw.arc(
            (
                scaled_box[0] + inset * scale,
                scaled_box[1] + inset * scale,
                scaled_box[2] - inset * scale,
                scaled_box[3] - inset * scale,
            ),
            start=196,
            end=344,
            fill=(color[0], color[1], color[2], alpha),
            width=max(1, round(width * scale)),
        )
    image.alpha_composite(layer)


def draw_project_logo(
    image: Image.Image,
    *,
    center: tuple[float, float],
    scale: float,
    include_shadow: bool = True,
    dark: bool = False,
) -> None:
    draw = ImageDraw.Draw(image)
    cx, cy = center
    word_tile = 116 * scale
    word_gap = 18 * scale
    word_y = cy - 128 * scale
    word_x = cx - (word_tile * 4 + word_gap * 3) / 2
    word_font = font(round(78 * scale))
    word_colors = (
        [
            (255, 156, 207, 252),
            (112, 226, 231, 252),
            (255, 156, 207, 252),
            (255, 214, 136, 252),
        ]
        if dark
        else [
            (255, 142, 199, 246),
            (120, 218, 219, 246),
            (255, 142, 199, 246),
            (255, 210, 145, 246),
        ]
    )
    for index, letter in enumerate("WORD"):
        x = word_x + index * (word_tile + word_gap)
        y = word_y + (0 if index in (0, 2) else -8 * scale) + (8 * scale if index == 3 else 0)
        draw_letter_tile(
            draw,
            (x, y, x + word_tile, y + word_tile),
            letter,
            word_colors[index],
            radius=round(30 * scale),
            text_font=word_font,
            shadow=include_shadow,
            shadow_fill=(16, 8, 28, 70) if dark else (67, 112, 112, 35),
            outline_fill=(255, 243, 214, 210) if dark else (255, 255, 255, 205),
        )

    pill_w = 602 * scale
    pill_h = 148 * scale
    pill_x = cx - pill_w / 2
    pill_y = cy + 22 * scale
    if include_shadow:
        shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle(
            (
                pill_x,
                pill_y + 16 * scale,
                pill_x + pill_w,
                pill_y + pill_h + 16 * scale,
            ),
            radius=42 * scale,
            fill=(12, 6, 22, 82) if dark else (26, 118, 133, 42),
        )
        image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(round(18 * scale))))
        draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (pill_x, pill_y, pill_x + pill_w, pill_y + pill_h),
        radius=42 * scale,
        fill=(92, 42, 96, 218) if dark else (255, 255, 246, 222),
        outline=(255, 224, 164, 148) if dark else (255, 255, 255, 230),
        width=max(1, round(4 * scale)),
    )
    search_tile = 76 * scale
    search_gap = 14 * scale
    search_x = cx - (search_tile * 6 + search_gap * 5) / 2
    search_y = pill_y + (pill_h - search_tile) / 2
    search_font = font(round(52 * scale))
    for index, letter in enumerate("SEARCH"):
        color_t = index / 5
        fill = (
            (
                lerp(49, 255, color_t * 0.16),
                lerp(224, 189, color_t * 0.16),
                lerp(232, 133, color_t * 0.16),
                238,
            )
            if dark
            else (
                lerp(17, 124, color_t * 0.22),
                lerp(207, 108, color_t * 0.22),
                lerp(232, 244, color_t * 0.22),
                232,
            )
        )
        draw_letter_tile(
            draw,
            (
                search_x + index * (search_tile + search_gap),
                search_y,
                search_x + index * (search_tile + search_gap) + search_tile,
                search_y + search_tile,
            ),
            letter,
            fill,
            radius=round(20 * scale),
            text_font=search_font,
            shadow=False,
            outline_fill=(255, 244, 213, 168) if dark else (255, 255, 255, 205),
        )


def draw_mascot_mark(
    image: Image.Image,
    *,
    center: tuple[float, float],
    scale: float,
    include_shadow: bool = True,
    dark: bool = False,
) -> None:
    cx, cy = center
    local = Image.new("RGBA", image.size, (0, 0, 0, 0))
    if include_shadow:
        glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow)
        glow_draw.ellipse(
            (
                cx - 280 * scale,
                cy - 220 * scale,
                cx + 280 * scale,
                cy + 240 * scale,
            ),
            fill=(255, 179, 87, 54) if dark else (255, 244, 177, 58),
        )
        image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(round(44 * scale))))

    draw_orbit(
        local,
        scale=scale,
        box=(
            (cx / scale) - 350,
            (cy / scale) - 218,
            (cx / scale) + 350,
            (cy / scale) + 190,
        ),
        color=(255, 211, 129, 112) if dark else (219, 130, 150, 96),
    )
    draw = ImageDraw.Draw(local)
    tile_font = font(round(44 * scale))
    tile_specs = (
        [
            ("B", -250, -156, (255, 151, 205, 248)),
            ("E", 0, -206, (255, 213, 128, 244)),
            ("C", 250, -156, (255, 151, 205, 248)),
            ("N", -346, 26, (92, 225, 229, 246)),
            ("A", 346, 26, (92, 225, 229, 246)),
            ("U", -214, 214, (255, 151, 205, 248)),
            ("T", 214, 214, (255, 151, 205, 248)),
        ]
        if dark
        else [
            ("B", -250, -156, (255, 166, 207, 238)),
            ("E", 0, -206, (255, 222, 158, 232)),
            ("C", 250, -156, (255, 166, 207, 238)),
            ("N", -346, 26, (126, 222, 221, 236)),
            ("A", 346, 26, (126, 222, 221, 236)),
            ("U", -214, 214, (255, 166, 207, 238)),
            ("T", 214, 214, (255, 166, 207, 238)),
        ]
    )
    for letter, dx, dy, color in tile_specs:
        side = 86 * scale
        x = cx + dx * scale - side / 2
        y = cy + dy * scale - side / 2
        draw_letter_tile(
            draw,
            (x, y, x + side, y + side),
            letter,
            color,
            radius=round(22 * scale),
            text_font=tile_font,
            shadow=True,
            shadow_fill=(13, 8, 22, 76) if dark else (67, 112, 112, 35),
            outline_fill=(255, 240, 208, 178) if dark else (255, 255, 255, 205),
        )
    image.alpha_composite(local)
    draw_open_book(
        image,
        scale=1.0 * scale,
        offset=((cx - 306 * scale), (cy - 82 * scale)),
        dark=dark,
    )

    path_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    path_draw = ImageDraw.Draw(path_layer)
    path_points = [
        (cx, cy - 206 * scale),
        (cx + 2 * scale, cy - 54 * scale),
        (cx + 4 * scale, cy + 118 * scale),
        (cx - 8 * scale, cy + 238 * scale),
    ]
    path_draw.line(
        path_points,
        fill=(255, 214, 140, 124) if dark else (22, 141, 145, 118),
        width=max(2, round(5 * scale)),
    )
    for x, y in path_points[1:3]:
        path_draw.ellipse(
            (x - 9 * scale, y - 9 * scale, x + 9 * scale, y + 9 * scale),
            fill=(255, 255, 255, 240),
            outline=(255, 173, 95, 148) if dark else (22, 141, 145, 140),
            width=max(1, round(3 * scale)),
        )
    image.alpha_composite(path_layer)

    draw = ImageDraw.Draw(image)
    ribbon_w = 286 * scale
    ribbon_h = 82 * scale
    ribbon_box = (
        cx - ribbon_w / 2,
        cy + 222 * scale,
        cx + ribbon_w / 2,
        cy + 222 * scale + ribbon_h,
    )
    if include_shadow:
        ribbon_shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
        ribbon_draw = ImageDraw.Draw(ribbon_shadow)
        ribbon_draw.rounded_rectangle(
            (
                ribbon_box[0],
                ribbon_box[1] + 12 * scale,
                ribbon_box[2],
                ribbon_box[3] + 12 * scale,
            ),
            radius=41 * scale,
            fill=(9, 5, 20, 82) if dark else (126, 42, 83, 50),
        )
        image.alpha_composite(ribbon_shadow.filter(ImageFilter.GaussianBlur(round(14 * scale))))
        draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        ribbon_box,
        radius=41 * scale,
        fill=(212, 75, 138, 246) if dark else (183, 67, 124, 236),
    )
    draw_centered_text(
        draw,
        ribbon_box,
        "FIND",
        (255, 255, 255, 255),
        font(round(48 * scale)),
        -2 * scale,
    )


def draw_brand_mark(
    size: int,
    *,
    include_card: bool,
    include_shadow: bool,
    transparent: bool = False,
    dark: bool = False,
) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_mascot_mark(
        image,
        center=(size * 0.5, size * 0.48),
        scale=size / 1024,
        include_shadow=include_shadow,
        dark=dark,
    )

    if transparent:
        return image
    return image


def create_icon(size: int) -> Image.Image:
    base = vertical_gradient(
        (size, size),
        [(0, "#F9D9CD"), (0.52, "#FFF0B8"), (1, "#DDF1BE")],
    ).convert("RGBA")
    add_soft_glow(base, (round(size * 0.5), round(size * 0.2)), round(size * 0.42), (255, 255, 255, 60))
    add_soft_glow(base, (round(size * 0.78), round(size * 0.74)), round(size * 0.26), (134, 223, 220, 50))

    draw = ImageDraw.Draw(base)
    for cx, cy, radius, fill in [
        (145, 178, 10, (255, 255, 255, 125)),
        (858, 378, 8, (255, 255, 255, 110)),
        (190, 778, 8, (255, 255, 255, 105)),
        (840, 770, 11, (255, 255, 255, 130)),
    ]:
        s = size / 1024
        draw.ellipse(
            (
                (cx - radius) * s,
                (cy - radius) * s,
                (cx + radius) * s,
                (cy + radius) * s,
            ),
            fill=fill,
        )

    draw_project_logo(
        base,
        center=(size * 0.5, size * 0.49),
        scale=size / 1024 * 1.34,
        include_shadow=True,
    )
    return base.convert("RGB")


def create_foreground(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_project_logo(
        canvas,
        center=(size * 0.5, size * 0.49),
        scale=size / 1024 * 1.28,
        include_shadow=False,
    )
    return canvas


def create_launch_logo(size: int, *, dark: bool = False) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if dark:
        add_soft_glow(canvas, (round(size * 0.5), round(size * 0.42)), round(size * 0.38), (255, 186, 92, 30))
        add_soft_glow(canvas, (round(size * 0.54), round(size * 0.70)), round(size * 0.34), (64, 222, 231, 24))
    draw_project_logo(
        canvas,
        center=(size * 0.5, size * 0.24),
        scale=size / 1024 * 0.62,
        include_shadow=True,
        dark=dark,
    )
    draw_mascot_mark(
        canvas,
        center=(size * 0.5, size * 0.62),
        scale=size / 1024 * 0.72,
        include_shadow=True,
        dark=dark,
    )
    return canvas


def create_launch_preview(path: Path, *, dark: bool = False) -> None:
    width, height = 1170, 2532
    image = (
        vertical_gradient(
            (width, height),
            [(0, "#35172F"), (0.58, "#2B142B"), (1, "#1D1026")],
        ).convert("RGBA")
        if dark
        else vertical_gradient(
            (width, height),
            [(0, "#F9D9CD"), (0.5, LAUNCH_LIGHT_BG), (1, "#DDF1BE")],
        ).convert("RGBA")
    )
    if dark:
        add_soft_glow(image, (width // 2, 340), 430, (255, 182, 92, 36))
        add_soft_glow(image, (250, 1810), 360, (37, 221, 232, 24))
        add_soft_glow(image, (900, 1770), 330, (255, 118, 183, 26))
    else:
        add_soft_glow(image, (width // 2, 340), 430, (255, 255, 255, 68))
        add_soft_glow(image, (250, 1810), 360, (17, 207, 232, 36))
        add_soft_glow(image, (900, 1770), 330, (255, 166, 207, 34))
    draw_project_logo(
        image,
        center=(width * 0.5, 620),
        scale=0.86,
        include_shadow=True,
        dark=dark,
    )
    draw_mascot_mark(
        image,
        center=(width * 0.5, 1036),
        scale=0.82,
        include_shadow=True,
        dark=dark,
    )
    draw = ImageDraw.Draw(image)
    title_font = font(86)
    body_font = font(34)
    draw_centered_text(
        draw,
        (0, 1426, width, 1542),
        "Word Search",
        (255, 230, 168, 255) if dark else (8, 112, 131, 255),
        title_font,
    )
    draw_centered_text(
        draw,
        (0, 1530, width, 1606),
        "Find words. Collect sparks.",
        (255, 238, 206, 218) if dark else (21, 94, 117, 220),
        body_font,
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path)


def resize_save(source: Image.Image, path: Path, size: int, *, rgb: bool = True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = source.resize((size, size), Image.Resampling.LANCZOS)
    if rgb:
        image = image.convert("RGB")
    image.save(path)


def write_ios_icons(source: Image.Image) -> None:
    contents_path = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    data = json.loads(contents_path.read_text())
    for item in data["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        base_size = float(item["size"].split("x")[0])
        scale = int(item["scale"].replace("x", ""))
        pixels = round(base_size * scale)
        resize_save(source, contents_path.parent / filename, pixels)


def write_android_icons(source: Image.Image) -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in sizes.items():
        resize_save(source, ROOT / f"android/app/src/main/res/{folder}/ic_launcher.png", size)


def write_web_icons(source: Image.Image) -> None:
    resize_save(source, ROOT / "web/favicon.png", 64)
    resize_save(source, ROOT / "web/icons/Icon-192.png", 192)
    resize_save(source, ROOT / "web/icons/Icon-512.png", 512)
    resize_save(source, ROOT / "web/icons/Icon-maskable-192.png", 192)
    resize_save(source, ROOT / "web/icons/Icon-maskable-512.png", 512)


def write_android_launch_logos() -> None:
    density_sizes = {
        "drawable-mdpi": 360,
        "drawable-hdpi": 540,
        "drawable-xhdpi": 720,
        "drawable-xxhdpi": 1080,
        "drawable-xxxhdpi": 1440,
    }
    for folder, pixels in density_sizes.items():
        light_path = ROOT / f"android/app/src/main/res/{folder}/launch_logo.png"
        light_path.parent.mkdir(parents=True, exist_ok=True)
        create_launch_logo(pixels).save(light_path)

        night_folder = folder.replace("drawable-", "drawable-night-")
        dark_path = ROOT / f"android/app/src/main/res/{night_folder}/launch_logo.png"
        dark_path.parent.mkdir(parents=True, exist_ok=True)
        create_launch_logo(pixels, dark=True).save(dark_path)


def write_ios_launch_imageset_contents() -> None:
    contents_path = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json"
    contents = {
        "images": [
            {
                "idiom": "universal",
                "filename": "LaunchImage.png",
                "scale": "1x",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "idiom": "universal",
                "filename": "LaunchImage-dark.png",
                "scale": "1x",
            },
            {
                "idiom": "universal",
                "filename": "LaunchImage@2x.png",
                "scale": "2x",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "idiom": "universal",
                "filename": "LaunchImage-dark@2x.png",
                "scale": "2x",
            },
            {
                "idiom": "universal",
                "filename": "LaunchImage@3x.png",
                "scale": "3x",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "idiom": "universal",
                "filename": "LaunchImage-dark@3x.png",
                "scale": "3x",
            },
        ],
        "info": {
            "version": 1,
            "author": "xcode",
        },
    }
    contents_path.write_text(json.dumps(contents, indent=2) + "\n")


def rounded_icon(source: Image.Image, size: int, *, radius: float = 0.22) -> Image.Image:
    image = ImageOps.fit(
        source.convert("RGB"),
        (size, size),
        method=Image.Resampling.LANCZOS,
    ).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=round(size * radius),
        fill=255,
    )
    image.putalpha(mask)
    return image


def create_brand_launch_mark(
    source: Image.Image,
    size: int,
    *,
    dark: bool = False,
) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    card_size = round(size * 0.72)
    left = (size - card_size) // 2
    top = (size - card_size) // 2
    radius = round(card_size * 0.22)

    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_color = (75, 226, 220, 80) if dark else (255, 190, 79, 78)
    ImageDraw.Draw(glow).ellipse(
        (size * 0.16, size * 0.16, size * 0.84, size * 0.84),
        fill=glow_color,
    )
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(round(size * 0.1))))

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + size * 0.035, left + card_size, top + card_size + size * 0.035),
        radius=radius,
        fill=(20, 10, 35, 92 if dark else 54),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(round(size * 0.035))))
    canvas.alpha_composite(rounded_icon(source, card_size), (left, top))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, top, left + card_size - 1, top + card_size - 1),
        radius=radius,
        outline=(255, 255, 255, 150 if dark else 205),
        width=max(2, round(size * 0.008)),
    )
    return canvas


def create_brand_launch_preview(
    source: Image.Image,
    path: Path,
    *,
    dark: bool = False,
) -> None:
    width, height = 1170, 2532
    image = vertical_gradient(
        (width, height),
        [(0, "#21152F"), (0.56, "#351D48"), (1, "#162E39")]
        if dark
        else [(0, "#FFE3C2"), (0.52, "#FFF4C9"), (1, "#D8F3DE")],
    ).convert("RGBA")
    add_soft_glow(
        image,
        (width // 2, 720),
        520,
        (45, 214, 218, 32 if dark else 48),
    )
    mark = create_brand_launch_mark(source, 650, dark=dark)
    image.alpha_composite(mark, ((width - 650) // 2, 440))
    draw = ImageDraw.Draw(image)
    title_color = (255, 244, 216, 255) if dark else (45, 42, 71, 255)
    body_color = (218, 232, 232, 225) if dark else (61, 102, 105, 225)
    draw_centered_text(
        draw,
        (0, 1180, width, 1320),
        "Word Search",
        title_color,
        font(88),
    )
    draw_centered_text(
        draw,
        (0, 1310, width, 1390),
        "See it. Hear it. Find it.",
        body_color,
        font(36),
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    save_webp(image.convert("RGB"), path)


def create_icon_size_check(source: Image.Image, path: Path) -> None:
    width, height = 720, 280
    image = vertical_gradient(
        (width, height),
        [(0, "#FFF4D2"), (1, "#DFF3E0")],
    ).convert("RGBA")
    draw = ImageDraw.Draw(image)
    for size, x in [(180, 70), (112, 330), (64, 550)]:
        icon = rounded_icon(source, size)
        y = (height - size) // 2 - 12
        image.alpha_composite(icon, (x, y))
        draw_centered_text(
            draw,
            (x, y + size + 4, x + size, height - 4),
            f"{size}px",
            (54, 72, 82, 220),
            font(18),
        )
    save_webp(image.convert("RGB"), path)


def create_project_home_reference(source: Image.Image, path: Path) -> None:
    width, height = 1280, 720
    image = vertical_gradient(
        (width, height),
        [(0, "#FFE1C4"), (0.48, "#FFF3C8"), (1, "#D9F3DE")],
    ).convert("RGBA")
    icon = rounded_icon(source, 150)
    image.alpha_composite(icon, (70, 54))
    draw = ImageDraw.Draw(image)
    draw.text((250, 72), "Word Search", font=font(54), fill=(44, 42, 70, 255))
    draw.text(
        (252, 140),
        "See it. Hear it. Find it.",
        font=font(24),
        fill=(54, 105, 109, 225),
    )

    names = ["Animals", "Food", "Nature", "Sports", "Space", "STEM"]
    category_dir = ROOT / "assets/categories"
    for index, name in enumerate(names):
        column = index % 3
        row = index // 3
        x = 70 + column * 405
        y = 250 + row * 205
        card_w, card_h = 370, 172
        card = ImageOps.fit(
            Image.open(category_dir / f"{name.lower() if name != 'STEM' else 'tech'}.webp").convert("RGB"),
            (card_w, card_h),
            method=Image.Resampling.LANCZOS,
        ).convert("RGBA")
        mask = Image.new("L", (card_w, card_h), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, card_w - 1, card_h - 1), radius=18, fill=255
        )
        card.putalpha(mask)
        image.alpha_composite(card, (x, y))
        overlay = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
        ImageDraw.Draw(overlay).rounded_rectangle(
            (0, card_h - 48, card_w, card_h),
            radius=18,
            fill=(25, 23, 43, 150),
        )
        image.alpha_composite(overlay, (x, y))
        draw.text((x + 18, y + card_h - 39), name, font=font(22), fill="white")
    save_webp(image.convert("RGB"), path)


def write_macos_icons(source: Image.Image) -> None:
    contents_path = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    data = json.loads(contents_path.read_text())
    for item in data["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        base_size = float(item["size"].split("x")[0])
        scale = int(item["scale"].replace("x", ""))
        resize_save(source, contents_path.parent / filename, round(base_size * scale))


def write_windows_icon(source: Image.Image) -> None:
    path = ROOT / "windows/runner/resources/app_icon.ico"
    path.parent.mkdir(parents=True, exist_ok=True)
    source.convert("RGBA").save(
        path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def write_brand_launch_assets(source: Image.Image, brand_dir: Path) -> None:
    write_ios_launch_imageset_contents()
    for scale, pixels in [(1, 184), (2, 368), (3, 552)]:
        suffix = "" if scale == 1 else f"@{scale}x"
        create_brand_launch_mark(source, pixels).save(
            ROOT / f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png"
        )
        create_brand_launch_mark(source, pixels, dark=True).save(
            ROOT / f"ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage-dark{suffix}.png"
        )

    for folder, pixels in {
        "drawable-mdpi": 360,
        "drawable-hdpi": 540,
        "drawable-xhdpi": 720,
        "drawable-xxhdpi": 1080,
        "drawable-xxxhdpi": 1440,
    }.items():
        light_path = ROOT / f"android/app/src/main/res/{folder}/launch_logo.png"
        light_path.parent.mkdir(parents=True, exist_ok=True)
        create_brand_launch_mark(source, pixels).save(light_path)
        dark_path = ROOT / f"android/app/src/main/res/{folder.replace('drawable-', 'drawable-night-')}/launch_logo.png"
        dark_path.parent.mkdir(parents=True, exist_ok=True)
        create_brand_launch_mark(source, pixels, dark=True).save(dark_path)

    create_brand_launch_mark(source, 360).save(
        ROOT / "android/app/src/main/res/drawable-nodpi/launch_logo.png"
    )
    dark_nodpi = ROOT / "android/app/src/main/res/drawable-night-nodpi/launch_logo.png"
    dark_nodpi.parent.mkdir(parents=True, exist_ok=True)
    create_brand_launch_mark(source, 360, dark=True).save(dark_nodpi)

    web_splash_dir = ROOT / "web/splash"
    web_splash_dir.mkdir(parents=True, exist_ok=True)
    create_brand_launch_mark(source, 420).save(web_splash_dir / "launch_logo_light.png")
    create_brand_launch_mark(source, 420, dark=True).save(
        web_splash_dir / "launch_logo_dark.png"
    )

    save_webp(
        create_brand_launch_mark(source, 384),
        brand_dir / "launch_mark.webp",
        lossless=True,
    )
    save_webp(
        create_brand_launch_mark(source, 384),
        brand_dir / "launch_mark_light.webp",
        lossless=True,
    )
    save_webp(
        create_brand_launch_mark(source, 384, dark=True),
        brand_dir / "launch_mark_dark.webp",
        lossless=True,
    )
    create_brand_launch_preview(source, brand_dir / "launch_preview.webp")
    create_brand_launch_preview(source, brand_dir / "launch_preview_light.webp")
    create_brand_launch_preview(
        source,
        brand_dir / "launch_preview_dark.webp",
        dark=True,
    )


def main() -> None:
    brand_dir = ROOT / "assets/brand"
    source_path = brand_dir / "app_icon_source.webp"
    if not source_path.exists():
        raise FileNotFoundError(f"Missing app icon master: {source_path}")
    source_icon = ImageOps.fit(
        Image.open(source_path).convert("RGB"),
        (1024, 1024),
        method=Image.Resampling.LANCZOS,
    )
    save_webp(source_icon, source_path, lossless=True)
    save_webp(source_icon, brand_dir / "app_icon_preview.webp")
    create_icon_size_check(source_icon, brand_dir / "app_icon_size_check.webp")

    write_ios_icons(source_icon)
    write_macos_icons(source_icon)
    write_android_icons(source_icon)
    write_web_icons(source_icon)
    write_windows_icon(source_icon)

    adaptive_foreground = create_brand_launch_mark(source_icon, 432)
    adaptive_foreground.save(
        ROOT / "android/app/src/main/res/drawable/ic_launcher_foreground.png"
    )
    write_brand_launch_assets(source_icon, brand_dir)
    create_project_home_reference(
        source_icon,
        brand_dir / "project_home_reference.webp",
    )

    print("Generated brand assets for iOS, Android, macOS, Windows, and Web.")


if __name__ == "__main__":
    main()

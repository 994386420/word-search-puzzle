from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageStat


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/store/screenshots/phone-04-daily-rewards.webp"
OUTPUT = ROOT / "assets/ui/clay/daily_reward_board_exact.webp"

# The route runs left-to-right across the top row, then right-to-left across
# the bottom row. Coordinates are relative to the 970 x 780 board crop.
NODE_CENTERS = (
    (166, 244),
    (377, 244),
    (586, 244),
    (783, 244),
    (704, 555),
    (470, 555),
    (219, 555),
)

STATE_SOURCES = {
    "complete": (377, 244),
    "active": (783, 244),
    "future": (470, 555),
}

PATCH_SIZE = (300, 330)


def _save_webp(image, path):
    image.save(
        path,
        format="WEBP",
        lossless=True,
        quality=100,
        method=6,
        exact=True,
    )


def _crop_board():
    source = Image.open(SOURCE).convert("RGBA")
    board = source.crop((55, 450, 1025, 1230))
    clean_edge = board.crop((430, 718, 540, 758))
    patched = board.copy()
    patched.paste(clean_edge, (590, 718))
    patch_mask = Image.new("L", board.size)
    ImageDraw.Draw(patch_mask).rectangle((594, 722, 696, 754), fill=255)
    board = Image.composite(
        patched,
        board,
        patch_mask.filter(ImageFilter.GaussianBlur(5)),
    )
    mask = Image.new("L", board.size)
    ImageDraw.Draw(mask).rounded_rectangle(
        (12, 15, board.width - 12, board.height - 38),
        radius=120,
        fill=255,
    )
    board.putalpha(mask.filter(ImageFilter.GaussianBlur(1.2)))
    return board


def _state_patch(board, state):
    center_x, center_y = STATE_SOURCES[state]
    half_width = PATCH_SIZE[0] // 2
    half_height = PATCH_SIZE[1] // 2
    bounds = (
        center_x - half_width,
        center_y - half_height,
        center_x + half_width,
        center_y + half_height,
    )
    patch = board.crop(bounds)
    mask = Image.new("L", patch.size)
    draw = ImageDraw.Draw(mask)
    center = (half_width, half_height)

    if state == "active":
        # Keep the active node's glow, ring, star, and rays, but exclude the
        # source route bend so the untouched route beneath remains continuous.
        glow = Image.new("L", patch.size)
        glow_draw = ImageDraw.Draw(glow)
        glow_draw.ellipse(
            (
                center[0] - 119,
                center[1] - 119,
                center[0] + 119,
                center[1] + 119,
            ),
            fill=155,
        )
        glow_draw.ellipse(
            (
                center[0] - 76,
                center[1] - 76,
                center[0] + 76,
                center[1] + 76,
            ),
            fill=0,
        )
        mask = Image.composite(
            Image.new("L", patch.size, 255),
            mask,
            glow.filter(ImageFilter.GaussianBlur(9)),
        )
        draw = ImageDraw.Draw(mask)
        draw.ellipse(
            (
                center[0] - 102,
                center[1] - 103,
                center[0] + 102,
                center[1] + 103,
            ),
            fill=255,
        )
        draw.ellipse(
            (
                center[0] - 66,
                center[1] - 68,
                center[0] + 66,
                center[1] + 68,
            ),
            fill=0,
        )
        draw.ellipse(
            (
                center[0] - 50,
                center[1] + 55,
                center[0] + 50,
                center[1] + 130,
            ),
            fill=255,
        )
        for ray_center, ray_size in (
            ((center[0] - 77, center[1] - 112), (24, 55)),
            ((center[0], center[1] - 139), (22, 56)),
            ((center[0] + 78, center[1] - 111), (24, 55)),
        ):
            ray_x, ray_y = ray_center
            ray_width, ray_height = ray_size
            draw.ellipse(
                (
                    ray_x - ray_width // 2,
                    ray_y - ray_height // 2,
                    ray_x + ray_width // 2,
                    ray_y + ray_height // 2,
                ),
                fill=255,
            )
    else:
        radius_x = 99 if state == "complete" else 96
        draw.ellipse(
            (
                center[0] - radius_x,
                center[1] - 108,
                center[0] + radius_x,
                center[1] + 99,
            ),
            fill=255,
        )
        draw.ellipse(
            (
                center[0] - 49,
                center[1] + 54,
                center[0] + 49,
                center[1] + 128,
            ),
            fill=255,
        )

    return patch, mask.filter(ImageFilter.GaussianBlur(3))


def _neutral_patch(board, size):
    swatch = board.crop((320, 365, 650, 435)).convert("RGB")
    mean = tuple(round(channel) for channel in ImageStat.Stat(swatch).mean)
    result = Image.new("RGB", size, mean)

    def noise_layer(grid_size, seed, radius):
        random = Random(seed)
        noise = Image.new("L", grid_size)
        noise.putdata(
            [random.randrange(256) for _ in range(grid_size[0] * grid_size[1])]
        )
        return noise.resize(size, Image.Resampling.BICUBIC).filter(
            ImageFilter.GaussianBlur(radius)
        )

    def tinted_noise(noise, spread):
        dark = tuple(max(0, channel - spread) for channel in mean)
        light = tuple(min(255, channel + spread) for channel in mean)
        return ImageOps.colorize(noise, black=dark, white=light)

    broad = noise_layer((18, 14), 741, 7)
    grain = noise_layer(
        (max(1, size[0] // 3), max(1, size[1] // 3)),
        1907,
        0.45,
    )
    result = Image.blend(result, tinted_noise(broad, 7), 0.55)
    result = Image.blend(result, tinted_noise(grain, 11), 0.18)
    return result.convert("RGBA")


def _bezier(start, control_a, control_b, end, steps=48):
    points = []
    for index in range(steps + 1):
        progress = index / steps
        inverse = 1 - progress
        x = (
            inverse**3 * start[0]
            + 3 * inverse**2 * progress * control_a[0]
            + 3 * inverse * progress**2 * control_b[0]
            + progress**3 * end[0]
        )
        y = (
            inverse**3 * start[1]
            + 3 * inverse**2 * progress * control_a[1]
            + 3 * inverse * progress**2 * control_b[1]
            + progress**3 * end[1]
        )
        points.append((round(x), round(y)))
    return points


def _draw_route(board):
    route = [
        NODE_CENTERS[0],
        (783, 244),
        *_bezier(
            (783, 244),
            (866, 300),
            (866, 503),
            (704, 555),
        )[1:],
        NODE_CENTERS[-1],
    ]
    shadow = Image.new("RGBA", board.size)
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.line(
        [(x + 2, y + 7) for x, y in route],
        fill=(135, 91, 42, 125),
        width=30,
        joint="curve",
    )
    board.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(7)))

    line = Image.new("RGBA", board.size)
    line_draw = ImageDraw.Draw(line)
    line_draw.line(
        route,
        fill=(208, 167, 106, 255),
        width=24,
        joint="curve",
    )
    board.alpha_composite(line)

    highlight = Image.new("RGBA", board.size)
    ImageDraw.Draw(highlight).line(
        [(x - 2, y - 3) for x, y in route],
        fill=(244, 218, 176, 105),
        width=6,
        joint="curve",
    )
    board.alpha_composite(highlight.filter(ImageFilter.GaussianBlur(2)))


def _clean_board(exact_board):
    clean = exact_board.copy()
    interior_bounds = (54, 54, clean.width - 54, clean.height - 54)
    interior_size = (
        interior_bounds[2] - interior_bounds[0],
        interior_bounds[3] - interior_bounds[1],
    )
    interior_mask = Image.new("L", clean.size)
    ImageDraw.Draw(interior_mask).rounded_rectangle(
        interior_bounds,
        radius=70,
        fill=255,
    )
    interior_mask = interior_mask.filter(ImageFilter.GaussianBlur(12))
    texture_layer = clean.copy()
    texture_layer.paste(
        _neutral_patch(clean, interior_size),
        interior_bounds[:2],
    )
    clean = Image.composite(texture_layer, clean, interior_mask)
    _draw_route(clean)
    return clean


def _board_for_state(clean_board, weekday, completed_today, state_assets):
    result = clean_board.copy()
    active_index = None if completed_today else weekday - 1
    completed_count = weekday if completed_today else weekday - 1
    for index, center in enumerate(NODE_CENTERS):
        if index < completed_count:
            state = "complete"
        elif index == active_index:
            state = "active"
        else:
            state = "future"
        if state == "active":
            cover_size = (150, 154)
            cover_mask = Image.new("L", cover_size)
            ImageDraw.Draw(cover_mask).ellipse(
                (3, 3, cover_size[0] - 3, cover_size[1] - 3),
                fill=255,
            )
            result.paste(
                _neutral_patch(result, cover_size),
                (
                    center[0] - cover_size[0] // 2,
                    center[1] - cover_size[1] // 2,
                ),
                cover_mask.filter(ImageFilter.GaussianBlur(3)),
            )
        patch, mask = state_assets[state]
        position = (
            center[0] - patch.width // 2,
            center[1] - patch.height // 2,
        )
        result.paste(patch, position, mask)
    return result


def main():
    board = _crop_board()
    _save_webp(board, OUTPUT)
    state_assets = {
        state: _state_patch(board, state) for state in STATE_SOURCES
    }
    clean_board = _clean_board(board)
    for weekday in range(1, 8):
        for completed_today in (False, True):
            state = "complete" if completed_today else "active"
            output = (
                ROOT
                / "assets/ui/clay"
                / f"daily_reward_board_weekday_{weekday}_{state}.webp"
            )
            _save_webp(
                _board_for_state(
                    clean_board,
                    weekday,
                    completed_today,
                    state_assets,
                ),
                output,
            )


if __name__ == "__main__":
    main()

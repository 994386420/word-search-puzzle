#!/usr/bin/env python3
"""Generate skin-specific clay scenes one compact reference at a time."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SCENE_DIR = ROOT / "assets" / "ui" / "clay" / "scenes"
SOURCE_DIR = ROOT / "tmp" / "imagegen" / "skin-scenes" / "generated"
GENERATOR = ROOT / "tool" / "generate_image.py"

SCENES = {
    "daily-world": (
        "a celebratory daily-reward trail with one gift chest near the lower edge",
        "gift boxes, reward tokens, and a winding trail",
    ),
    "game-garden": (
        "an inviting open play garden",
        "small plants and playful word-search objects around the outer edges",
    ),
    "leaderboard-world": (
        "a cheerful ranking plaza",
        "three trophy podiums and small stars near the lower edge",
    ),
    "picture-garden": (
        "a picture-search garden",
        "colorful magnifying glasses and tiny discovery objects around the border",
    ),
    "review-world": (
        "a calm word-review study garden",
        "an open picture book, bookmarks, flash cards, and a small screen at the bottom",
    ),
    "stats-world": (
        "a playful achievement plaza",
        "books, building blocks, medals, cups, and trophies around the bottom corners",
    ),
    "theme-animals": (
        "a friendly animal habitat",
        "a lion, giraffe, elephant, and zebra kept small around the perimeter",
    ),
    "theme-food": (
        "a welcoming food market courtyard",
        "small food stalls and recognizable dishes arranged around the perimeter",
    ),
    "theme-nature": (
        "a majestic nature valley",
        "mountains, a waterfall, forest plants, and a stream framing the outer edges",
    ),
    "theme-space": (
        "a whimsical outer-space landscape",
        "a rocket, telescope, planets, and alien plants around the perimeter",
    ),
    "theme-sports": (
        "a playful multi-sport arena",
        "sports equipment and small goal, hoop, track, and court details around the perimeter",
    ),
    "theme-tech": (
        "a friendly technology garden",
        "a small robot, circuits, satellite dishes, gears, and lab objects around the perimeter",
    ),
}

SKINS = {
    "starry": (
        "a genuinely new starry dream-world scene at twilight, with a deep indigo and violet sky, "
        "soft cyan glow, constellations, tiny luminous stars, moonlit clay terrain, and a few crystal accents",
        "indigo, violet, midnight blue, cyan, and warm starlight",
    ),
    "candy": (
        "a genuinely new candy wonderland scene, with frosting hills, candy trees, sugar crystals, "
        "lollipops, mint leaves, and soft confectionery details",
        "strawberry pink, mint, lemon yellow, coral, lavender, and white frosting",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("skin", choices=(*SKINS, "all"))
    parser.add_argument("--only", choices=SCENES, action="append")
    parser.add_argument("--quality", choices=("low", "medium", "high"), default="medium")
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--use-reference",
        action="store_true",
        help="Use the compact reference-image edit endpoint instead of generation.",
    )
    return parser.parse_args()


def prompt_for(scene: str, skin: str) -> str:
    identity, objects = SCENES[scene]
    treatment, palette = SKINS[skin]
    return (
        "Portrait 2:3 premium soft 3D clay background for a children's "
        f"word-search game. Create {treatment}: {identity}, with {objects}. "
        "This must be a newly illustrated environment, not a recolor. Keep "
        "the central 55 percent open, quiet, and low-detail for game UI; keep "
        "objects small along the outer edges and bottom third. Soft magical "
        f"lighting. Palette: {palette}. No text, letters, numbers, logos, UI, "
        "people, watermark, photorealism, flat vector art, or busy center."
    )


def convert_to_runtime(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as opened:
        image = ImageOps.exif_transpose(opened).convert("RGB")
        if image.size != (1024, 1536):
            image = ImageOps.fit(
                image,
                (1024, 1536),
                method=Image.Resampling.LANCZOS,
            )
        image.save(destination, format="WEBP", quality=82, method=6)


def generate(
    scene: str,
    skin: str,
    quality: str,
    force: bool,
    use_reference: bool,
) -> None:
    reference = SCENE_DIR / f"{scene}-v1.webp"
    destination = SCENE_DIR / f"{scene}-{skin}-v1.webp"
    if destination.exists() and not force:
        print(f"skip {destination.relative_to(ROOT)}")
        return

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    source_name = f"{scene}-{skin}-source"
    command = [
        sys.executable,
        str(GENERATOR),
        prompt_for(scene, skin),
        "--size",
        "1024x1536",
        "--quality",
        quality,
        "--output-dir",
        str(SOURCE_DIR),
        "--name",
        source_name,
    ]
    if use_reference:
        command.extend(
            [
                "--input",
                str(reference),
                "--input-max-edge",
                "768",
                "--input-quality",
                "58",
            ]
        )
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=240,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"Generation timed out after 240 seconds for {scene}-{skin}"
        ) from error
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    if result.returncode != 0:
        raise RuntimeError(f"Generation failed for {scene}-{skin}")
    output_lines = [line for line in result.stdout.splitlines() if line.strip()]
    if not output_lines:
        raise RuntimeError(f"Generator returned no output path for {scene}-{skin}")
    source = Path(output_lines[-1])
    convert_to_runtime(source, destination)
    print(destination.resolve())


def main() -> int:
    args = parse_args()
    scenes = args.only or list(SCENES)
    skins = list(SKINS) if args.skin == "all" else [args.skin]
    failures: list[str] = []
    for skin in skins:
        for scene in scenes:
            try:
                generate(
                    scene,
                    skin,
                    args.quality,
                    args.force,
                    args.use_reference,
                )
            except (OSError, RuntimeError) as error:
                failures.append(f"{scene}-{skin}")
                print(f"Error: {error}", file=sys.stderr)
    if failures:
        print(f"Failed scenes: {', '.join(failures)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

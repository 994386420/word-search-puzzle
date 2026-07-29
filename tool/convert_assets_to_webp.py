#!/usr/bin/env python3
"""Convert legacy bitmap assets to validated WebP files."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets"
SOURCE_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--keep-originals",
        action="store_true",
        help="Validate WebP outputs without deleting the legacy files.",
    )
    return parser.parse_args()


def has_alpha(image: Image.Image) -> bool:
    return "A" in image.getbands() or "transparency" in image.info


def should_be_lossless(source: Path, image: Image.Image) -> bool:
    relative = source.relative_to(ASSET_ROOT)
    return (
        has_alpha(image)
        or "source" in relative.parts
        or relative == Path("brand/app_icon_source.png")
    )


def validate(source: Path, target: Path) -> None:
    with Image.open(source) as source_image, Image.open(target) as target_image:
        expected = ImageOps.exif_transpose(source_image)
        if target_image.format != "WEBP":
            raise ValueError(f"Not a WebP file: {target}")
        if target_image.size != expected.size:
            raise ValueError(
                f"Dimension mismatch for {target}: "
                f"{target_image.size} != {expected.size}"
            )
        if has_alpha(expected) and "A" not in target_image.getbands():
            raise ValueError(f"Alpha channel missing from {target}")
        target_image.load()


def convert(source: Path, target: Path) -> bool:
    if target.exists():
        validate(source, target)
        return False

    with Image.open(source) as opened:
        image = ImageOps.exif_transpose(opened)
        lossless = should_be_lossless(source, image)
        image = image.convert("RGBA" if has_alpha(image) else "RGB")
        temporary = target.with_name(f".{target.name}.tmp")
        image.save(
            temporary,
            format="WEBP",
            lossless=lossless,
            quality=100 if lossless else 90,
            method=6,
            exact=lossless,
        )
        temporary.replace(target)

    validate(source, target)
    return True


def main() -> int:
    args = parse_args()
    sources = sorted(
        path
        for path in ASSET_ROOT.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    )
    if not sources:
        print("No legacy bitmap assets found.")
        return 0

    original_bytes = sum(path.stat().st_size for path in sources)
    created = 0
    targets: list[Path] = []
    for source in sources:
        target = source.with_suffix(".webp")
        created += int(convert(source, target))
        targets.append(target)

    for source, target in zip(sources, targets):
        validate(source, target)

    webp_bytes = sum(path.stat().st_size for path in targets)
    if not args.keep_originals:
        for source in sources:
            source.unlink()

    action = "validated" if args.keep_originals else "converted"
    print(
        f"{action.capitalize()} {len(sources)} assets "
        f"({created} new): {original_bytes / 1024 / 1024:.1f} MiB -> "
        f"{webp_bytes / 1024 / 1024:.1f} MiB"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

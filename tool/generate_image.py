#!/usr/bin/env python3
"""Generate project images through the configured OpenAI-compatible API."""

from __future__ import annotations

import argparse
import base64
import http.client
import io
import json
import os
import secrets
import socket
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps


DEFAULT_ENDPOINT = "https://api.euzhi.com/v1/images/generations"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "assets" / "generated"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate images with the project's OpenAI-compatible image API."
    )
    parser.add_argument("prompt", help="Image generation prompt")
    parser.add_argument("--model", default="gpt-image-2")
    parser.add_argument("--size", default="1024x1024")
    parser.add_argument(
        "--quality", choices=("low", "medium", "high", "auto"), default="medium"
    )
    parser.add_argument("-n", type=int, choices=range(1, 11), default=1)
    parser.add_argument(
        "--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="Output directory"
    )
    parser.add_argument(
        "--name",
        help="Base output name without extension (default: generated timestamp)",
    )
    parser.add_argument(
        "--endpoint",
        default=os.environ.get("IMAGE_API_ENDPOINT", DEFAULT_ENDPOINT),
        help="Generation endpoint; can also be set with IMAGE_API_ENDPOINT",
    )
    parser.add_argument(
        "--input",
        type=Path,
        help="Optional reference image. It is resized and compressed before upload.",
    )
    parser.add_argument(
        "--edit-endpoint",
        default=os.environ.get("IMAGE_EDIT_API_ENDPOINT"),
        help="Image edit endpoint (default: derive /edits from --endpoint)",
    )
    parser.add_argument(
        "--input-max-edge",
        type=int,
        default=1152,
        help="Maximum reference-image edge before upload (default: 1152)",
    )
    parser.add_argument(
        "--input-quality",
        type=int,
        choices=range(30, 86),
        default=62,
        help="Reference WebP quality before upload (default: 62)",
    )
    parser.add_argument(
        "--response-format",
        choices=("url", "b64_json"),
        default="url",
        help="Prefer compact URL responses to multi-megabyte base64 JSON.",
    )
    parser.add_argument(
        "--output-format",
        choices=("png", "jpeg", "webp"),
        default="webp",
        help="Use compact WebP output by default.",
    )
    parser.add_argument(
        "--output-compression",
        type=int,
        choices=range(0, 101),
        default=80,
        help="Compression level for JPEG or WebP output (default: 80).",
    )
    return parser.parse_args()


def prepare_reference(args: argparse.Namespace) -> tuple[bytes, str]:
    if args.input is None:
        raise ValueError("Reference image is required")
    if not args.input.is_file():
        raise RuntimeError(f"Reference image does not exist: {args.input}")

    with Image.open(args.input) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
        image.thumbnail(
            (args.input_max_edge, args.input_max_edge),
            Image.Resampling.LANCZOS,
        )
        output = io.BytesIO()
        image.save(
            output,
            format="WEBP",
            quality=args.input_quality,
            method=6,
        )
    return output.getvalue(), "reference.webp"


def multipart_payload(
    fields: dict[str, str],
    *,
    image: bytes,
    image_name: str,
) -> tuple[bytes, str]:
    boundary = f"----codex-image-{secrets.token_hex(12)}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                (
                    f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
                ).encode(),
                value.encode(),
                b"\r\n",
            ]
        )
    chunks.extend(
        [
            f"--{boundary}\r\n".encode(),
            (
                'Content-Disposition: form-data; name="image"; '
                f'filename="{image_name}"\r\n'
            ).encode(),
            b"Content-Type: image/webp\r\n\r\n",
            image,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def request_generation(args: argparse.Namespace, api_key: str) -> dict[str, Any]:
    endpoint = args.endpoint
    if args.input is None:
        payload = json.dumps(
            {
                "model": args.model,
                "prompt": args.prompt,
                "size": args.size,
                "quality": args.quality,
                "n": args.n,
                "response_format": args.response_format,
                "output_format": args.output_format,
                "output_compression": args.output_compression,
            }
        ).encode("utf-8")
        content_type = "application/json"
    else:
        image, image_name = prepare_reference(args)
        endpoint = args.edit_endpoint or args.endpoint.replace(
            "/images/generations",
            "/images/edits",
        )
        payload, content_type = multipart_payload(
            {
                "model": args.model,
                "prompt": args.prompt,
                "size": args.size,
                "quality": args.quality,
                "n": str(args.n),
                "response_format": args.response_format,
                "output_format": args.output_format,
                "output_compression": str(args.output_compression),
            },
            image=image,
            image_name=image_name,
        )
        print(
            f"Prepared reference upload: {len(image) / 1024:.0f} KiB",
            file=sys.stderr,
        )
    request = urllib.request.Request(
        endpoint,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": content_type,
        },
        method="POST",
    )
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code == 413 and args.input is not None:
                raise RuntimeError(
                    "Image API returned HTTP 413 after reference compression. "
                    "Retry with a smaller --input-max-edge or lower --input-quality."
                ) from error
            raise RuntimeError(
                f"Image API returned HTTP {error.code}: {detail}"
            ) from error
        except (
            ConnectionError,
            http.client.IncompleteRead,
            urllib.error.URLError,
            http.client.RemoteDisconnected,
            socket.timeout,
            TimeoutError,
        ) as error:
            if attempt == 3:
                reason = getattr(error, "reason", error)
                raise RuntimeError(f"Could not reach image API: {reason}") from error
            print(
                f"Image API connection failed; retrying ({attempt}/3)...",
                file=sys.stderr,
            )
            time.sleep(2 * attempt)
    raise RuntimeError("Image API request failed")


def download(url: str) -> tuple[bytes, str]:
    for attempt in range(1, 4):
        try:
            with urllib.request.urlopen(url, timeout=300) as response:
                content_type = response.headers.get_content_type()
                extension = {
                    "image/jpeg": ".jpg",
                    "image/webp": ".webp",
                }.get(content_type, ".png")
                return response.read(), extension
        except (
            ConnectionError,
            http.client.IncompleteRead,
            urllib.error.URLError,
            socket.timeout,
            TimeoutError,
        ) as error:
            if attempt == 3:
                reason = getattr(error, "reason", error)
                raise RuntimeError(
                    f"Could not download generated image: {reason}"
                ) from error
            print(
                f"Image download failed; retrying ({attempt}/3)...",
                file=sys.stderr,
            )
            time.sleep(2 * attempt)
    raise RuntimeError("Generated image download failed")


def decode_image(
    item: dict[str, Any],
    output_format: str,
) -> tuple[bytes, str]:
    encoded = item.get("b64_json")
    if encoded:
        try:
            extension = ".jpg" if output_format == "jpeg" else f".{output_format}"
            return base64.b64decode(encoded, validate=True), extension
        except (ValueError, TypeError) as error:
            raise RuntimeError("Image API returned invalid base64 image data") from error

    url = item.get("url")
    if url:
        return download(url)
    raise RuntimeError("Image API response item contains neither 'b64_json' nor 'url'")


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("Error: OPENAI_API_KEY is not set.", file=sys.stderr)
        return 2

    try:
        response = request_generation(args, api_key)
        items = response.get("data")
        if not isinstance(items, list) or not items:
            raise RuntimeError(f"Image API returned no image data: {response}")

        args.output_dir.mkdir(parents=True, exist_ok=True)
        base_name = args.name or datetime.now().strftime("image-%Y%m%d-%H%M%S")
        for index, item in enumerate(items, start=1):
            if not isinstance(item, dict):
                raise RuntimeError("Image API returned an invalid image item")
            image, extension = decode_image(item, args.output_format)
            suffix = f"-{index}" if len(items) > 1 else ""
            output = args.output_dir / f"{base_name}{suffix}{extension}"
            output.write_bytes(image)
            print(output.resolve())
    except (RuntimeError, OSError, json.JSONDecodeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

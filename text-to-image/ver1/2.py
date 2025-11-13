import os
import argparse
import subprocess
from pathlib import Path
from typing import Tuple

from huggingface_hub import InferenceClient
from PIL import Image


def run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{proc.stdout}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--model", default="black-forest-labs/FLUX.1-schnell")
    parser.add_argument("--output-image", default="out.png")
    parser.add_argument("--output-video", default="out.mp4")
    parser.add_argument("--duration", type=float, default=5.0, help="Seconds")
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--zoom", type=float, default=1.2, help="Final zoom factor (>1)")
    args = parser.parse_args()

    api_key = os.environ.get("HF_API_KEY")
    if not api_key:
        raise RuntimeError("Missing HF_API_KEY environment variable")

    client = InferenceClient(provider="nebius", api_key=api_key)

    # Generate image
    img: Image.Image = client.text_to_image(args.prompt, model=args.model)
    img.save(args.output_image)
    print(f"Saved image: {args.output_image}")

    # Inspect size for ffmpeg output resolution
    with Image.open(args.output_image) as im:
        w, h = im.size

    # Build ffmpeg zoompan expression
    # We loop a single image and apply zoompan from 1.0 up to args.zoom over total frames.
    total_frames = max(1, int(args.duration * args.fps))
    # Per-frame zoom increment so that after total_frames, zoom ~ args.zoom
    # zoompan accumulates: new_zoom = previous_zoom + inc
    inc = (args.zoom - 1.0) / total_frames
    z_expr = f"zoom+{inc:.10f}"
    x_expr = "iw/2-(iw/zoom/2)"
    y_expr = "ih/2-(ih/zoom/2)"
    s_expr = f"{w}x{h}"

    vf = f"zoompan=z='{z_expr}':d=1:x='{x_expr}':y='{y_expr}':s={s_expr},fps={args.fps}"

    # Create video
    cmd = [
        "ffmpeg",
        "-y",
        "-loop", "1",
        "-t", str(args.duration),
        "-i", args.output_image,
        "-vf", vf,
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-pix_fmt", "yuv420p",
        args.output_video,
    ]

    print("Running:", " ".join(cmd))
    run(cmd)
    print(f"Saved video: {args.output_video}")


if __name__ == "__main__":
    main()

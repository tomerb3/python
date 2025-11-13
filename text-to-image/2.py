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
    parser.add_argument("--smooth", action="store_true", help="Enable motion interpolation to 60fps for smoother animation")
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
    # Generate exactly total_frames with exponential easing from 1.0 -> args.zoom.
    total_frames = max(1, int(args.duration * args.fps))
    # Exponential easing: z = exp(log(final_zoom) * t), t in [0,1]
    z_expr = f"if(eq(on,1),1,min(exp(log({args.zoom})*(on-1)/{max(1, total_frames-1)}),{args.zoom}))"
    x_expr = "iw/2-(iw/zoom/2)"
    y_expr = "ih/2-(ih/zoom/2)"
    s_expr = f"{w}x{h}"

    # Add a high-quality scaler after zoompan to reduce aliasing/jitter
    vf = (
        f"zoompan=z='{z_expr}':d=1:x='{x_expr}':y='{y_expr}':s={s_expr},"
        f"fps={args.fps},scale={w}:{h}:flags=lanczos"
    )
    if args.smooth:
        vf += ",minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"

    # Create video
    # Determine output frames (if smoothing, final fps is 60)
    output_frames = max(1, int(args.duration * (60 if args.smooth else args.fps)))

    cmd = [
        "ffmpeg",
        "-y",
        "-loop", "1",
        "-i", args.output_image,
        "-vf", vf,
        "-frames:v", str(output_frames),
        "-c:v", "libx264",
        "-crf", "18",
        "-preset", "veryfast",
        "-pix_fmt", "yuv420p",
        args.output_video,
    ]

    print("Running:", " ".join(cmd))
    run(cmd)
    print(f"Saved video: {args.output_video}")


if __name__ == "__main__":
    main()

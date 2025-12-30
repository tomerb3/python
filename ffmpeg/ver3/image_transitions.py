#!/usr/bin/env python3
import argparse
import logging
import os
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple


SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}


# Maps friendly names -> FFmpeg xfade transition names.
# Add more here as needed.
XFADE_TRANSITIONS = {
    "crossfade": "fade",
    "fade": "fade",
    "wipeleft": "wipeleft",
    "wiperight": "wiperight",
    "wipeup": "wipeup",
    "wipedown": "wipedown",
    "slideleft": "slideleft",
    "slideright": "slideright",
    "slideup": "slideup",
    "slidedown": "slidedown",
    "circleopen": "circleopen",
    "circleclose": "circleclose",
    "rectcrop": "rectcrop",
    "distance": "distance",
    "smoothleft": "smoothleft",
    "smoothright": "smoothright",
}


@dataclass(frozen=True)
class OutputConfig:
    width: int
    height: int
    fps: int
    vcodec: str
    crf: int
    preset: str
    pix_fmt: str


@dataclass(frozen=True)
class TimelineConfig:
    still_duration: float         # time each image is fully visible (excluding transition overlap)
    transition_duration: float    # duration of transition overlap
    transition_name: str          # key into XFADE_TRANSITIONS
    zoom_style: Optional[str]     # None | "in" | "out" | "inout"


class FFmpegError(RuntimeError):
    pass


def ensure_ffmpeg_available(ffmpeg_bin: str) -> None:
    if shutil.which(ffmpeg_bin) is None:
        raise FFmpegError(
            f"FFmpeg binary not found: '{ffmpeg_bin}'. "
            f"Install ffmpeg or pass --ffmpeg-bin /path/to/ffmpeg."
        )


def collect_images(folder: Optional[Path], files: List[Path], recursive: bool) -> List[Path]:
    if folder is None and not files:
        raise ValueError("You must provide either --input-folder or one or more --input-files.")

    images: List[Path] = []

    if folder is not None:
        if not folder.exists() or not folder.is_dir():
            raise ValueError(f"Input folder does not exist or is not a directory: {folder}")

        if recursive:
            candidates = folder.rglob("*")
        else:
            candidates = folder.glob("*")

        for p in candidates:
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS:
                images.append(p)

        # Deterministic ordering: filename sort (customize if you prefer EXIF/mtime/numeric)
        images.sort(key=lambda x: x.name.lower())

    if files:
        for f in files:
            images.append(f)

    # Validate + normalize
    normalized: List[Path] = []
    for p in images:
        p = p.expanduser().resolve()
        if not p.exists() or not p.is_file():
            raise ValueError(f"Missing file: {p}")
        if p.suffix.lower() not in SUPPORTED_EXTS:
            raise ValueError(f"Unsupported image extension '{p.suffix}' for file: {p}")
        normalized.append(p)

    # De-duplicate preserving order
    seen = set()
    deduped = []
    for p in normalized:
        if p not in seen:
            seen.add(p)
            deduped.append(p)

    if len(deduped) < 2:
        raise ValueError("Need at least 2 images to create transitions.")

    return deduped


def build_zoompan_filter(zoom_style: str, fps: int, still_plus_trans: float) -> str:
    """
    Returns a zoompan filter that yields a stream at 'fps' lasting 'still_plus_trans' seconds.
    This is applied per-image before scaling and xfade.

    Notes:
    - zoompan works by generating frames; we control duration via d=...
    - For professional workflows, you may want more sophisticated easing curves.
    """
    total_frames = max(1, int(round(still_plus_trans * fps)))

    # Mild zoom factors; adjust to taste.
    # z is the zoom factor. We clamp to avoid runaway.
    if zoom_style == "in":
        z_expr = "min(zoom+0.0015,1.10)"
    elif zoom_style == "out":
        # Start slightly zoomed, then zoom out towards 1.0
        # Use if(lte(on,1),...) to initialize zoom.
        z_expr = "if(lte(on,1),1.10,max(zoom-0.0015,1.00))"
    elif zoom_style == "inout":
        # Zoom in first half, zoom out second half (simple piecewise based on frame count).
        # on is output frame index starting at 0/1 depending on ffmpeg build; keep it robust.
        z_expr = (
            f"if(lte(on,{total_frames//2}),"
            f"min(zoom+0.0015,1.10),"
            f"max(zoom-0.0015,1.00))"
        )
    else:
        raise ValueError(f"Unknown zoom style: {zoom_style}")

    # Centered pan so zoom stays centered
    x_expr = "iw/2-(iw/zoom/2)"
    y_expr = "ih/2-(ih/zoom/2)"

    return f"zoompan=z='{z_expr}':x='{x_expr}':y='{y_expr}':d={total_frames}:fps={fps}"


def build_filter_complex(
    num_inputs: int,
    out_w: int,
    out_h: int,
    fps: int,
    timeline: TimelineConfig,
) -> Tuple[str, str]:
    """
    Constructs a filter_complex that:
    - normalizes each image stream (optional zoompan), then scale+fps+format
    - chains xfade transitions across all images
    Returns (filter_complex, final_video_label)
    """
    if timeline.transition_name not in XFADE_TRANSITIONS:
        raise ValueError(
            f"Unknown transition '{timeline.transition_name}'. "
            f"Available: {', '.join(sorted(XFADE_TRANSITIONS.keys()))}"
        )

    xfade_name = XFADE_TRANSITIONS[timeline.transition_name]
    total_duration = num_inputs * timeline.still_duration
    still_plus_trans = timeline.still_duration

    parts: List[str] = []

    # Prepare each input stream: optionally zoompan -> scale -> fps -> format -> setsar
    for i in range(num_inputs):
        in_label = f"[{i}:v]"

        chain = []

        # If zoom is enabled, it should happen before scaling to keep math simple.
        if timeline.zoom_style is not None:
            chain.append(build_zoompan_filter(timeline.zoom_style, fps, total_duration))

        # Ensure a consistent output geometry and timing.
        chain.append(f"scale={out_w}:{out_h}:force_original_aspect_ratio=decrease")
        chain.append(f"pad={out_w}:{out_h}:(ow-iw)/2:(oh-ih)/2:color=black")
        chain.append(f"fps={fps}")
        chain.append("format=rgba")
        chain.append("setsar=1")

        out_label = f"[v{i}]"
        parts.append(f"{in_label}{','.join(chain)}{out_label}")

    # Chain xfade: each transition overlaps by transition_duration.
    # Offsets are computed in the *output timeline*:
    # offset_k = k * still_duration + (k-1) * transition_duration
    # This makes each image fully visible for still_duration, then overlap transition.
    current = "[v0]"
    for k in range(1, num_inputs):
        offset = (k * timeline.still_duration) - timeline.transition_duration
        next_label = f"[v{k}]"
        out_label = f"[x{k}]"
        parts.append(
            f"{current}{next_label}"
            f"xfade=transition={xfade_name}:duration={timeline.transition_duration}:offset={offset}"
            f"{out_label}"
        )
        current = out_label

    return ";".join(parts), current


def run_ffmpeg(cmd: List[str]) -> None:
    logging.debug("FFmpeg command:\n%s", " \\\n  ".join(shlex.quote(c) for c in cmd))

    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    if proc.returncode != 0:
        # Include tail of stderr for readability
        err = proc.stderr.strip()
        tail = "\n".join(err.splitlines()[-60:])
        raise FFmpegError(f"FFmpeg failed (exit {proc.returncode}). Stderr tail:\n{tail}")

    if proc.stderr:
        # FFmpeg writes progress to stderr; keep it at debug level unless you want verbose.
        logging.debug("FFmpeg stderr:\n%s", proc.stderr.strip())


def build_ffmpeg_command(
    ffmpeg_bin: str,
    images: List[Path],
    output_path: Path,
    out_cfg: OutputConfig,
    timeline: TimelineConfig,
) -> List[str]:
    # We loop each image long enough for the *entire* filter graph timeline.
    # In practice, chained xfade graphs can truncate if later stages don't have
    # frames available from their inputs.
    total_duration = len(images) * timeline.still_duration

    filter_complex, final_label = build_filter_complex(
        num_inputs=len(images),
        out_w=out_cfg.width,
        out_h=out_cfg.height,
        fps=out_cfg.fps,
        timeline=timeline,
    )

    cmd: List[str] = [
        ffmpeg_bin,
        "-y",
        "-hide_banner",
        "-loglevel", "warning",
    ]

    # Inputs: loop still images
    for img in images:
        cmd += [
            "-loop", "1",
            "-t", f"{total_duration:.3f}",
            "-i", str(img),
        ]

    cmd += [
        "-filter_complex", filter_complex,
        "-map", final_label,
        "-r", str(out_cfg.fps),
        "-c:v", out_cfg.vcodec,
        "-crf", str(out_cfg.crf),
        "-preset", out_cfg.preset,
        "-pix_fmt", out_cfg.pix_fmt,
        str(output_path),
    ]

    return cmd


def parse_resolution(res: str) -> Tuple[int, int]:
    if "x" not in res:
        raise ValueError("Resolution must be like 1920x1080")
    w_s, h_s = res.lower().split("x", 1)
    w, h = int(w_s), int(h_s)
    if w <= 0 or h <= 0:
        raise ValueError("Resolution must be positive")
    return w, h


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a transitions video from images using FFmpeg xfade/zoompan."
    )
    parser.add_argument("--input-folder", type=Path, default=None)
    parser.add_argument("--input-files", type=Path, nargs="*", default=[])
    parser.add_argument("--recursive", action="store_true", help="Scan input folder recursively")

    parser.add_argument("--transition", default="crossfade", choices=sorted(XFADE_TRANSITIONS.keys()))
    parser.add_argument("--still", type=float, default=2.0, help="Seconds each image is fully visible")
    parser.add_argument("--duration", type=float, default=0.75, help="Transition duration in seconds")

    parser.add_argument("--zoom", default="none", choices=["none", "in", "out", "inout"])

    parser.add_argument("--resolution", default="1920x1080")
    parser.add_argument("--fps", type=int, default=30)

    parser.add_argument("--vcodec", default="libx264")
    parser.add_argument("--crf", type=int, default=18)
    parser.add_argument("--preset", default="medium")
    parser.add_argument("--pix-fmt", default="yuv420p")

    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--ffmpeg-bin", default="ffmpeg")

    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])

    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    try:
        ensure_ffmpeg_available(args.ffmpeg_bin)

        width, height = parse_resolution(args.resolution)
        out_cfg = OutputConfig(
            width=width,
            height=height,
            fps=args.fps,
            vcodec=args.vcodec,
            crf=args.crf,
            preset=args.preset,
            pix_fmt=args.pix_fmt,
        )

        zoom_style = None if args.zoom == "none" else args.zoom
        timeline = TimelineConfig(
            still_duration=float(args.still),
            transition_duration=float(args.duration),
            transition_name=args.transition,
            zoom_style=zoom_style,
        )

        if timeline.still_duration <= 0:
            raise ValueError("--still must be > 0")
        if timeline.transition_duration <= 0:
            raise ValueError("--duration must be > 0")
        if timeline.transition_duration > timeline.still_duration:
            raise ValueError("--duration must be <= --still (transition must fit within each image time)")

        images = collect_images(args.input_folder, args.input_files, args.recursive)
        logging.info("Using %d images", len(images))
        logging.debug("Image order:\n%s", "\n".join(str(p) for p in images))

        output_path = args.output.expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)

        cmd = build_ffmpeg_command(
            ffmpeg_bin=args.ffmpeg_bin,
            images=images,
            output_path=output_path,
            out_cfg=out_cfg,
            timeline=timeline,
        )

        logging.info("Rendering: %s", output_path)
        run_ffmpeg(cmd)
        logging.info("Done.")
        return 0

    except (ValueError, FFmpegError) as e:
        logging.error(str(e))
        return 2
    except Exception:
        logging.exception("Unexpected failure")
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
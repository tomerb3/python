import argparse
import logging
import os
import pathlib
import shlex
import subprocess
from dataclasses import dataclass
from typing import List, Optional, Sequence

# ---------------- Logging setup ---------------- #

def setup_logger(verbosity: int = 1) -> logging.Logger:
    logger = logging.getLogger("img2video")
    if logger.handlers:
        return logger
    level = logging.DEBUG if verbosity > 1 else logging.INFO
    logger.setLevel(level)
    ch = logging.StreamHandler()
    ch.setLevel(level)
    fmt = logging.Formatter("[%(levelname)s] %(message)s")
    ch.setFormatter(fmt)
    logger.addHandler(ch)
    return logger


# ---------------- Data models ---------------- #

SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".webp"}


@dataclass
class TransitionSpec:
    """Spec for a single transition between clip i and i+1."""
    transition: str = "fade"    # any xfade transition name
    duration: float = 0.75      # seconds


@dataclass
class RenderSettings:
    width: int = 1920
    height: int = 1080
    fps: int = 30
    still_duration: float = 3.0     # visible time per image (seconds, including overlap)
    codec: str = "libx264"
    crf: int = 18
    preset: str = "medium"
    pix_fmt: str = "yuv420p"


# ---------------- Utility functions ---------------- #

def discover_images(input_path: str) -> List[str]:
    """Return sorted list of image paths given a folder or a single file/list text."""
    p = pathlib.Path(input_path)
    if p.is_dir():
        files = sorted(
            str(f)
            for f in p.iterdir()
            if f.suffix.lower() in SUPPORTED_EXTS and f.is_file()
        )
    else:
        if p.suffix.lower() in SUPPORTED_EXTS:
            files = [str(p)]
        else:
            raise ValueError(f"Unsupported input: {input_path!r}")
    if not files:
        raise ValueError(f"No supported images found in {input_path!r}")
    return files


def validate_transitions(num_images: int, transitions: Optional[Sequence[TransitionSpec]]) -> List[TransitionSpec]:
    """Ensure there is a TransitionSpec for each junction; repeat or default if needed."""
    num_needed = max(0, num_images - 1)
    if num_needed == 0:
        return []

    if not transitions:
        return [TransitionSpec()] * num_needed

    # If one spec provided, reuse; otherwise truncate/pad
    if len(transitions) == 1:
        return [transitions[0]] * num_needed

    if len(transitions) < num_needed:
        last = transitions[-1]
        transitions = list(transitions) + [last] * (num_needed - len(transitions))
    else:
        transitions = list(transitions[:num_needed])
    return transitions


# ---------------- FFmpeg command builder ---------------- #

def build_ffmpeg_command(
    images: Sequence[str],
    transitions: Sequence[TransitionSpec],
    render: RenderSettings,
    output_path: str,
    log: logging.Logger,
) -> List[str]:
    """
    Build a single ffmpeg command that:
    - creates still clips from each image
    - chains them via xfade transitions
    """
    n = len(images)
    if n == 0:
        raise ValueError("No images to process")

    if n == 1:
        # Single still -> no transition, just loop it for still_duration
        log.info("Only one image provided; generating still video without transitions.")
    else:
        if len(transitions) != n - 1:
            raise ValueError("Number of transitions must be num_images - 1")

    # Inputs
    cmd = ["ffmpeg", "-y"]
    for img in images:
        cmd += ["-loop", "1", "-i", img]

    # Filter graph
    filters = []
    duration = render.still_duration
    w, h, fps = render.width, render.height, render.fps

    # Prepare scaled/padded streams for each input: [s0], [s1], ...
    for i in range(n):
        # scale to fit, pad to requested resolution, then set fps and duration
        # t is the total time for the still; transitions will reuse overlapping frames
        filters.append(
            f"[{i}:v]scale={w}:{h}:force_original_aspect_ratio=decrease,"
            f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,"
            f"fps={fps},trim=duration={duration},setpts=PTS-STARTPTS[s{i}]"
        )

    # Chain xfade filters: [s0][s1] -> [xf0]; [xf0][s2] -> [xf1]; ...
    # Each xfade offset starts at (duration - t_dur) * step, but a simple scheme is:
    # offset = duration - t_dur, so transition starts t_dur seconds before end of first clip.[web:1][web:18]
    prev_label = f"s0"
    offset_base = duration
    for idx in range(len(transitions)):
        t = transitions[idx]
        in1 = f"[{prev_label}]"
        in2 = f"[s{idx+1}]"
        out = f"[xf{idx}]"
        offset = max(0.0, offset_base - t.duration)
        filters.append(
            f"{in1}{in2}xfade=transition={t.transition}:duration={t.duration}:offset={offset}{out}"
        )
        prev_label = f"xf{idx}"

    final_label = f"[s0]" if n == 1 else f"[{prev_label}]"

    filter_complex = ";".join(filters)

    cmd += [
        "-filter_complex",
        filter_complex,
        "-map",
        final_label,
        "-vsync",
        "2",
        "-c:v",
        render.codec,
        "-crf",
        str(render.crf),
        "-preset",
        render.preset,
        "-pix_fmt",
        render.pix_fmt,
        output_path,
    ]

    log.debug("FFmpeg command:\n%s", " ".join(shlex.quote(c) for c in cmd))
    return cmd


# ---------------- Execution wrapper ---------------- #

def run_ffmpeg(cmd: List[str], log: logging.Logger) -> None:
    """Run ffmpeg command, capturing stderr for debugging on failure.[web:7][web:16]"""
    try:
        completed = subprocess.run(
            cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if completed.stderr:
            # FFmpeg writes progress and info to stderr even on success.[web:7]
            log.debug(completed.stderr)
    except subprocess.CalledProcessError as e:
        log.error("FFmpeg failed with exit code %s", e.returncode)
        log.error("Command: %s", " ".join(shlex.quote(c) for c in e.cmd))
        if e.stderr:
            log.error("FFmpeg stderr:\n%s", e.stderr)
        raise RuntimeError("FFmpeg execution failed") from e


# ---------------- Public API ---------------- #

def images_to_video(
    input_path: str,
    output_path: str,
    render: Optional[RenderSettings] = None,
    transitions: Optional[Sequence[TransitionSpec]] = None,
    verbosity: int = 1,
) -> None:
    """
    High-level API for programmatic use.
    - input_path: folder with images or single image
    - output_path: resulting video path
    """
    log = setup_logger(verbosity)
    render = render or RenderSettings()

    # Input handling
    images = discover_images(input_path)
    log.info("Found %d image(s).", len(images))
    for img in images:
        log.debug("  %s", img)

    # Transition configuration
    transitions = validate_transitions(len(images), transitions)

    # Command assembly
    cmd = build_ffmpeg_command(images, transitions, render, output_path, log)

    # Run FFmpeg
    run_ffmpeg(cmd, log)
    log.info("Video written to %s", output_path)


# ---------------- CLI interface ---------------- #

def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a video with FFmpeg xfade transitions from a sequence of images."
    )
    parser.add_argument("input", help="Input folder containing images or a single image file")
    parser.add_argument("output", help="Output video file path (e.g., out.mp4)")
    parser.add_argument("--width", type=int, default=1920, help="Output width")
    parser.add_argument("--height", type=int, default=1080, help="Output height")
    parser.add_argument("--fps", type=int, default=30, help="Frames per second")
    parser.add_argument(
        "--still-duration",
        type=float,
        default=3.0,
        help="Duration in seconds for each image (including transition overlap)",
    )
    parser.add_argument("--codec", default="libx264", help="Video codec")
    parser.add_argument("--crf", type=int, default=18, help="CRF value for quality")
    parser.add_argument("--preset", default="medium", help="FFmpeg preset")
    parser.add_argument("--pix-fmt", default="yuv420p", help="Pixel format")
    parser.add_argument(
        "--transition",
        action="append",
        help=(
            "Transition spec between slides, e.g. 'fade:0.7', 'wipeleft:1.0'. "
            "Repeat to define sequence; last one is reused as needed."
        ),
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=1, help="Increase verbosity (-v, -vv)"
    )
    return parser.parse_args(argv)


def parse_transition_arg(arg: str) -> TransitionSpec:
    """
    Parse 'name:duration' into a TransitionSpec.
    Example: 'wipeleft:1.0'
    """
    parts = arg.split(":")
    if len(parts) == 1:
        return TransitionSpec(transition=parts[0])
    name, dur = parts[0], float(parts[1])
    return TransitionSpec(transition=name, duration=dur)


def main(argv: Optional[Sequence[str]] = None) -> None:
    args = parse_args(argv)
    transitions = None
    if args.transition:
        transitions = [parse_transition_arg(t) for t in args.transition]

    render = RenderSettings(
        width=args.width,
        height=args.height,
        fps=args.fps,
        still_duration=args.still_duration,
        codec=args.codec,
        crf=args.crf,
        preset=args.preset,
        pix_fmt=args.pix_fmt,
    )

    images_to_video(
        input_path=args.input,
        output_path=args.output,
        render=render,
        transitions=transitions,
        verbosity=args.verbose,
    )


if __name__ == "__main__":
    main()

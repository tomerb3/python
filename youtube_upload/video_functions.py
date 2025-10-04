#!/usr/bin/env python3

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Optional

TMP_ROOT = Path("/app/data/tmp")
TMP_ROOT.mkdir(parents=True, exist_ok=True)


def run(cmd: list[str]) -> None:
    print("$", " ".join(shlex.quote(c) for c in cmd))
    proc = subprocess.run(cmd)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {proc.returncode}: {' '.join(cmd)}")


def ensure_ffmpeg() -> None:
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        raise RuntimeError("ffmpeg not found. Please install ffmpeg and ensure it's on PATH.")


def ensure_node() -> None:
    try:
        subprocess.run(["node", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        raise RuntimeError("node not found. Required for Lottie overlay. Install Node.js and ensure 'node' is on PATH.")


def action_last_frame(input_video: Path, output_video: Path, seconds: float, fps: int = 30) -> None:
    """Extract the last frame of input_video to an image and create a still video of X seconds."""
    ensure_ffmpeg()
    workdir = TMP_ROOT / f"vf_lastframe_{output_video.stem}"
    workdir.mkdir(parents=True, exist_ok=True)
    last_png = workdir / "last_frame.png"

    # Grab the last frame as an image
    run([
        "ffmpeg", "-hide_banner", "-y",
        "-sseof", "-1",
        "-i", input_video.as_posix(),
        "-frames:v", "1",
        last_png.as_posix(),
    ])

    # Create a still video of the requested duration
    run([
        "ffmpeg", "-hide_banner", "-y",
        "-loop", "1",
        "-t", str(seconds),
        "-i", last_png.as_posix(),
        "-r", str(fps),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        output_video.as_posix(),
    ])


def action_add_sound(input_video: Path, output_video: Path, sound: Path, start: float, duration: Optional[float] = None, volume: Optional[float] = None) -> None:
    """Mix a short sound effect into the video's audio starting at `start` seconds for `duration` seconds (if provided)."""
    ensure_ffmpeg()
    # Build filter for the sound effect: delay to start time, optional trim, optional volume
    fx_chain = []
    if duration is not None:
        fx_chain.append(f"atrim=0:{duration}")
    # adelay takes milliseconds per channel
    delay_ms = max(0, int(start * 1000))
    fx_chain.append(f"adelay={delay_ms}|{delay_ms}")
    if volume is not None:
        fx_chain.append(f"volume={volume}")

    fx_filter = ",".join(fx_chain) if fx_chain else "anull"

    filter_complex = (
        f"[1:a]{fx_filter}[fx];"  # processed effect
        f"[0:a][fx]amix=inputs=2:duration=first:dropout_transition=0[aout]"
    )

    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_video.as_posix(),
        "-i", sound.as_posix(),
        "-filter_complex", filter_complex,
        "-map", "0:v:0",
        "-map", "[aout]",
        "-c:v", "copy",
        "-c:a", "aac",
        "-shortest",
        output_video.as_posix(),
    ]
    run(cmd)


def action_mouse_move(
    input_video: Path,
    output_video: Path,
    cursor_png: Path,
    x: str,
    y: str,
    start: float,
    duration: float,
    scale_cursor: float = 1.0,
) -> None:
    """Overlay a mouse cursor PNG at (x,y) starting at `start` for `duration` seconds.
    The cursor can be scaled by `scale_cursor`.
    """
    ensure_ffmpeg()

    end = start + duration
    # Build filter_complex: optionally scale cursor, then overlay with time gating
    if scale_cursor != 1.0:
        filter_complex = (
            f"[1:v]scale=iw*{scale_cursor}:ih*{scale_cursor}[cur];"
            f"[0:v][cur]overlay=x={x}:y={y}:enable='between(t,{start},{end})'"
        )
    else:
        filter_complex = (
            f"[0:v][1:v]overlay=x={x}:y={y}:enable='between(t,{start},{end})'"
        )

    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_video.as_posix(),
        "-i", cursor_png.as_posix(),
        "-filter_complex", filter_complex,
        "-map", "0:a?",  # copy audio if present
        "-map", "[vout]?",  # not used; overlay becomes primary video output
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        output_video.as_posix(),
    ]
    # Because we didn't name the output pad, simplify mapping by omitting explicit maps and let ffmpeg choose
    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_video.as_posix(),
        "-i", cursor_png.as_posix(),
        "-filter_complex", filter_complex,
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        output_video.as_posix(),
    ]
    run(cmd)


def action_animate_text_with_lottie(
    input_video: Path,
    output_video: Path,
    lottie_json: Path,
    x: int,
    y: int,
    start: float,
    duration: float,
    scale: float = 1.0,
    fps: int = 30,
    overlay_w: int = 512,
    overlay_h: int = 512,
) -> None:
    """Overlay a Lottie animation over the video by invoking the node-based renderer/overlay script.
    Requires effects/1/overlay.js (see README) and Node.js.
    """
    ensure_node()
    ensure_ffmpeg()  # overlay.js ends with ffmpeg overlay

    # Default path to overlay.js based on repo layout
    overlay_js = Path(__file__).parent.parent / "effects/1/overlay.js"
    if not overlay_js.exists():
        raise FileNotFoundError(f"overlay.js not found at {overlay_js}. Please ensure the effects package is present.")

    cmd = [
        "node", overlay_js.as_posix(),
        "--video", input_video.as_posix(),
        "--lottie", lottie_json.as_posix(),
        "--x", str(x), "--y", str(y),
        "--scale", str(scale),
        "--start", str(start), "--duration", str(duration),
        "--fps", str(fps),
        "--overlayWidth", str(overlay_w), "--overlayHeight", str(overlay_h),
        "--out", output_video.as_posix(),
    ]
    run(cmd)


def action_running_code_drawtext(
    input_video: Path,
    output_video: Path,
    text: str,
    x: str,
    y: str,
    start: float,
    duration: float,
    fontsize: int = 36,
    fontcolor: str = "white",
    fontfile: Optional[Path] = None,
    box: bool = True,
    boxcolor: str = "black@0.5",
    shadowcolor: str = "black",
    shadowx: int = 2,
    shadowy: int = 2,
) -> None:
    """Render text on the video at (x,y) starting at `start` for `duration` seconds using ffmpeg drawtext."""
    ensure_ffmpeg()

    # drawtext positions can be expressions; accept raw strings for x/y
    draw_opts = [
        f"text={text.replace(':', '\\:').replace("'", "\\'")}",
        f"x={x}", f"y={y}",
        f"fontsize={fontsize}", f"fontcolor={fontcolor}",
        f"enable='between(t,{start},{start + duration})'",
        f"shadowcolor={shadowcolor}", f"shadowx={shadowx}", f"shadowy={shadowy}",
    ]
    if box:
        draw_opts.append(f"box=1")
        draw_opts.append(f"boxcolor={boxcolor}")
    if fontfile:
        draw_opts.append(f"fontfile={fontfile.as_posix()}")

    vf = f"drawtext={':'.join(draw_opts)}"

    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_video.as_posix(),
        "-vf", vf,
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        output_video.as_posix(),
    ]
    run(cmd)

def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Video utility actions: last_frame, add_sound, animate_text (Lottie), running_code (drawtext), mouse_move (cursor PNG overlay)")
    p.add_argument("--action", required=True, choices=["last_frame", "add_sound", "animate_text", "running_code", "mouse_move"], help="Action to perform")
    p.add_argument("--input_video", required=True, help="Path of input video file")
    p.add_argument("--output_video", required=True, help="Path of output video file")

    # Common optional params
    p.add_argument("--fps", type=int, default=30, help="FPS for generated content where applicable")

    # last_frame
    p.add_argument("--seconds", type=float, help="Duration in seconds for the still video (last_frame)")

    # add_sound
    p.add_argument("--start", type=float, help="Start time (seconds) for sound/text overlays")
    p.add_argument("--sound_duration", type=float, help="Duration (seconds) of the sound effect (add_sound)")
    p.add_argument("--volume", type=float, help="Volume multiplier for the sound effect (e.g., 0.6)")

    # animate_text (Lottie)
    p.add_argument("--lottie", help="Path to Lottie JSON to overlay (required for animate_text)")
    p.add_argument("--x", help="X position (can be number or ffmpeg expr for drawtext; integer for Lottie)")
    p.add_argument("--y", help="Y position (can be number or ffmpeg expr for drawtext; integer for Lottie)")
    p.add_argument("--duration", type=float, help="Duration (seconds) for overlay/text display")
    p.add_argument("--scale", type=float, default=1.0, help="Scale for Lottie overlay")
    p.add_argument("--overlay_width", type=int, default=512, help="Lottie overlay surface width")
    p.add_argument("--overlay_height", type=int, default=512, help="Lottie overlay surface height")

    # running_code (drawtext)
    p.add_argument("--text", help="Text content for animate_text/running_code")
    p.add_argument("--fontsize", type=int, default=36, help="Font size for drawtext (running_code)")
    p.add_argument("--fontcolor", default="white", help="Font color for drawtext (running_code)")
    p.add_argument("--fontfile", help="Path to a TTF/OTF font file (running_code)")

    # mouse_move (cursor PNG overlay)
    p.add_argument("--cursor_png", help="Path to cursor PNG image (required for mouse_move)")
    p.add_argument("--scale_cursor", type=float, default=1.0, help="Scale factor for cursor PNG (mouse_move)")

    return p.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)

    input_video = Path(args.input_video).resolve()
    output_video = Path(args.output_video).resolve()

    if args.action == "last_frame":
        if args.seconds is None:
            print("--seconds is required for last_frame", file=sys.stderr)
            return 2
        action_last_frame(input_video, output_video, seconds=args.seconds, fps=args.fps)
        return 0

    if args.action == "mouse_move":
        if not args.cursor_png:
            print("--cursor_png is required for mouse_move", file=sys.stderr)
            return 2
        if args.x is None or args.y is None or args.start is None or args.duration is None:
            print("--x, --y, --start, --duration are required for mouse_move", file=sys.stderr)
            return 2
        action_mouse_move(
            input_video,
            output_video,
            cursor_png=Path(args.cursor_png).resolve(),
            x=args.x,
            y=args.y,
            start=float(args.start),
            duration=float(args.duration),
            scale_cursor=float(args.scale_cursor),
        )
        return 0

    if args.action == "add_sound":
        if not args.sound:
            print("--sound is required for add_sound", file=sys.stderr)
            return 2
        if args.start is None:
            print("--start is required for add_sound", file=sys.stderr)
            return 2
        sound_path = Path(args.sound).resolve()
        action_add_sound(
            input_video,
            output_video,
            sound=sound_path,
            start=float(args.start),
            duration=float(args.sound_duration) if args.sound_duration is not None else None,
            volume=float(args.volume) if args.volume is not None else None,
        )
        return 0

    if args.action == "animate_text":
        # For Lottie text animations, user must provide a Lottie JSON that encodes the desired text animation.
        # We overlay that animation at (x,y) for the specified window.
        if not args.lottie:
            print("--lottie is required for animate_text (provide a Lottie JSON that animates your text)", file=sys.stderr)
            return 2
        if args.x is None or args.y is None or args.start is None or args.duration is None:
            print("--x, --y, --start, --duration are required for animate_text", file=sys.stderr)
            return 2
        lottie_path = Path(args.lottie).resolve()
        action_animate_text_with_lottie(
            input_video,
            output_video,
            lottie_json=lottie_path,
            x=int(args.x),
            y=int(args.y),
            start=float(args.start),
            duration=float(args.duration),
            scale=float(args.scale),
            fps=int(args.fps),
            overlay_w=int(args.overlay_width),
            overlay_h=int(args.overlay_height),
        )
        return 0

    if args.action == "running_code":
        if args.text is None:
            print("--text is required for running_code", file=sys.stderr)
            return 2
        if args.x is None or args.y is None or args.start is None or args.duration is None:
            print("--x, --y, --start, --duration are required for running_code", file=sys.stderr)
            return 2
        action_running_code_drawtext(
            input_video,
            output_video,
            text=args.text,
            x=args.x,
            y=args.y,
            start=float(args.start),
            duration=float(args.duration),
            fontsize=int(args.fontsize),
            fontcolor=args.fontcolor,
            fontfile=Path(args.fontfile).resolve() if args.fontfile else None,
        )
        return 0

    print(f"Unknown action: {args.action}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())

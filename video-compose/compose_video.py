#!/usr/bin/env python3

import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional


def run(cmd: List[str]) -> None:
    print("$", " ".join(shlex.quote(c) for c in cmd))
    proc = subprocess.run(cmd)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {proc.returncode}: {' '.join(cmd)}")


def ensure_ffmpeg() -> None:
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        raise RuntimeError("ffmpeg not found. Please install ffmpeg and ensure it's on PATH.")


DefSection = Dict[str, Any]


def clean_str_path(p: Optional[Any]) -> Optional[str]:
    """Sanitize path-like strings coming from JSON/n8n.
    - Cast to str
    - Strip whitespace
    - Remove common invisible chars (ZWSP, BOM)
    - Strip surrounding quotes
    """
    if p is None:
        return None
    s = str(p)
    # Remove invisible characters that sometimes sneak in from forms/CSV
    s = s.replace("\u200b", "").replace("\ufeff", "")
    s = s.strip()
    # Remove accidental surrounding quotes
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        s = s[1:-1].strip()
    return s


def seconds_from_section(sec: DefSection) -> float:
    if "duration" in sec:
        return float(sec["duration"])
    if "start" in sec and "end" in sec:
        return float(sec["end"]) - float(sec["start"])
    raise ValueError("Section must include either 'duration' or both 'start' and 'end'.")


def build_section_ffmpeg_cmd(
    idx: int,
    sec: DefSection,
    out_path: Path,
    target_w: Optional[int],
    target_h: Optional[int],
    fps: Optional[int],
    vcodec: str,
    acodec: str,
    crf: int,
    preset: str,
) -> List[str]:
    duration = seconds_from_section(sec)
    if duration <= 0:
        raise ValueError(f"Section {idx}: duration must be > 0")

    video = clean_str_path(sec.get("video"))
    if not video:
        raise ValueError(f"Section {idx}: 'video' is required")
    audio = clean_str_path(sec.get("audio"))
    ass = clean_str_path(sec.get("ass"))
    filter_script = clean_str_path(sec.get("filter_script"))  # path to filter_complex_script file

    video_start = float(sec.get("video_start", 0))
    audio_start = float(sec.get("audio_start", 0))

    filters: List[str] = []
    if fps:
        filters.append(f"fps={fps}")
    if target_w and target_h:
        # Scale to fit inside target while preserving aspect, pad to exact size
        filters.append(
            f"scale=w={target_w}:h={target_h}:force_original_aspect_ratio=decrease"
        )
        filters.append(
            f"pad={target_w}:{target_h}:(ow-iw)/2:(oh-ih)/2:color=black"
        )
    if ass:
        # Escape backslashes and colons for drawtext/ass filter
        ass_path = str(Path(ass).resolve()).replace("\\", "\\\\").replace(":", r"\:")
        filters.append(f"ass='{ass_path}'")

    extra_filters = sec.get("extra_filters")
    if extra_filters:
        filters.append(str(extra_filters))

    vf = ",".join(filters) if filters else None

    cmd: List[str] = [
        "ffmpeg",
        "-hide_banner",
        "-y",
    ]

    # Video input with optional seek
    if video_start > 0:
        cmd += ["-ss", f"{video_start}"]
    cmd += ["-i", video]

    # Audio input with optional seek (if provided), otherwise use video audio
    if audio:
        if audio_start > 0:
            cmd += ["-ss", f"{audio_start}"]
        cmd += ["-i", audio]

    # Duration
    cmd += ["-t", f"{duration}"]

    # Map streams
    # If using a filter_complex_script, do not map 0:v:0 explicitly; let ffmpeg select filtered video output.
    if not filter_script:
        cmd += ["-map", "0:v:0"]
    if audio:
        cmd += ["-map", "1:a:0?", "-shortest"]
    else:
        cmd += ["-map", "0:a:0?", "-shortest"]

    # Filters
    if filter_script:
        # Use complex filter script file for this section (e.g., multiple drawtext steps)
        cmd += ["-filter_complex_script", str(Path(filter_script).resolve())]
    elif vf:
        cmd += ["-vf", vf]

    # Encoding params for uniformity across segments
    cmd += [
        "-c:v", vcodec,
        "-preset", preset,
        "-crf", str(crf),
        "-pix_fmt", "yuv420p",
        "-c:a", acodec,
        "-b:a", "192k",
        out_path.as_posix(),
    ]

    return cmd


def compose_from_dict(cfg: Dict[str, Any], *, phase: Optional[str] = None, workdir: Optional[Path] = None) -> Path:
    ensure_ffmpeg()

    # Support shorthand JSON: {"video": "file.mp4", "seconds": 10, ...}
    if "video" in cfg and "seconds" in cfg and not cfg.get("sections"):
        sec: DefSection = {
            "duration": float(cfg["seconds"]),
            "video": cfg["video"],
        }
        if cfg.get("audio"):
            sec["audio"] = cfg["audio"]
        if cfg.get("ass"):
            sec["ass"] = cfg["ass"]
        if cfg.get("video_start") is not None:
            sec["video_start"] = cfg["video_start"]
        if cfg.get("audio_start") is not None:
            sec["audio_start"] = cfg["audio_start"]
        cfg = {**cfg, "sections": [sec]}

    output = Path(cfg.get("output", "master.mp4")).resolve()
    sections: List[DefSection] = cfg.get("sections", [])
    if not sections:
        raise ValueError("Config must include 'sections'.")
    if len(sections) > 8:
        raise ValueError("Maximum of 8 sections supported.")

    width = cfg.get("width")
    height = cfg.get("height")
    fps = cfg.get("fps")
    vcodec = cfg.get("video_codec", "libx264")
    acodec = cfg.get("audio_codec", "aac")
    crf = int(cfg.get("crf", 23))
    preset = cfg.get("preset", "medium")

    # Use a stable temp root under /app/data/tmp for all intermediate compose files
    tmp_root = Path("/app/data/tmp")
    tmp_root.mkdir(parents=True, exist_ok=True)
    # If running in phased mode, default to a deterministic workdir per output name unless a workdir is provided
    if phase:
        if workdir is not None:
            tmpdir = Path(workdir)
        else:
            tmpdir = tmp_root / f"compose_{output.stem}"
        tmpdir.mkdir(parents=True, exist_ok=True)
    else:
        # Non-phased mode: create a unique temp directory for this run
        tmpdir = Path(tempfile.mkdtemp(prefix="compose_ffmpeg_", dir=str(tmp_root)))
    print(f"Working directory: {tmpdir}")

    # Phase 1: render segments and write concat list
    if phase is None or phase == "phase1":
        segment_paths: List[Path] = []
        for i, sec in enumerate(sections):
            seg_out = tmpdir / f"segment_{i:02d}.mp4"
            cmd = build_section_ffmpeg_cmd(
                i,
                sec,
                seg_out,
                width,
                height,
                fps,
                vcodec,
                acodec,
                crf,
                preset,
            )
            run(cmd)
            segment_paths.append(seg_out)

        # Create/overwrite concat list file in workdir
        list_path = tmpdir / "concat_list.txt"
        with list_path.open("w") as f:
            for p in segment_paths:
                f.write(f"file '{p.as_posix()}'\n")
        print(f"Phase1 complete. Concat list written to {list_path}")

    # Phase 2: concatenate segments
    if phase is None or phase == "phase2":
        list_path = tmpdir / "concat_list.txt"
        if not list_path.exists():
            raise FileNotFoundError(f"Concat list not found: {list_path}. Run with --phase phase1 first or specify the correct --workdir.")

        out_dir = output.parent
        out_dir.mkdir(parents=True, exist_ok=True)

        concat_cmd = [
            "ffmpeg",
            "-hide_banner",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", list_path.as_posix(),
            "-c", "copy",
            output.as_posix(),
        ]
        run(concat_cmd)
        print(f"Wrote {output}")

    return output


def compose(config_path: Path, *, phase: Optional[str] = None, workdir: Optional[Path] = None) -> Path:
    cfg = json.loads(Path(config_path).read_text())
    # Allow n8n-style outputs where the root is a list of config objects.
    # If a list is provided, process each config sequentially and return the last output path.
    if isinstance(cfg, list):
        if not cfg:
            raise ValueError("Config list is empty.")
        outputs: List[Path] = []
        for i, item in enumerate(cfg):
            if not isinstance(item, dict):
                raise ValueError(f"Config list element {i} must be an object/dict.")
            # Unwrap n8n items shape: { "json": { ... actual config ... } }
            if "json" in item and isinstance(item["json"], dict):
                item_cfg = item["json"]
            else:
                item_cfg = item
            outputs.append(compose_from_dict(item_cfg, phase=phase, workdir=workdir))
        return outputs[-1]
    return compose_from_dict(cfg, phase=phase, workdir=workdir)


def example_config() -> Dict[str, Any]:
    return {
        "output": "master.mp4",
        "width": 1920,
        "height": 1080,
        "fps": 30,
        "video_codec": "libx264",
        "audio_codec": "aac",
        "crf": 23,
        "preset": "medium",
        "sections": [
            {
                "duration": 6,
                "video": "input1.mp4",
                "audio": "input1.mp3"
            },
            {
                "duration": 19,
                "video": "input1.mp4",
                "ass": "effects.ass"
            },
            {
                "duration": 35,
                "video": "input2.mp4",
                "audio": "input3.mp3"
            }
        ]
    }


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Compose up to 8 video sections into one master.mp4 using ffmpeg.")
    p.add_argument("--config", required=False, help="Path to JSON config file describing sections.")
    p.add_argument("--print-example", action="store_true", help="Print an example config JSON and exit.")
    p.add_argument("--phase", choices=["phase1", "phase2"], help="Run only a specific phase: phase1=create segments, phase2=concat segments. Omit to run both.")
    p.add_argument("--workdir", help="Working directory to place/find intermediate segment files and concat_list.txt. Defaults to /app/data/tmp/compose_<outputname> when --phase is set.")
    # Simple mode: one MP4 and a number of seconds (optional audio/ass)
    p.add_argument("--video", help="Shorthand: input video file for a single section")
    p.add_argument("--seconds", type=float, help="Shorthand: duration in seconds for the single section")
    p.add_argument("--audio", help="Shorthand: optional audio file to use instead of video's audio")
    p.add_argument("--ass", help="Shorthand: optional ASS subtitles/effects file for the single section")
    p.add_argument("--video-start", type=float, default=0.0, help="Shorthand: start offset (sec) within the video")
    p.add_argument("--audio-start", type=float, default=0.0, help="Shorthand: start offset (sec) within the audio")
    p.add_argument("--output", help="Shorthand: output file path (default master.mp4)")

    args = p.parse_args(argv)

    if args.print_example:
        print(json.dumps(example_config(), indent=2))
        return 0

    # Shorthand CLI mode
    if args.video and args.seconds:
        cfg: Dict[str, Any] = {
            "output": args.output or "master.mp4",
            "video": args.video,
            "seconds": float(args.seconds),
        }
        if args.audio:
            cfg["audio"] = args.audio
        if args.ass:
            cfg["ass"] = args.ass
        if args.video_start:
            cfg["video_start"] = float(args.video_start)
        if args.audio_start:
            cfg["audio_start"] = float(args.audio_start)
        try:
            wd = Path(args.workdir) if args.workdir else None
            compose_from_dict(cfg, phase=args.phase, workdir=wd)
            return 0
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1

    if not args.config:
        print("Provide --config, or use shorthand --video and --seconds.", file=sys.stderr)
        return 2

    try:
        wd = Path(args.workdir) if args.workdir else None
        compose(Path(args.config), phase=args.phase, workdir=wd)
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
import os
import sys
import argparse
import pathlib
import random
import math
import json
import shutil
import subprocess
from typing import List, Optional

import requests

FREESOUND_SEARCH = "https://freesound.org/apiv2/search/text/"


def run(cmd: str) -> str:
    print(cmd)
    return subprocess.check_output(cmd, shell=True).decode("utf-8", errors="ignore").strip()


def get_fps(video_path: pathlib.Path) -> float:
    # returns frames per second from ffprobe r_frame_rate
    rate = run(
        f"ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=nw=1:nk=1 {video_path.as_posix()}"
    )
    # e.g. "30000/1001" or "60/1" or "30"
    if "/" in rate:
        num, den = rate.split("/", 1)
        try:
            fps = float(num) / float(den)
        except Exception:
            fps = 30.0
    else:
        try:
            fps = float(rate)
        except Exception:
            fps = 30.0
    return max(1.0, fps)


def get_audio_duration_seconds(path: pathlib.Path) -> Optional[float]:
    try:
        val = run(
            f"ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 {path.as_posix()}"
        )
        return float(val)
    except Exception:
        return None


def has_audio(video_path: pathlib.Path) -> bool:
    try:
        cnt = run(
            f"ffprobe -v error -select_streams a -show_entries stream=index -of default=nw=1:nk=1 {video_path.as_posix()} | wc -l"
        )
        return int(cnt.strip() or "0") > 0
    except Exception:
        return False


def search_freesound(
    api_token: str,
    query: str,
    num: int = 4,
    page_size: int = 50,
    min_dur: Optional[float] = None,
    max_dur: Optional[float] = None,
    license_filter: Optional[str] = None,
    extra_filter: Optional[str] = None,
    verbose: bool = False,
) -> List[dict]:
    """Search Freesound, returning up to num entries. Tries to be robust when zero results."""
    headers = {"Authorization": f"Token {api_token}"}

    def build_filter() -> Optional[str]:
        parts = []
        # duration filter syntax: duration:[min TO max]
        if min_dur is not None or max_dur is not None:
            lo = 0 if min_dur is None else max(0, float(min_dur))
            hi = "*" if max_dur is None else max(0, float(max_dur))
            parts.append(f"duration:[{lo} TO {hi}]")
        if license_filter:
            # user passes raw filter, e.g., license:("Creative Commons 0") or license:"Attribution"
            parts.append(license_filter)
        if extra_filter:
            parts.append(extra_filter)
        return " ".join(parts) if parts else None

    attempts = []
    # Try with constructed filter first, then without filters
    attempts.append((query, build_filter()))
    attempts.append((query, None))

    # Also try a few alternate queries (synonyms)
    alt_queries = [
        query,
        "mouse click",
        "click",
        "button click",
        "tap",
        "ding",
        "ring bell",
    ]

    results: List[dict] = []
    for q in alt_queries:
        for (q_try, filt) in [(q, build_filter()), (q, None)]:
            if verbose:
                print(f"Freesound search q='{q_try}' filter='{filt}' page_size={page_size}")
            params = {
                "query": q_try,
                "page_size": max(4, min(150, page_size)),
                "fields": "id,name,previews,url,duration,license",
                "sort": "score",
            }
            if filt:
                params["filter"] = filt
            r = requests.get(FREESOUND_SEARCH, headers=headers, params=params, timeout=30)
            if r.status_code == 429:
                # rate limited; back off a bit and continue
                import time as _t
                _t.sleep(1.0)
                continue
            if r.status_code != 200:
                if verbose:
                    print(f"Freesound API error {r.status_code}: {r.text}")
                continue
            data = r.json()
            batch = data.get("results", [])
            if verbose:
                print(f"Found {len(batch)} for q='{q_try}'")
            results.extend(batch)
            if len(results) >= num:
                return results[:num]
        if results:
            break
    return results[:num]


def download_preview(entry: dict, dest: pathlib.Path) -> Optional[pathlib.Path]:
    # Prefer high-quality MP3 preview, else ogg
    previews = entry.get("previews", {})
    url = (
        previews.get("preview-hq-mp3")
        or previews.get("preview-lq-mp3")
        or previews.get("preview-hq-ogg")
        or previews.get("preview-lq-ogg")
    )
    if not url:
        return None
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(1024 * 256):
                if chunk:
                    f.write(chunk)
    return dest


def main():
    parser = argparse.ArgumentParser(description="Download 4 preview sounds from Freesound by text OR choose one locally, and mix into MP4 at a specific frame.")
    parser.add_argument("--query", required=False, default=None, help='Search text for Freesound, e.g., "ring bell sound" (omit if using --mp3-dir)')
    parser.add_argument("--input", type=pathlib.Path, required=True, help="Input MP4 video path")
    parser.add_argument("--output", type=pathlib.Path, required=True, help="Output MP4 video path")
    parser.add_argument("--frame", type=int, required=True, help="Frame number at which to start the sound (0-based)")
    parser.add_argument("--gain", type=float, default=1.0, help="Gain to apply to the inserted sound (1.0 = unchanged)")
    parser.add_argument("--bg-gain", type=float, default=1.0, help="Gain to apply to the original video audio (1.0 = unchanged)")
    parser.add_argument("--keep-temp", action="store_true", help="Keep downloaded previews")
    parser.add_argument("--offset-ms", type=int, default=0, help="Trim this many milliseconds from start of the effect (skip leading silence)")
    parser.add_argument("--min-dur", type=float, default=None, help="Minimum duration (seconds) of sound (optional)")
    parser.add_argument("--max-dur", type=float, default=None, help="Maximum duration (seconds) of sound (optional)")
    parser.add_argument("--license-filter", type=str, default=None, help="Advanced Freesound license filter, e.g., license:(\"Creative Commons 0\")")
    parser.add_argument("--extra-filter", type=str, default=None, help="Raw Freesound filter string to add (advanced)")
    parser.add_argument("--page-size", type=int, default=50, help="Search page size (default 50)")
    parser.add_argument("--verbose", action="store_true", help="Verbose search logs")
    parser.add_argument("--mp3-dir", type=pathlib.Path, default=None, help="If set, choose a random audio file from this folder (mp3/ogg) instead of downloading from Freesound.")
    parser.add_argument("--exts", type=str, default="mp3,ogg", help="Comma-separated audio extensions to include with --mp3-dir. Default: mp3,ogg")
    args = parser.parse_args()

    # Require at least one source: Freesound (--query) or local folder (--mp3-dir)
    if not args.mp3_dir and not args.query:
        print("ERROR: Provide either --query (Freesound) or --mp3-dir (local folder of sounds).", file=sys.stderr)
        sys.exit(2)

    api_token = os.getenv("FREESOUND_API_TOKEN", "").strip()
    if not args.mp3_dir:
        if not api_token:
            print("ERROR: Please export FREESOUND_API_TOKEN with your Freesound API token (or use --mp3-dir).", file=sys.stderr)
            sys.exit(1)

    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        print("ERROR: ffmpeg/ffprobe not found on PATH.", file=sys.stderr)
        sys.exit(1)

    if not args.input.exists():
        print(f"ERROR: Input not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    fps = get_fps(args.input)
    start_sec = max(0.0, float(args.frame) / fps)
    start_ms = int(round(start_sec * 1000))

    print(f"Detected FPS: {fps:.3f}; start at {start_sec:.3f}s ({start_ms} ms)")

    used_downloads = False

    # If local directory provided, pick a random file from there
    choice: pathlib.Path
    if args.mp3_dir:
        if not args.mp3_dir.exists() or not args.mp3_dir.is_dir():
            print(f"ERROR: --mp3-dir not found or not a directory: {args.mp3_dir}", file=sys.stderr)
            sys.exit(1)
        exts = [e.strip().lstrip('.').lower() for e in (args.exts.split(',') if args.exts else ['mp3','ogg'])]
        candidates: List[pathlib.Path] = []
        for ext in exts:
            candidates.extend(sorted(args.mp3_dir.glob(f"*.{ext}")))
        if not candidates:
            print(f"ERROR: No files with extensions {exts} found in {args.mp3_dir}", file=sys.stderr)
            sys.exit(1)
        choice = random.choice(candidates)
        print(f"Chosen local sound: {choice}")
    else:
        # Search and download 4 previews
        results = search_freesound(
            api_token,
            args.query,
            num=4,
            page_size=args.page_size,
            min_dur=args.min_dur,
            max_dur=args.max_dur,
            license_filter=args.license_filter,
            extra_filter=args.extra_filter,
            verbose=args.verbose,
        )
        if not results:
            print("No results from Freesound. Try a broader query (e.g., 'click', 'ding') or use --verbose to debug.", file=sys.stderr)
            sys.exit(1)

        tmpdir = args.output.parent / "_fs_previews"
        tmpdir.mkdir(parents=True, exist_ok=True)

        paths: List[pathlib.Path] = []
        for i, item in enumerate(results, start=1):
            p = tmpdir / f"preview_{i:02d}.mp3"
            got = download_preview(item, p)
            if got:
                paths.append(got)
        if not paths:
            print("Failed to download any previews.", file=sys.stderr)
            sys.exit(1)

        choice = random.choice(paths)
        used_downloads = True
    print(f"Chosen sound: {choice.name}")
    eff_dur = get_audio_duration_seconds(choice) or 0.0
    print(f"Effect duration: {eff_dur:.3f}s")

    # Build ffmpeg command
    # If video has audio: amix original and delayed sound
    # If no audio: just use delayed sound as the sole audio track
    video_has_audio = has_audio(args.input)

    # Prepare effect trim to skip initial silence if requested
    offset_ms = max(0, int(args.offset_ms))
    offset_s = offset_ms / 1000.0
    # Compute effect end time on the global timeline for ducking window (cap to effect duration if known)
    effect_play_dur = max(0.0, (eff_dur - offset_s)) if eff_dur else 2.0
    duck_start = start_sec
    duck_end = start_sec + effect_play_dur

    if video_has_audio:
        # Apply time-dependent ducking on background during the effect window
        # adelay argument in milliseconds per channel (use same for stereo: ms|ms)
        filt = (
            f"[0:a]volume='if(between(t,{duck_start:.3f},{duck_end:.3f}),{args.bg_gain*0.6:.3f},{args.bg_gain:.3f})'[bg];"
            f"[1:a]atrim=start={offset_s:.3f},asetpts=PTS-STARTPTS,volume={args.gain},adelay={start_ms}|{start_ms}[fx];"
            f"[bg][fx]amix=inputs=2:duration=longest:dropout_transition=0[aout]"
        )
        cmd = (
            f"ffmpeg -y -i {args.input.as_posix()} -i {choice.as_posix()} "
            f"-filter_complex \"{filt}\" -map 0:v:0 -map [aout] -c:v copy -c:a aac -b:a 192k "
            f"-movflags +faststart {args.output.as_posix()}"
        )
    else:
        # No original audio: just delay the effect and map it
        filt = f"[1:a]atrim=start={offset_s:.3f},asetpts=PTS-STARTPTS,volume={args.gain},adelay={start_ms}|{start_ms}[aout]"
        cmd = (
            f"ffmpeg -y -i {args.input.as_posix()} -i {choice.as_posix()} "
            f"-filter_complex \"{filt}\" -map 0:v:0 -map [aout] -c:v copy -c:a aac -b:a 192k "
            f"-movflags +faststart {args.output.as_posix()}"
        )

    try:
        run(cmd)
        print(f"Done. Wrote: {args.output}")
    except subprocess.CalledProcessError as e:
        print(f"ffmpeg failed with code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
    finally:
        if used_downloads and not args.keep_temp:
            try:
                for p in paths:
                    p.unlink(missing_ok=True)
                tmpdir.rmdir()
            except Exception:
                pass


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path
import json
from typing import List
try:
    import yaml  # optional
    HAS_YAML = True
except Exception:
    HAS_YAML = False


def read_steps(input_path: Path) -> List[str]:
    """Read steps from txt (one per line), JSON (list), or YAML (list under 'steps' or root list)."""
    s = input_path.read_text(encoding="utf-8")
    suffix = input_path.suffix.lower()
    steps: List[str] = []
    try:
        if suffix in {".json"}:
            data = json.loads(s)
            if isinstance(data, dict) and "steps" in data and isinstance(data["steps"], list):
                steps = [str(x) for x in data["steps"]]
            elif isinstance(data, list):
                steps = [str(x) for x in data]
        elif suffix in {".yml", ".yaml"} and HAS_YAML:
            data = yaml.safe_load(s)
            if isinstance(data, dict) and "steps" in data and isinstance(data["steps"], list):
                steps = [str(x) for x in data["steps"]]
            elif isinstance(data, list):
                steps = [str(x) for x in data]
        else:
            # Plain text: one step per non-empty line
            steps = [ln.strip() for ln in s.splitlines() if ln.strip()]
    except Exception as e:
        print(f"Failed to parse steps file: {e}", file=sys.stderr)
        raise
    # Preserve case and content, but strip surrounding whitespace
    return steps


def build_alpha_expr(ts: float, te: float, fi: float, fo: float) -> str:
    """Build a drawtext alpha expression with fade-in/out around [ts, te]."""
    # Ensure proper ordering: ts < te, non-negative fades
    ts = max(0.0, float(ts))
    te = max(ts, float(te))
    fi = max(0.0, float(fi))
    fo = max(0.0, float(fo))
    # alpha='if(lt(t,ts),0, if(lt(t,ts+fi),(t-ts)/fi, if(lt(t,te-fo),1, if(lt(t,te),(te-t)/fo,0))))'
    return (
        f"if(lt(t,{ts}),0,"
        f" if(lt(t,{ts}+{fi}),(t-{ts})/{fi},"
        f" if(lt(t,{te}-{fo}),1,"
        f" if(lt(t,{te}),({te}-t)/{fo},0))))"
    )


def main() -> int:
    p = argparse.ArgumentParser(description="Generate files/step_XXX.txt and files/filters.txt for ffmpeg drawtext animation.")
    p.add_argument("--input", required=True, help="Path to steps file (txt/json/yaml)")
    p.add_argument("--outdir", default="files", help="Output directory for step files and filters.txt (default: files)")
    p.add_argument("--x", type=int, default=100, help="Base X position (pixels). Will be truncated to integer.")
    p.add_argument("--y", type=int, default=200, help="Base Y position (pixels). Will be truncated to integer.")
    p.add_argument("--line_height", type=int, default=64, help="Vertical distance between lines (pixels)")
    p.add_argument("--start", type=float, default=0.5, help="Start time for the first step (seconds)")
    p.add_argument("--per_step", type=float, default=2.0, help="Total time each step is on-screen (seconds)")
    p.add_argument("--fade_in", type=float, default=0.2, help="Fade-in duration (seconds)")
    p.add_argument("--fade_out", type=float, default=0.2, help="Fade-out duration (seconds)")
    args = p.parse_args()

    input_path = Path(args.input)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    steps = read_steps(input_path)
    if not steps:
        print("No steps found in input.", file=sys.stderr)
        return 2

    # Write step text files step_001.txt, step_002.txt, ... preserving content
    step_paths: List[Path] = []
    for idx, text in enumerate(steps, start=1):
        name = f"step_{idx:03d}.txt"
        path = outdir / name
        path.write_text(text, encoding="utf-8")
        step_paths.append(path)

    # Build filters.txt: a comma-separated chain of drawtext filters.
    # Do not set font here; ffmpeg-run.sh injects RC_* and ft_load_flags.
    # We ensure integer x/y and include reload=1, expansion=none, alpha, enable.
    filters: List[str] = []
    base_x = int(args.x)
    base_y = int(args.y)
    lh = int(args.line_height)

    for i, path in enumerate(step_paths):
        ts = args.start + i * args.per_step
        te = ts + args.per_step
        alpha = build_alpha_expr(ts, te, args.fade_in, args.fade_out)
        # Escape single quotes in path (rare)
        p_esc = str(path).replace("'", "\\'")
        y_i = base_y + i * lh
        seg = (
            "drawtext="
            f"reload=1:expansion=none:"
            f"textfile='{p_esc}':"
            f"x=trunc({base_x}):y=trunc({y_i}):"
            f"alpha='{alpha}':"
            f"enable='between(t,{ts},{te})'"
        )
        filters.append(seg)

    fchain = ",".join(filters) + ","
    (outdir / "filters.txt").write_text(fchain, encoding="utf-8")

    # Print summary for shell scripts
    print(f"steps={len(steps)}")
    print(f"wrote={outdir}/filters.txt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

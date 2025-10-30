import argparse
import os
import random
from typing import List, Tuple

import cv2
import numpy as np


# ---------------------- Utils ----------------------

def parse_color_hex_list(s: str) -> List[Tuple[int, int, int]]:
    colors = []
    for item in s.split(','):
        h = item.strip().lstrip('#')
        if len(h) == 6:
            r = int(h[0:2], 16)
            g = int(h[2:4], 16)
            b = int(h[4:6], 16)
            colors.append((b, g, r))  # OpenCV BGR
    return colors


def ease(t: float, mode: str = "ease-in-out") -> float:
    t = max(0.0, min(1.0, t))
    if mode == "linear":
        return t
    # smoothstep-like ease in-out
    return t * t * (3 - 2 * t)


def clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def overlay_bgra(base_bgr: np.ndarray, overlay_bgr: np.ndarray, overlay_alpha: np.ndarray):
    # overlay_alpha expected in [0,1] float, shape (H,W)
    for c in range(3):
        base_bgr[:, :, c] = (
            overlay_alpha * overlay_bgr[:, :, c] + (1.0 - overlay_alpha) * base_bgr[:, :, c]
        ).astype(np.uint8)


# ---------------------- Motifs ----------------------

def motif_loops(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, colors: List[Tuple[int, int, int]], rng: random.Random):
    h, w = canvas_bgr.shape[:2]
    cx, cy = int(w * 0.5), int(h * 0.5)
    n = 6
    radius = int(min(w, h) * 0.2)
    for i in range(n):
        angle = (t01 * 2 * np.pi) + (i * 2 * np.pi / n)
        x = int(cx + radius * np.cos(angle))
        y = int(cy + radius * np.sin(angle))
        color = colors[i % len(colors)]
        cv2.circle(canvas_bgr, (x, y), 10, color, -1)
        cv2.circle(canvas_bgr, (x, y), 14, color, 2)
        cv2.circle(canvas_a, (x, y), 14, 1, -1)


def motif_objects(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, colors: List[Tuple[int, int, int]], rng: random.Random):
    h, w = canvas_bgr.shape[:2]
    # Slightly smaller group dimensions
    group_w, group_h = int(w * 0.32), int(h * 0.16)
    gx = int((w - group_w) * 0.3 + (w * 0.4) * np.sin(t01 * 2 * np.pi * 0.5))
    gy = int((h - group_h) * 0.3 + (h * 0.2) * np.cos(t01 * 2 * np.pi * 0.5))
    for i in range(3):
        x = gx + i * int(group_w / 3) + 10
        y = gy + 10
        rect = (x, y, int(group_w / 3) - 20, group_h - 20)
        color = colors[i % len(colors)]
        cv2.rectangle(canvas_bgr, (rect[0], rect[1]), (rect[0]+rect[2], rect[1]+rect[3]), color, 2)
        cv2.rectangle(canvas_a, (rect[0], rect[1]), (rect[0]+rect[2], rect[1]+rect[3]), 1, 2)
    # Removed bottom connecting line


def motif_list_numbers(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, colors: List[Tuple[int, int, int]], rng: random.Random):
    h, w = canvas_bgr.shape[:2]
    n = 5
    box_w = int(w * 0.12)
    box_h = int(h * 0.12)
    start_x = int(w * 0.1)
    y = int(h * 0.8)
    for i in range(n):
        appear = clamp01((t01 * 1.2) - i * 0.15)
        if appear <= 0:
            continue
        x = start_x + i * (box_w + 10)
        color = colors[i % len(colors)]
        # slide-up effect
        y_anim = y - int(30 * ease(appear))
        cv2.rectangle(canvas_bgr, (x, y_anim - box_h), (x + box_w, y_anim), color, 2)
        cv2.rectangle(canvas_a, (x, y_anim - box_h), (x + box_w, y_anim), 1, 2)
        # number text
        cv2.putText(canvas_bgr, str(i+1), (x + box_w//3, y_anim - box_h//3), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2, cv2.LINE_AA)
        cv2.putText(canvas_a, str(i+1), (x + box_w//3, y_anim - box_h//3), cv2.FONT_HERSHEY_SIMPLEX, 1, (1,1,1), 2, cv2.LINE_AA)


def motif_flow_lines(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, colors: List[Tuple[int, int, int]], rng: random.Random):
    h, w = canvas_bgr.shape[:2]
    rng_state = int(t01 * 1000)
    local_rng = random.Random(rng_state)
    for i in range(20):
        y = int(local_rng.uniform(0, h))
        x1 = int(local_rng.uniform(0, w*0.3))
        x2 = int(x1 + (w * 0.2 + w * 0.4 * ease(t01)))
        color = colors[i % len(colors)]
        cv2.line(canvas_bgr, (x1, y), (min(w-1, x2), y), color, 1)
        cv2.line(canvas_a, (x1, y), (min(w-1, x2), y), 1, 1)


def motif_code_rain(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, colors: List[Tuple[int, int, int]], rng: random.Random):
    h, w = canvas_bgr.shape[:2]
    cols = 24
    col_w = max(8, w // cols)
    speed = int(150 * (0.5 + 0.5 * t01))
    for c in range(cols):
        x = c * col_w + 2
        y = int((t01 * speed + c * 37) % (h + 40)) - 40
        color = colors[c % len(colors)]
        for k in range(0, 6):
            yy = y + k * 14
            if 0 <= yy < h:
                cv2.putText(canvas_bgr, chr(0x30A0 + (c+k) % 96), (x, yy), cv2.FONT_HERSHEY_PLAIN, 1, color, 1, cv2.LINE_AA)
                cv2.putText(canvas_a, '.', (x, yy), cv2.FONT_HERSHEY_PLAIN, 1, (1,1,1), 1, cv2.LINE_AA)


def draw_text_particles(canvas_bgr: np.ndarray, canvas_a: np.ndarray, t01: float, text: str, colors: List[Tuple[int, int, int]]):
    if not text:
        return
    tokens = text.split()
    h, w = canvas_bgr.shape[:2]
    base_y = int(h * 0.2)
    for i, token in enumerate(tokens):
        color = colors[i % len(colors)]
        x = int(w * 0.1 + i * (w * 0.2))
        y = base_y + int(20 * np.sin((t01 + i * 0.2) * 2 * np.pi))
        alpha = clamp01(0.2 + 0.8 * ease(t01))
        cv2.putText(canvas_bgr, token, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 1.1, color, 2, cv2.LINE_AA)
        cv2.putText(canvas_a, token, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 1.1, (alpha, alpha, alpha), 2, cv2.LINE_AA)


# ---------------------- Main ----------------------

def parse_args():
    p = argparse.ArgumentParser(description="Overlay animated tech shapes/text onto a base video.")
    p.add_argument("--video", required=True, help="Path to input base video (with or without audio)")
    p.add_argument("--out", required=True, help="Path to output video")
    p.add_argument("--start", type=float, required=True, help="Start time in seconds for animation window")
    p.add_argument("--duration", type=float, required=True, help="Duration in seconds of animation window")
    p.add_argument("--text", type=str, default="", help="Keywords to influence animations, e.g. 'python loops'")
    p.add_argument("--seed", type=int, default=None, help="Random seed for determinism")
    p.add_argument("--opacity", type=float, default=0.85, help="Global overlay opacity [0-1]")
    p.add_argument("--fade-in", dest="fade_in", type=float, default=0.3, help="Seconds for fade-in")
    p.add_argument("--fade-out", dest="fade_out", type=float, default=0.3, help="Seconds for fade-out")
    p.add_argument("--easing", type=str, default="ease-in-out", choices=["linear", "ease-in-out"], help="Easing function")
    p.add_argument("--palette", type=str, default="#00FFC8,#19A7F6,#9B59B6,#F39C12,#E74C3C", help="Comma hex colors")
    return p.parse_args()


def pick_motifs_from_text(text: str):
    text_l = text.lower()
    motifs = []
    if "loop" in text_l:
        motifs.append(motif_loops)
    if "object" in text_l:
        motifs.append(motif_objects)
    if "list" in text_l or "number" in text_l:
        motifs.append(motif_list_numbers)
    # Always include techy ambient motifs (excluding random lines)
    motifs.append(motif_code_rain)
    return motifs


def main():
    args = parse_args()
    if args.seed is not None:
        rng = random.Random(args.seed)
        np.random.seed(args.seed)
    else:
        rng = random.Random()

    if not os.path.isfile(args.video):
        raise FileNotFoundError(f"Video not found: {args.video}")

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        raise RuntimeError(f"Failed to open video: {args.video}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) if cap.get(cv2.CAP_PROP_FRAME_COUNT) > 0 else None

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    writer = cv2.VideoWriter(args.out, fourcc, fps, (width, height))
    if not writer.isOpened():
        raise RuntimeError(f"Failed to open output writer for: {args.out}")

    start_f = max(0, int(args.start * fps))
    end_f = start_f + max(0, int(args.duration * fps))
    if total_frames is not None:
        end_f = min(end_f, total_frames)

    colors = parse_color_hex_list(args.palette)
    if not colors:
        colors = [(200, 255, 200), (255, 200, 255), (200, 200, 255)]

    motifs = pick_motifs_from_text(args.text)

    frame_idx = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break

        if start_f <= frame_idx < end_f:
            # Local normalized time in window
            t01 = (frame_idx - start_f) / max(1, (end_f - start_f))
            t_eased = ease(t01, args.easing)

            # Fade factor
            fade = 1.0
            fade_in_frames = int(args.fade_in * fps)
            fade_out_frames = int(args.fade_out * fps)
            if frame_idx - start_f < fade_in_frames:
                fade = (frame_idx - start_f) / max(1, fade_in_frames)
            if end_f - frame_idx <= fade_out_frames:
                fade = min(fade, (end_f - frame_idx) / max(1, fade_out_frames))
            fade = clamp01(fade)

            # Prepare overlay canvas
            overlay = np.zeros_like(frame, dtype=np.uint8)
            alpha = np.zeros((height, width), dtype=np.float32)

            # Draw motifs
            for m in motifs:
                m(overlay, alpha, t_eased, colors, rng)

            # Normalize alpha channel and apply global opacity and fade
            alpha = np.clip(alpha, 0.0, 1.0)
            alpha *= (args.opacity * fade)

            overlay_bgra(frame, overlay, alpha)

        # Write original frame or composited frame (duration unchanged)
        writer.write(frame)
        frame_idx += 1

        # If unknown total frames, stop at end of window? No: keep entire original duration.

    cap.release()
    writer.release()


if __name__ == "__main__":
    main()

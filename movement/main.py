import argparse
import os
import random
from typing import Tuple

import cv2
import numpy as np


def parse_args():
    parser = argparse.ArgumentParser(description="Overlay a randomly moving cursor onto a video.")
    parser.add_argument("--video", required=True, help="Path to input video file (e.g., movie.mp4)")
    parser.add_argument("--cursor", required=True, help="Path to cursor image (PNG with alpha), e.g., cursor.png")
    parser.add_argument("--out", required=True, help="Path to output video (e.g., /out/output.mp4)")
    parser.add_argument("--duration", type=float, required=True, help="Duration in seconds for which the cursor moves randomly")
    parser.add_argument("--scale", type=float, default=0.2, help="Scale factor for cursor image (default: 0.2)")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility")
    parser.add_argument("--start", type=float, default=0.0, help="Start time in seconds for the cursor animation (default: 0)")
    parser.add_argument("--speed", type=float, default=300.0, help="Average cursor speed in pixels/second (default: 300)")
    parser.add_argument("--segment", type=float, default=0.5, help="Average seconds per movement segment/direction (default: 0.5)")
    return parser.parse_args()


def load_cursor(cursor_path: str, scale: float) -> Tuple[np.ndarray, np.ndarray]:
    img = cv2.imread(cursor_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        raise ValueError(f"Could not read cursor image at {cursor_path}")

    # Ensure we have an alpha channel and remove near-white backgrounds
    if img.shape[2] == 3:
        bgr = img
        white_mask = (bgr[:, :, 0] > 240) & (bgr[:, :, 1] > 240) & (bgr[:, :, 2] > 240)
        alpha = np.where(white_mask, 0, 255).astype(np.uint8)
        img = np.dstack([bgr, alpha])
    else:
        bgr = img[:, :, :3]
        alpha = img[:, :, 3]
        white_mask = (bgr[:, :, 0] > 240) & (bgr[:, :, 1] > 240) & (bgr[:, :, 2] > 240)
        alpha = np.minimum(alpha, np.where(white_mask, 0, 255).astype(np.uint8))
        img = np.dstack([bgr, alpha])

    if scale != 1.0:
        w = max(1, int(img.shape[1] * scale))
        h = max(1, int(img.shape[0] * scale))
        img = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)

    bgr = img[:, :, :3]
    alpha = img[:, :, 3]
    alpha_f = alpha.astype(float) / 255.0
    return bgr, alpha_f


def overlay_cursor(frame: np.ndarray, cursor_bgr: np.ndarray, cursor_alpha: np.ndarray, x: int, y: int):
    h, w = frame.shape[:2]
    ch, cw = cursor_bgr.shape[:2]

    # Clamp position to frame bounds (top-left placement)
    x = max(0, min(x, w - cw))
    y = max(0, min(y, h - ch))

    roi = frame[y:y+ch, x:x+cw]

    # Alpha blending per channel
    for c in range(0, 3):
        roi[:, :, c] = (cursor_alpha * cursor_bgr[:, :, c] + (1.0 - cursor_alpha) * roi[:, :, c]).astype(np.uint8)

    frame[y:y+ch, x:x+cw] = roi


def random_directions(rng: random.Random, n: int) -> np.ndarray:
    # Random unit vectors (cos theta, sin theta)
    thetas = np.array([rng.uniform(0, 2 * np.pi) for _ in range(n)], dtype=np.float32)
    dirs = np.stack([np.cos(thetas), np.sin(thetas)], axis=1)
    return dirs


def generate_path(
    rng: random.Random,
    width: int,
    height: int,
    cursor_w: int,
    cursor_h: int,
    fps: float,
    start_frame: int,
    end_frame: int,
    avg_speed: float,
    avg_segment_sec: float,
) -> np.ndarray:
    total_frames = end_frame - start_frame
    if total_frames <= 0:
        return np.zeros((0, 2), dtype=np.int32)

    # Choose a starting position within bounds
    x = rng.randint(0, max(0, width - cursor_w))
    y = rng.randint(0, max(0, height - cursor_h))

    # Determine number of segments
    est_segments = max(1, int(np.ceil((total_frames / fps) / max(0.05, avg_segment_sec))))
    dirs = random_directions(rng, est_segments)

    # Speed per frame
    speed_pf = avg_speed / max(1e-6, fps)

    # Frames per segment vary around avg_segment_sec
    frames = []
    remaining = total_frames
    for i in range(est_segments - 1):
        seg = max(1, int(rng.gauss(mu=avg_segment_sec, sigma=avg_segment_sec * 0.3) * fps))
        seg = min(seg, max(1, remaining - (est_segments - i - 1)))
        frames.append(seg)
        remaining -= seg
    frames.append(remaining)

    positions = []
    for seg_len, d in zip(frames, dirs):
        # Add slight jitter to speed
        speed_jitter = max(0.0, rng.gauss(mu=speed_pf, sigma=speed_pf * 0.2))
        dx = d[0] * speed_jitter
        dy = d[1] * speed_jitter
        for _ in range(seg_len):
            # Move
            x += dx
            y += dy
            # Bounce off borders
            if x < 0:
                x = -x
                dx = -dx
            if y < 0:
                y = -y
                dy = -dy
            if x > width - cursor_w:
                x = 2 * (width - cursor_w) - x
                dx = -dx
            if y > height - cursor_h:
                y = 2 * (height - cursor_h) - y
                dy = -dy
            positions.append((int(x), int(y)))

    return np.array(positions, dtype=np.int32)


def main():
    args = parse_args()

    if args.seed is not None:
        rng = random.Random(args.seed)
        np.random.seed(args.seed)
    else:
        rng = random.Random()

    if not os.path.isfile(args.video):
        raise FileNotFoundError(f"Video not found: {args.video}")
    if not os.path.isfile(args.cursor):
        raise FileNotFoundError(f"Cursor image not found: {args.cursor}")

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        raise RuntimeError(f"Failed to open video: {args.video}")

    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_src_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) if cap.get(cv2.CAP_PROP_FRAME_COUNT) > 0 else None

    cursor_bgr, cursor_alpha = load_cursor(args.cursor, args.scale)
    ch, cw = cursor_bgr.shape[:2]

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    writer = cv2.VideoWriter(args.out, fourcc, src_fps, (width, height))
    if not writer.isOpened():
        raise RuntimeError(f"Failed to open output writer for: {args.out}")

    # Compute frame ranges
    start_frame = max(0, int(args.start * src_fps))
    duration_frames = max(0, int(args.duration * src_fps))
    if total_src_frames is None:
        # Stream-like: generate positions for duration, then stop
        end_frame = start_frame + duration_frames
    else:
        end_frame = min(start_frame + duration_frames, total_src_frames)

    positions = generate_path(
        rng=rng,
        width=width,
        height=height,
        cursor_w=cw,
        cursor_h=ch,
        fps=src_fps,
        start_frame=start_frame,
        end_frame=end_frame,
        avg_speed=args.speed,
        avg_segment_sec=args.segment,
    )

    current_frame = 0
    pos_index = 0

    while True:
        ok, frame = cap.read()
        if not ok:
            break

        if start_frame <= current_frame < end_frame and pos_index < len(positions):
            x, y = positions[pos_index]
            overlay_cursor(frame, cursor_bgr, cursor_alpha, x, y)
            pos_index += 1

        writer.write(frame)
        current_frame += 1

        if total_src_frames is None and current_frame >= end_frame:
            # Stop after we've written the requested duration when input length is unknown
            break

    cap.release()
    writer.release()


if __name__ == "__main__":
    main()

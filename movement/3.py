import cv2
import numpy as np
import os

def animate_text(text, frame_size=(640,480), duration=3, font=cv2.FONT_HERSHEY_SIMPLEX, 
                 start_color=(255,0,0), end_color=(0,255,255), move_pixels=50, fade=True):
    fps = 30
    total_frames = int(duration * fps)
    frames = []
    for i in range(total_frames):
        # Generate fade level and color interpolation
        alpha = min(1, i / (fps)) if fade else 1
        color = [int(start_color[j] + (end_color[j] - start_color[j]) * (i / total_frames)) for j in range(3)]
        img = np.zeros((*frame_size,3), dtype=np.uint8)
        y_pos = int(frame_size[1] // 2 + move_pixels * np.sin(np.pi * i / total_frames))
        text_size = cv2.getTextSize(text, font, 2, 3)[0]
        x_pos = (frame_size[0] - text_size[0]) // 2

        overlay = img.copy()
        cv2.putText(overlay, text, (x_pos, y_pos), font, 2, color, 3, cv2.LINE_AA)
        # Blend for fade effect
        new_frame = cv2.addWeighted(img, 1-alpha, overlay, alpha, 0)
        frames.append(new_frame)
    return frames  # List of frames for animation

def animate_logo(png_path, frame_size=(640,480), duration=3, rotate=True, scale_effect=True, out_commands=None):
    script_dir = os.path.dirname(__file__)
    candidates = [
        png_path,
        os.path.join(os.getcwd(), png_path),
        os.path.join(script_dir, png_path),
    ]
    logo = None
    chosen_path = None
    for p in candidates:
        img = cv2.imread(p, cv2.IMREAD_UNCHANGED)
        if img is not None:
            logo = img
            chosen_path = p
            break
    if logo is None:
        # Graceful fallback: return blank frames instead of crashing
        fps = 30
        total_frames = int(duration * fps)
        return [np.zeros((*frame_size, 3), dtype=np.uint8) for _ in range(total_frames)]

    logo_h, logo_w = logo.shape[:2]
    fps = 30
    total_frames = int(duration * fps)
    frames = []
    frame_w, frame_h = frame_size[0], frame_size[1]
    for i in range(total_frames):
        img = np.zeros((frame_h, frame_w, 3), dtype=np.uint8)
        # Rotation
        angle = (360 * i / total_frames) if rotate else 0
        R = cv2.getRotationMatrix2D((logo_w//2, logo_h//2), angle, 1.0)
        rot_logo = cv2.warpAffine(logo, R, (logo_w, logo_h), borderValue=(0,0,0,0))
        # Scaling
        scale = 1 + (0.5 * np.sin(2 * np.pi * i / total_frames)) if scale_effect else 1
        scaled_logo = cv2.resize(rot_logo, None, fx=scale, fy=scale, interpolation=cv2.INTER_LINEAR)
        h, w = scaled_logo.shape[:2]
        # Limit max size to 90% of frame to avoid huge overlays
        max_w = int(frame_w * 0.9)
        max_h = int(frame_h * 0.9)
        if w > max_w or h > max_h:
            s = min(max_w / max(w, 1), max_h / max(h, 1))
            if s < 1:
                scaled_logo = cv2.resize(scaled_logo, (max(1, int(w * s)), max(1, int(h * s))), interpolation=cv2.INTER_AREA)
                h, w = scaled_logo.shape[:2]
        x = (frame_w - w)//2
        y = (frame_h - h)//2
        # Compute intersection with frame bounds
        x1 = max(0, x)
        y1 = max(0, y)
        x2 = min(frame_w, x + w)
        y2 = min(frame_h, y + h)
        if x2 > x1 and y2 > y1:
            sx1 = x1 - x
            sy1 = y1 - y
            sx2 = sx1 + (x2 - x1)
            sy2 = sy1 + (y2 - y1)
            logo_crop = scaled_logo[sy1:sy2, sx1:sx2]
            if logo_crop.shape[2] == 4:
                alpha = (logo_crop[...,3].astype(np.float32) / 255.0)[..., None]
                roi = img[y1:y2, x1:x2, :].astype(np.float32)
                fg = logo_crop[..., :3].astype(np.float32)
                comp = alpha * fg + (1 - alpha) * roi
                img[y1:y2, x1:x2, :] = comp.astype(np.uint8)
            else:
                img[y1:y2, x1:x2, :] = logo_crop[..., :3]
        frames.append(img)
    return frames  # List of frames for animation

# Example usage
text_frames = animate_text("Amazing!", fade=True)
logo_frames = animate_logo("logo.png", rotate=True, scale_effect=True)

# Save as video
out = cv2.VideoWriter("text_anim.avi", cv2.VideoWriter_fourcc(*'XVID'), 30, (640,480))
for frame in text_frames:
    out.write(frame)
out.release()

out2 = cv2.VideoWriter("logo_anim.avi", cv2.VideoWriter_fourcc(*'XVID'), 30, (640,480))
for frame in logo_frames:
    out2.write(frame)
out2.release()

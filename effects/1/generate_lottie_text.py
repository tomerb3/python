#!/usr/bin/env python3
import json
import argparse

# Generate a simple Lottie JSON with a single text layer and a basic animation
# Effects supported:
# - fade: opacity from 0 -> 100 over the first 30% of duration
# - slide: position X from off-screen left -> center over first 30% of duration (with optional fade-in)

def build_lottie_text(
    text: str,
    width: int = 1024,
    height: int = 256,
    duration: float = 4.0,
    fps: int = 30,
    font: str = "Arial",
    font_size: int = 72,
    color_hex: str = "#ffffff",
    effect: str = "slide",
    fade_also: bool = True,
):
    # Convert color hex to [r,g,b] 0..1
    def hex_to_rgb01(h: str):
        h = h.strip()
        if h.startswith('#'):
            h = h[1:]
        if len(h) == 3:
            h = ''.join([c*2 for c in h])
        if len(h) != 6:
            return [1, 1, 1]
        r = int(h[0:2], 16) / 255.0
        g = int(h[2:4], 16) / 255.0
        b = int(h[4:6], 16) / 255.0
        return [round(r,4), round(g,4), round(b,4)]

    # Lottie expects newlines as \r in many exports
    text = text.replace('\n', '\r')

    total_frames = int(round(duration * fps))
    if total_frames < 2:
        total_frames = 2

    # Keyframe times
    t0 = 0
    t_in = max(1, int(0.3 * total_frames))  # 30% of duration for entrance
    t_end = total_frames

    # Base text document settings
    text_doc = {
        "f": font,              # font family name
        "s": float(font_size),  # font size
        "t": text,              # text content
        "j": 1,                 # 0: left, 1: center, 2: right
        "tr": 0,                # tracking
        "lh": round(font_size * 1.2, 2),  # line height
        "ls": 0,                # letter spacing
        "fc": hex_to_rgb01(color_hex),    # fill color
    }

    # Opacity property (ks.o)
    if effect == "fade":
        o_prop = {
            "a": 1,
            "k": [
                {"t": t0, "s": [0], "e": [100]},
                {"t": t_in}
            ]
        }
        p_prop = {"a": 0, "k": [width/2, height/2, 0]}
    elif effect == "slide":
        o_prop = {
            "a": 1 if fade_also else 0,
            "k": ([{"t": t0, "s": [0], "e": [100]}, {"t": t_in}] if fade_also else 100)
        }
        p_prop = {
            "a": 1,
            "k": [
                {"t": t0, "s": [-width*0.5, height/2, 0], "e": [width/2, height/2, 0], "to": [0,0,0], "ti": [0,0,0]},
                {"t": t_in}
            ]
        }
    else:
        # default: no entrance anim
        o_prop = {"a": 0, "k": 100}
        p_prop = {"a": 0, "k": [width/2, height/2, 0]}

    layer = {
        "ddd": 0,
        "ind": 1,
        "ty": 5,                 # text layer
        "nm": "Text",
        "sr": 1,
        "ks": {
            "o": o_prop,
            "r": {"a": 0, "k": 0},
            "p": p_prop,
            "a": {"a": 0, "k": [0, 0, 0]},
            "s": {"a": 0, "k": [100, 100, 100]}
        },
        "ao": 0,
        "t": {
            "d": {
                "k": [
                    {"s": text_doc, "t": 0}
                ]
            },
            "p": {"m": 0, "f": ""},
            "m": {"g": 1, "a": {"a": 0, "k": 0}}
        },
        "ip": 0,
        "op": t_end,
        "st": 0,
        "bm": 0
    }

    comp = {
        "v": "5.7.4",
        "fr": fps,
        "ip": 0,
        "op": t_end,
        "w": width,
        "h": height,
        "nm": "TextComp",
        "ddd": 0,
        "assets": [],
        "layers": [layer]
    }

    return comp


def main():
    ap = argparse.ArgumentParser(description="Generate a simple Lottie JSON with a text layer and animation.")
    ap.add_argument("--out", default="anim1.json", help="Output Lottie JSON path")
    ap.add_argument("--text", required=True, help="Text content")
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--height", type=int, default=256)
    ap.add_argument("--duration", type=float, default=4.0)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--font", default="Arial")
    ap.add_argument("--fontSize", type=int, default=72)
    ap.add_argument("--color", default="#ffffff")
    ap.add_argument("--effect", choices=["fade", "slide"], default="slide")
    args = ap.parse_args()

    data = build_lottie_text(
        text=args.text,
        width=args.width,
        height=args.height,
        duration=args.duration,
        fps=args.fps,
        font=args.font,
        font_size=args.fontSize,
        color_hex=args.color,
        effect=args.effect,
    )

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    print(f"Wrote {args.out} (w={args.width}, h={args.height}, duration={args.duration}s, fps={args.fps})")


if __name__ == "__main__":
    main()

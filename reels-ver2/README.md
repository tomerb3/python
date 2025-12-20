# reels-ver2 — Viral Carousel Reel Builder (Spec)

This folder will contain a Bash + ffmpeg pipeline to generate a single Instagram Reel (vertical video) from 4 PNG slides.

The output video should look like an Instagram **carousel**:
- Slide 1 -> Slide 2 -> Slide 3 -> Slide 4
- Transition direction: **right-to-left**

Each PNG slide has 3 logical regions:
- **Top**: black bar area (optional text)
- **Middle**: main area (optional text, centered)
- **Bottom**: black bar area (optional text)

This README is the **single source of truth** for coordinates/parameters so you can adjust values later and continue the conversation.

---

## 1) Inputs

### Required
- `file1.png`
- `file2.png`
- `file3.png`
- `file4.png`

### Optional
- `bg.mp3` (background music to play over the final reel)
- `overlay1.mp4`, `overlay2.mp4`, `overlay3.mp4`, `overlay4.mp4`
  - Optional per-slide overlay video layer.
  - Can be muted or mixed at a specific volume.

### Font
- Provide a font file path (TTF/OTF), e.g.
  - `./fonts/MyFont.ttf`

---

## 2) Output

- Individual slide clips (intermediate):
  - `out/slide1.mp4`
  - `out/slide2.mp4`
  - `out/slide3.mp4`
  - `out/slide4.mp4`
- Final reel:
  - `out/reel.mp4`

---

## 3) Target Canvas / Video Settings (EDIT THIS)

Set your desired output format here.

- `CANVAS_W`: `1080`
- `CANVAS_H`: `1920`
- `FPS`: `30`

Durations:
- `SLIDE_DUR_SEC`: `2.0`
- `TRANSITION_DUR_SEC`: `0.6`

Encoding:
- H.264 (`libx264`)
- Pixel format: `yuv420p`

---

## 4) Region Coordinates (EDIT THIS)

Coordinate system assumption:
- Origin `(0,0)` is top-left of the final canvas.
- Units are pixels.

You will replace the guessed values below with your real ones.

### Top black region (text box)
- `TOP_X`: `0`
- `TOP_Y`: `0`
- `TOP_W`: `1080`
- `TOP_H`: `260`

### Middle region (text box)
- `MID_X`: `0`
- `MID_Y`: `260`
- `MID_W`: `1080`
- `MID_H`: `1400`

### Bottom black region (text box)
- `BOT_X`: `0`
- `BOT_Y`: `1660`
- `BOT_W`: `1080`
- `BOT_H`: `260`

Notes:
- Your PNGs already contain the black bars, so these coordinates are only for placing text.
- If you later change the PNGs, we can also render the black rectangles as part of the pipeline.

---

## 5) Text Overlay Parameters

Each slide may have 0..3 text overlays (top/middle/bottom).

Per text overlay parameters:
- `TEXT` (string; can be empty to skip)
- `FONT_FILE` (path)
- `FONT_SIZE_PX` (integer)
- `FONT_COLOR` (e.g. `white` or `#FFFFFF`)
- `OUTLINE_COLOR` (e.g. `black` or `#000000`)
- `OUTLINE_THICKNESS`
  - We will use **pixels** in the script.
  - If you want mm: define `DPI` and convert: `px = mm * DPI / 25.4`.

Alignment:
- Top text: usually centered within TOP region.
- Middle text: centered within MID region.
- Bottom text: centered within BOT region.

---

## 6) Text Wrapping Rules (EDIT THIS)

ffmpeg `drawtext` does not auto-wrap well for all cases. We will pre-wrap text in Bash.

Choose one wrapping mode:

### Mode A: wrap by words-per-line
- `WRAP_MODE`: `words`
- `WORDS_PER_LINE`: e.g. `4`

Example:
- Input: `"THIS IS A VIRAL TITLE RIGHT NOW"`
- Words per line 4 =>
  - `THIS IS A VIRAL`
  - `TITLE RIGHT NOW`

### Mode B: wrap by max characters per line
- `WRAP_MODE`: `chars`
- `CHARS_PER_LINE`: e.g. `18`

---

## 7) Carousel Transition Requirement

You asked for:
- “slide effect of middle area from right to left like instagram carousel”.

There are two interpretations (choose one):

### Transition Type 1 (Simpler): full-frame swipe
- Entire slide (including top/bottom/middle) moves right-to-left.
- Implementation: ffmpeg `xfade=transition=slideleft`.

### Transition Type 2 (Advanced): middle-only swipe
- Top and bottom regions remain static.
- Only the middle region animates right-to-left.
- Implementation: more complex ffmpeg filter graph (crop + overlay with time-based x).

**DECIDE AND WRITE HERE**:
- `TRANSITION_TYPE`: `full` OR `middle_only`

Confirmed choice:
- `TRANSITION_TYPE`: `middle_only`

Default for initial build will likely be `full` unless you insist on `middle_only`.

---

## 8) Audio Requirements

### Background music (global)
- If `bg.mp3` is present:
  - It will be mixed into the final reel.
  - If bg.mp3 is longer than the reel, it will be trimmed.
  - If bg.mp3 is shorter, it can be looped (we will decide later).

Confirmed:
- MP3 should stop at the end of the reel (trim to reel duration).

### Optional per-slide overlay video audio
For each slide overlay video (if provided):
- `MUTE_OVERLAY_AUDIO`: `yes|no`
- If not muted, provide:
  - `OVERLAY_VOLUME`: float (e.g. `0.2`, `0.7`, `1.0`)

Mixing rules (to confirm later):
- bg.mp3 at a constant volume (e.g. 0.7)
- overlay audio optional at requested volume

---

## 9) Script Interface (what we will implement in script.sh)

We will implement 4 functions (one per slide) and a final merge.

### Slide render function (concept)
For each slide `N`:
- Input:
  - PNG: `fileN.png`
  - (optional) overlay video: `overlayN.mp4`
  - top/mid/bot text parameters
- Output:
  - `out/slideN.mp4`

Conceptual signature:
- `render_slide N \
    --png fileN.png \
    --out out/slideN.mp4 \
    --font ./fonts/MyFont.ttf \
    --top-text "..." --top-size 72 --top-color "white" --top-outline-color "black" --top-outline 4 \
    --mid-text "..." --mid-size 90 --mid-color "white" --mid-outline-color "black" --mid-outline 6 \
    --bot-text "..." --bot-size 64 --bot-color "white" --bot-outline-color "black" --bot-outline 4 \
    --wrap-mode words --words-per-line 4 \
    --overlay overlayN.mp4 --overlay-mute yes|no --overlay-volume 0.3`

(Exact CLI flags may evolve, but this is the target.)

### Merge function
- Inputs:
  - `out/slide1.mp4..out/slide4.mp4`
  - optional `bg.mp3`
- Output:
  - `out/reel.mp4`

Conceptual signature:
- `merge_reel --slides out/slide1.mp4 out/slide2.mp4 out/slide3.mp4 out/slide4.mp4 --bg bg.mp3 --out out/reel.mp4`

---

## 10) Values To Fill In (Checklist)

Fill these in when you’re ready:
- Canvas:
  - `CANVAS_W`, `CANVAS_H`, `FPS`
- Durations:
  - `SLIDE_DUR_SEC`, `TRANSITION_DUR_SEC`
- Region coordinates:
  - TOP: `X,Y,W,H`
  - MID: `X,Y,W,H`
  - BOT: `X,Y,W,H`
- Fonts:
  - `FONT_FILE`
- Wrapping:
  - `WRAP_MODE` and `WORDS_PER_LINE` or `CHARS_PER_LINE`
- Transition type:
  - `TRANSITION_TYPE` = `full` or `middle_only`
- Audio:
  - `bg.mp3` present?
  - overlay audio per slide: mute/volume

---

## 11) Open Questions (Answer in this file)

1) Do your PNGs already contain the black bars, or do we need to draw them?
2) Should `bg.mp3` be looped if shorter than reel? (yes/no)
3) Outline thickness: do you accept pixels, or do you want mm->px conversion using a chosen DPI?
4) Confirm transition type: `full` vs `middle_only`.

---

## 12) Current Status

- `script.sh` exists but is empty.
- Next step (baby-step) will be to implement **one** slide render pipeline and validate it produces `out/slide1.mp4`.

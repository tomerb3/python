# Lottie Overlay (n8n-ready)

One-pass overlay of a Lottie (lottie-web) animation on a video. Renders frames in headless Chrome and streams PNGs directly into a single ffmpeg overlay filter.

## Usage

Install deps:

```bash
npm i --omit=dev
```


anim1.json  https://app.lottiefiles.com/animation/48a9da0d-9df6-4c49-8ea0-2591214820b4?channel=web&from=download&panel=download&source=public-animation



Run:

```bash
node overlay.js \
  --video ./input.mp4 \
  --lottie ./anim.json \
  --x 100 --y 120 --scale 1.0 \
  --start 2.0 --duration 5 \
  --fps 30 \
  --overlayWidth 512 --overlayHeight 512 \
  --out ./output.mp4
```

## Docker

```bash
docker build -t lottie-overlay:latest .
docker run --rm -v "$PWD:/data" lottie-overlay:latest \
  node overlay.js \
  --video /data/input.mp4 \
  --lottie /data/anim.json \
  --x 100 --y 120 --scale 1 \
  --start 0 --duration 4 --fps 30 \
  --overlayWidth 512 --overlayHeight 512 \
  --out /data/out.mp4
```

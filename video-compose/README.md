# Video Compose Utilities

Utilities for composing videos using ffmpeg and optional Node-based Lottie rendering. The primary entrypoint is `video_functions.py`, which provides several actions:

- last_frame
- add_sound
- animate_text_with_lottie (Node + puppeteer)
- running_code (ffmpeg drawtext)
- mouse_move (PNG cursor overlay)

## Requirements

- Docker (recommended) or local Python + ffmpeg
- ffmpeg (installed in Docker image)
- For Lottie overlay: Node.js and npm (installed in Docker image) and puppeteer dependency (installed in the project via npm)

## Project layout

```
video-compose/
├─ Dockerfile
├─ docker-entrypoint.sh
├─ video_functions.py
├─ overlay.js
├─ renderer.html
├─ package.json
├─ node_modules/               # created by npm install
└─ data/, back/, files/, ...   # your media assets
```

## Quick start (Docker)

1) Build the image (named `test1` in examples):

```bash
cd /home/baum/src/python/video-compose
docker build -t test1 --build-arg PYTHON_IMAGE=python:3.6.9-slim .
```


## Actions and arguments

Entry: `video_functions.py` (Python 3). All actions share `--input_video` and `--output_video`.



## general tips 

# to check how much seconds this video clip . and then shorter result in 1 second 
sec=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 codewrite.mp4)
short=$(awk -v s="$sec" 'BEGIN{d=s-1; if(d<0)d=0; printf "%.3f", d}')
echo "$short"









### last_frame
Create a still video from the last frame of an input.

```bash
--action last_frame --input_video <in> --output_video <out> --seconds 5 --fps 30
```

- seconds: duration of the still video
- fps: output frames per second



## take last frame from codewrite.mp4 video and make from it 20 seconds mp4 video 

docker run -ti --rm \
  -v /home/baum/venv/src:/venv-host:ro \
  -v /home/baum/src/example:/app/data \
  -v /home/baum/src/example:/app/back \
  -v /home/baum/src/example/fonts:/home/node/tts/fonts \
  -v /home/baum/src/python/video-compose:/app \
  test1 python video_functions.py \
  --action last_frame \
  --second 20 \
  --input_video /app/data/codewrite.mp4 \
  --output_video /app/data/output.mp4 


# done 




### add_sound
Mix a short sound into the main audio at a given start time.

for key strokes audio . and for bell audio 

```bash
--action add_sound --input_video <in> --output_video <out> \
  --sound /app/data/sfx.wav --start 3.5 [--sound_duration 2.0] [--volume 0.6]
```

- sound: path to sound file
- start: seconds offset where to mix the sound in
- sound_duration: optional trim of the sound effect
- volume: optional volume multiplier


docker run -ti --rm \
  -v /home/baum/venv/src:/venv-host:ro \
  -v /home/baum/src/example:/app/data \
  -v /home/baum/src/example:/app/back \
  -v /home/baum/src/example/fonts:/home/node/tts/fonts \
  -v /home/baum/src/python/video-compose:/app \
  test1 python video_functions.py \
  --action add_sound \
  --input_video /app/data/output.mp4 \
  --output_video /app/data/output2.mp4 \
  --sound /app/data/key.mp3 \
  --start 1 \
  --sound_duration 4.0 \
  --volume 0.6






# tip how to create folder - few ring bells from pexels. 
pv src 
 
it will create folder. _fs_previews 
  and inside 4 examples 
    it will choose 1 of them random  

python add_sound_from_freesound.py --query "girl" --input ../../example/back-20.mp4 --output 1.mp4 --frame 130 --gain 1.0 --verbose














2) Install Node dependencies on the host so the container can see them via the bind mount:

```bash
npm install --omit=dev
```

3) Run an example (Lottie overlay):

```bash
docker run -ti --rm \
  -v /home/baum/venv/src:/venv-host:ro \
  -v /home/baum/src/example:/app/data \
  -v /home/baum/src/example:/app/back \
  -v /home/baum/src/example/fonts:/home/node/tts/fonts \
  -v /home/baum/src/python/video-compose:/app \
  test1 python video_functions.py \
  --action animate_text_with_lottie \
  --input_video /app/data/back-20.mp4 \
  --output_video /app/data/output.mp4 \
  --lottie_json /app/data/lottie.json \
  --x 100 --y 100 --start 0 --duration 10
```

If your `overlay.js` lives elsewhere, pass `--overlay_js /app/overlay.js` (defaults to `/app/overlay.js`).





### animate_text_with_lottie
Overlay a Lottie animation using a Node renderer (puppeteer) then ffmpeg overlay.

```bash
--action animate_text_with_lottie --input_video <in> --output_video <out> \
  --lottie_json /app/data/lottie.json --x 100 --y 100 --start 0 --duration 10 \
  [--fps 30] [--scale 1.0] [--overlay_width 512] [--overlay_height 512] \
  [--overlay_js /app/overlay.js]
```

- Requires Node.js + puppeteer. Ensure `npm install` was run.
- x,y: integer overlay position in pixels
- start,duration: seconds
- overlay_js: optional path to the renderer script (defaults to `/app/overlay.js`)

Text mode (no Lottie JSON) is also supported by `overlay.js` directly (not through `video_functions.py` yet):

```bash
node overlay.js --video <in> --text "Hello" --font Arial --fontSize 72 --color "#ffffff" \
  --effect fade --fps 30 --duration 3 --x 100 --y 100 --overlayWidth 512 --overlayHeight 512 --out <out>
```

### running_code (ffmpeg drawtext)
Draws text via ffmpeg `drawtext` with careful escaping for special characters.

```bash
--action running_code --input_video <in> --output_video <out> \
  --text "Text with : and ' and \\" \
  --x "(w-text_w)/2" --y "(h-text_h)/2" \
  --start 1 --duration 3 --fontsize 48 --fontcolor "white" [--fontfile /app/fonts/MyFont.ttf]
```

- x,y accept expressions (ffmpeg drawtext)
- Text is escaped for colons `:`, single quotes `'`, and backslashes `\\`

### mouse_move
Overlays a PNG cursor at a position and time window.

```bash
--action mouse_move --input_video <in> --output_video <out> \
  --cursor_png /app/data/cursor.png --x 200 --y 150 --start 2 --duration 4 \
  [--scale_cursor 1.0]
```

## Implementation notes

- `run(cmd)` prints the command and raises if the exit code is non-zero.
- `ensure_ffmpeg()` and `ensure_node()` validate runtime availability.
- Lottie overlay uses `overlay.js` which renders frames with puppeteer (`renderer.html`) and pipes them into ffmpeg via `image2pipe`.
- `video_functions.py` escapes drawtext content to avoid ffmpeg parse errors.

## Troubleshooting

- Node not found: Rebuild Docker image or install NodeJS on the host and mount it.
- Cannot find module 'puppeteer': run `npm install` in the project directory so `node_modules/` exists.
- overlay.js not found: pass `--overlay_js` to `video_functions.py` or ensure `overlay.js` exists in `/app`.
- ffmpeg errors: ensure input paths are correct and readable inside the container (`/app/...`).

## License

MIT (or your preferred license).

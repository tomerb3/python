#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const puppeteer = require('puppeteer');

function arg(name, defVal = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  if (i !== -1 && i + 1 < process.argv.length) return process.argv[i + 1];
  return defVal;
}
function flag(name) {
  return process.argv.includes(`--${name}`);
}

(async () => {
  const video = arg('video');
  const lottie = arg('lottie');               // URL or local file path
  const out = arg('out', 'output.mp4');

  if (!video || !lottie) {
    console.error('Usage: node overlay.js --video <videoPathOrURL> --lottie <jsonPathOrURL> [--x 0 --y 0 --scale 1 --start 0 --duration 5 --fps 30 --overlayWidth 512 --overlayHeight 512]');
    process.exit(2);
  }

  const x = parseInt(arg('x', '0'), 10);
  const y = parseInt(arg('y', '0'), 10);
  const scale = parseFloat(arg('scale', '1'));
  const fps = parseInt(arg('fps', '30'), 10);
  const start = parseFloat(arg('start', '0'));
  const duration = arg('duration') ? parseFloat(arg('duration')) : null;
  const overlayWidth = parseInt(arg('overlayWidth', '512'), 10);
  const overlayHeight = parseInt(arg('overlayHeight', '512'), 10);

  // Resolve local file paths to file:// URLs so the HTML page can fetch them
  function toUrlMaybeLocal(p) {
    if (/^https?:\/\//i.test(p)) return p;
    const abs = path.resolve(p);
    return 'file://' + abs;
  }

  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--allow-file-access-from-files',
      '--enable-features=NetworkService,NetworkServiceInProcess'
    ]
  });

  let exitCode = 1;
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: overlayWidth, height: overlayHeight, deviceScaleFactor: 1 });

    const htmlPath = path.resolve(__dirname, 'renderer.html');
    const url = `file://${htmlPath}?width=${overlayWidth}&height=${overlayHeight}&scale=${scale}&lottie=${encodeURIComponent(toUrlMaybeLocal(lottie))}`;
    await page.goto(url, { waitUntil: 'load' });

    // Ensure anim is ready
    await page.waitForFunction('window.__getMeta && window.__getMeta() !== null', { timeout: 30000 });
    const meta = await page.evaluate('window.__getMeta()');

    // Determine frame counts
    const effectiveFps = fps || meta.fr || 30;
    const totalSeconds = duration != null ? duration : meta.duration;
    const totalFrames = Math.max(1, Math.round(totalSeconds * effectiveFps));

    // Build filter
    const enableExpr = duration == null
      ? `gte(t,${start})`
      : `between(t,${start},${(start + totalSeconds).toFixed(3)})`;

    const filterComplex = `[0:v][1:v]overlay=${x}:${y}:format=auto:eval=frame:enable='${enableExpr}'[vout]`;
    const fullArgs = [
      '-y',
      '-i', toUrlMaybeLocal(video),
      '-f', 'image2pipe',
      '-framerate', String(effectiveFps),
      '-i', 'pipe:0',
      '-filter_complex', filterComplex,
      '-map', '[vout]',
      '-map', '0:a?',
      '-shortest',
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
      '-preset', 'veryfast',
      '-crf', '20',
      out
    ];

    const ff = spawn('ffmpeg', fullArgs, { stdio: ['pipe', 'inherit', 'inherit'] });

    ff.on('error', (err) => {
      console.error('ffmpeg spawn error:', err);
    });

    // Stream frames
    for (let i = 0; i < totalFrames; i++) {
      const frameNumber = Math.round(i * (meta.fr || effectiveFps) * (1 / effectiveFps)); // map requested fps to lottie internal fr
      const dataUrl = await page.evaluate((f) => window.__renderFrame(f), frameNumber);
      const base64 = dataUrl.split(',')[1];
      const buf = Buffer.from(base64, 'base64');
      const ok = ff.stdin.write(buf);
      if (!ok) {
        await new Promise(res => ff.stdin.once('drain', res));
      }
    }

    ff.stdin.end();

    await new Promise((resolve, reject) => {
      ff.on('close', (code) => {
        if (code === 0) resolve();
        else reject(new Error(`ffmpeg exited with code ${code}`));
      });
    });

    console.log('Overlay complete:', out);
    exitCode = 0;
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await browser.close().catch(() => {});
    process.exit(exitCode);
  }
})();

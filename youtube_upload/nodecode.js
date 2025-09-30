// Inputs expected on items[0].json (from a Set node or similar):
// before, before_audio, duration_before
// code, code_audio (or code_autio), duration_code
// running, running_audio, duration_running
// after, after_audio, duration_after
// Optional per-section extras you can add later:
//   filter_script (e.g., filter_script_code), video_start (e.g., video_start_running)
// Optional top-level overrides:
//   output, width, height, fps, video_codec, audio_codec, crf, preset

const i = items[0]?.json ?? {};

const isNone = (v) => v == null || String(v).trim().toLowerCase() === 'none';
const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

// Build candidate sections based on your fields
const candidates = [
  {
    name: 'before',
    video: i.before,
    audio: i.before_audio,
    duration: num(i.duration_before),
    video_start: i.video_start_before,           // optional
    filter_script: i.filter_script_before,       // optional
  },
  {
    name: 'code',
    video: i.code,
    audio: i.code_audio ?? i.code_autio,         // support both spellings
    duration: num(i.duration_code),
    video_start: i.video_start_code,             // optional
    filter_script: i.filter_script_code,         // optional
  },
  {
    name: 'running',
    video: i.running,
    audio: i.running_audio,
    duration: num(i.duration_running),
    video_start: i.video_start_running,          // optional
    filter_script: i.filter_script_running,      // optional
  },
  {
    name: 'after',
    video: i.after,
    audio: i.after_audio,
    duration: num(i.duration_after),
    video_start: i.video_start_after,            // optional
    filter_script: i.filter_script_after,        // optional
  },
];

// Keep only valid sections: require video, audio not "none", and positive duration
const sections = [];
for (const s of candidates) {
  if (isNone(s.video) || isNone(s.audio) || !(s.duration > 0)) continue;

  const sec = {
    duration: s.duration,
    video: String(s.video),
    audio: String(s.audio),
  };
  // Optional fields if provided and valid
  if (s.video_start != null && Number.isFinite(num(s.video_start)) && num(s.video_start) >= 0) {
    sec.video_start = num(s.video_start);
  }
  if (s.filter_script && !isNone(s.filter_script)) {
    sec.filter_script = String(s.filter_script);
  }
  sections.push(sec);
}

// Build final result with top-level defaults (can be overridden via inputs)
const result = {
  output: String(i.output ?? 'output.mp4'),
  width: Number(i.width ?? 1920),
  height: Number(i.height ?? 1080),
  fps: Number(i.fps ?? 30),
  video_codec: String(i.video_codec ?? 'libx264'),
  audio_codec: String(i.audio_codec ?? 'aac'),
  crf: Number(i.crf ?? 23),
  preset: String(i.preset ?? 'medium'),
  sections,
};

return [{ json: result }];
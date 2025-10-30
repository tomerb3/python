#!/bin/bash -x

set -euo pipefail


# to download 5 pexels video relate to string: 
# ./ffmpeg-run.sh pexels "laptop code" 5

usage() {
  echo "Usage: $0 <command> [args...]" >&2
  echo "Commands:" >&2
  echo "  one_mp3 <in_mp4> <mp3> <out_mp4>" >&2
  echo "  two_mp3 <in_mp4> <mp3_primary> <mp3_secondary> <offset_seconds> <out_mp4>" >&2
  echo "  concat <out_mp4> <in1.mp4> [in2.mp4 ...]" >&2
  echo "didnt test yet"

  echo "  filter_script <in_mp4> <filters.txt> <voice.mp3> <key.mp3> <lines_count> <out_mp4> [halfkey.mp3]" >&2
  echo "  freeze_last_frame <in_mp4> <seconds> <out_mp4>" >&2
  echo "  running_code <in_mp4> <textfile> <x> <y> <seconds> <start_delay> <out_mp4> [sfx.mp3] [explain.mp3]" >&2
  exit 1
}


# before run filter_script function 
check_num_lines() {
  LINES_COUNT=$(
    awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' /home/baum/src/python/ffmpeg/video_script.txt
  )
  echo "lines_count=$LINES_COUNT"
}




pexels_download_videos() {
  local query="$1"; local count="$2"; local outdir
  if [ -z "${PEXELS_API_KEY:-}" ]; then echo "PEXELS_API_KEY is required" >&2; exit 1; fi
  if [ -z "$query" ] || [ -z "$count" ]; then echo "query and count are required" >&2; exit 1; fi
  outdir="${output:-${output_folder:-./output}}"
  mkdir -p "$outdir"
  local downloaded=0 page=1 per_page=30
  while [ "$downloaded" -lt "$count" ]; do
    local remaining=$((count-downloaded))
    local pp=$per_page; if [ "$remaining" -lt "$per_page" ]; then pp="$remaining"; fi
    local resp
    resp=$(curl -sS -G "https://api.pexels.com/videos/search" \
      --data-urlencode "query=$query" --data-urlencode "per_page=$pp" --data-urlencode "page=$page" \
      -H "Authorization: $PEXELS_API_KEY")
    mapfile -t lines < <(printf '%s' "$resp" | python3 -c '
import sys, json
data = json.loads(sys.stdin.read() or "{}")
for v in data.get("videos", []):
    vid = v.get("id")
    files = v.get("video_files") or []
    if not files:
        continue
    def key(f):
        return (f.get("width") or 0, f.get("height") or 0, f.get("bitrate") or 0)
    best = max(files, key=key)
    url = best.get("link") or best.get("file")
    if vid is not None and url:
        print(f"{vid}\t{url}")
')
    if [ "${#lines[@]}" -eq 0 ]; then break; fi
    local line id url fname base
    for line in "${lines[@]}"; do
      if [ "$downloaded" -ge "$count" ]; then break; fi
      id="${line%%$'\t'*}"
      url="${line#*$'\t'}"
      base=$(printf '%s' "$query" | tr ' /\t' '___')
      fname="$outdir/${base}__${id}_${downloaded}.mp4"
      curl -sSL "$url" -o "$fname"
      downloaded=$((downloaded+1))
    done
    page=$((page+1))
  done
}



dur() {
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" | awk '{printf "%.3f\n", $1}'
}

trailing_silence_remain() {
  local afile="$1"
  local total
  total=$(dur "$afile")
  local last_end="0"
  local last_dur="0"
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ silence_end:\ ([0-9.]+) ]]; then
      last_end="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ silence_duration:\ ([0-9.]+) ]]; then
      last_dur="${BASH_REMATCH[1]}"
    fi
  done < <(ffmpeg -hide_banner -nostats -i "$afile" -af "silencedetect=noise=-50dB:d=0.2" -f null - 2>&1 || true)
  awk -v total="$total" -v end="$last_end" -v sdur="$last_dur" '
    BEGIN {
      rem = 1.0
      if (end > 0 && (total - end) <= 0.3) {
        rem = 1.0 - sdur
      }
      if (rem < 0) rem = 0
      printf "%.3f\n", rem
    }
  '
}

encode_video_audio() {
  local in_mp4="$1"
  local a_file="$2"
  local out_mp4="$3"
  local duration="$4"
  ffmpeg -y \
    -i "$in_mp4" -i "$a_file" \
    -map 0:v:0 -map 1:a:0 \
    -c:v libx264 -preset veryfast -crf 20 -r 30 -pix_fmt yuv420p \
    -filter:a "aformat=channel_layouts=stereo:sample_rates=48000,loudnorm=I=-14:TP=-1.0:LRA=11" \
    -c:a aac -b:a 192k \
    -t "$duration" \
    "$out_mp4"
}

encode_video_filter_script() {
  local in_mp4="$1"
  local script="$2"
  local voice_mp3="$3"
  local key_mp3="$4"
  local lines_count="$5"
  local out_mp4="$6"
  local duration="$7"
  local halfkey_mp3="${8:-}"
  # Read and flatten the video filter chain from the script
  local fchain
  fchain=$(tr -d '\n' < "$script")
  fchain="${fchain%,}"
  fchain="${fchain%.}"
  # Optional defaults for drawtext injected via env vars (do not override per-filter settings)
  # RC_FONTFILE or RC_FONT, RC_FONTSIZE, RC_FONTCOLOR
  if [ -n "${RC_FONTFILE:-}" ]; then
    esc=$(printf %s "$RC_FONTFILE" | sed -e "s/[\\/&]/\\\\&/g")
    fchain=$(printf %s "$fchain" | sed -E "s/drawtext=/drawtext=fontfile='${esc}':/g")
  elif [ -n "${RC_FONT:-}" ]; then
    esc=$(printf %s "$RC_FONT" | sed -e "s/[\\/&]/\\\\&/g")
    fchain=$(printf %s "$fchain" | sed -E "s/drawtext=/drawtext=font='${esc}':/g")
  fi
  if [ -n "${RC_FONTSIZE:-}" ]; then
    fchain=$(printf %s "$fchain" | sed -E "s/drawtext=/drawtext=fontsize=${RC_FONTSIZE}:/g")
  fi
  if [ -n "${RC_FONTCOLOR:-}" ]; then
    esc=$(printf %s "$RC_FONTCOLOR" | sed -e "s/[\\\/&]/\\\\&/g")
    fchain=$(printf %s "$fchain" | sed -E "s/drawtext=/drawtext=fontcolor=${esc}:/g")
  fi
  # Improve text sharpness: enable FreeType autohint for all drawtext filters
  fchain=$(printf %s "$fchain" | sed -E "s/drawtext=/drawtext=ft_load_flags=force_autohint:/g")
  # Build a unified filter_complex: video + audio mix
  # [0:v] -> video filters -> [vout]
  # [1:a] voice trimmed -> [a1]; [2:a] key (looped) -> [a2m]; optional [3:a] halfkey -> [a3]; concat -> [a2]; amix -> [aout]
  local fc
  # Render in RGB for crisper glyph rasterization, then convert to 4:4:4 before encode step
  fc="[0:v]format=rgb24,${fchain},format=yuv444p[vout];"
  fc+="[1:a]aformat=channel_layouts=stereo:sample_rates=48000,apad=pad_dur=${duration},atrim=0:${duration},asetpts=PTS-STARTPTS[a1];"
  # Loop the first 2 seconds of key audio lines_count times: at 48kHz, 2s -> size=96000 samples, loop=(lines_count-1)
  fc+="[2:a]aformat=channel_layouts=stereo:sample_rates=48000,atrim=0:2,asetpts=PTS-STARTPTS,aloop=loop=$((lines_count-1)):size=96000:start=0[a2m];"
  if [ -n "$halfkey_mp3" ] && [ -f "$halfkey_mp3" ]; then
    fc+="[3:a]aformat=channel_layouts=stereo:sample_rates=48000,atrim=0:2,asetpts=PTS-STARTPTS[a3];[a2m][a3]concat=n=2:v=0:a=1,apad=pad_dur=${duration},atrim=0:${duration}[a2];"
  else
    fc+="[a2m]apad=pad_dur=${duration},atrim=0:${duration}[a2];"
  fi
  fc+="[a1][a2]amix=inputs=2:duration=longest:dropout_transition=0,loudnorm=I=-14:TP=-1.0:LRA=11[aout]"
  if [ -n "$halfkey_mp3" ] && [ -f "$halfkey_mp3" ]; then
    ffmpeg -y \
      -i "$in_mp4" -i "$voice_mp3" -stream_loop -1 -i "$key_mp3" -i "$halfkey_mp3" \
      -t "$duration" \
      -filter_complex "$fc" \
      -map "[vout]" -map "[aout]" \
      -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
      -c:a aac -b:a 192k \
      "$out_mp4"
  else
    ffmpeg -y \
      -i "$in_mp4" -i "$voice_mp3" -stream_loop -1 -i "$key_mp3" \
      -t "$duration" \
      -filter_complex "$fc" \
      -map "[vout]" -map "[aout]" \
      -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
      -c:a aac -b:a 192k \
      "$out_mp4"
  fi
}

one_mp3() {
  local in_mp4="$1"; local mp3="$2"; local out_mp4="$3"
  local base_dur rem target
  base_dur=$(dur "$mp3")
  rem=$(trailing_silence_remain "$mp3")
  target=$(awk -v a="$base_dur" -v b="$rem" 'BEGIN{printf "%.3f\n", a+b}')
  encode_video_audio "$in_mp4" "$mp3" "$out_mp4" "$target"
}

two_mp3() {
  local in_mp4="$1"; local mp3_primary="$2"; local mp3_secondary="$3"; local offset_sec="$4"; local out_mp4="$5"
  local base_dur rem target offset_ms
  base_dur=$(dur "$mp3_primary")
  rem=$(trailing_silence_remain "$mp3_primary")
  target=$(awk -v a="$base_dur" -v b="$rem" 'BEGIN{printf "%.3f\n", a+b}')
  # offset in milliseconds for adelay
  offset_ms=$(awk -v s="$offset_sec" 'BEGIN{ if (s < 0) s=0; printf "%d", s*1000 }')
  ffmpeg -y \
    -i "$in_mp4" -i "$mp3_primary" -i "$mp3_secondary" \
    -filter_complex "[1:a]aformat=channel_layouts=stereo:sample_rates=48000,volume=1.0[a1];[2:a]adelay=${offset_ms}:all=1,aformat=channel_layouts=stereo:sample_rates=48000,volume=0.3[a2];[a1][a2]amix=inputs=2:duration=first:dropout_transition=0,loudnorm=I=-14:TP=-1.0:LRA=11[aout]" \
    -map 0:v:0 -map "[aout]" \
    -c:v libx264 -preset veryfast -crf 20 -r 30 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -t "$target" \
    "$out_mp4"
}

filter_script() {
  local in_mp4="$1"; local script="$2"; local voice="$3"; local key="$4"; local lines_count="$5"; local out_mp4="$6"; local halfkey="${7:-}"
  local v_base v_rem v_total k_total target
  v_base=$(dur "$voice")
  v_rem=$(trailing_silence_remain "$voice")
  v_total=$(awk -v a="$v_base" -v b="$v_rem" 'BEGIN{printf "%.3f\n", a+b}')
  # key duration = lines_count * 2 seconds
  if [ -n "$halfkey" ] && [ -f "$halfkey" ]; then
    k_total=$(awk -v n="$lines_count" 'BEGIN{printf "%.3f\n", n*2.0 + 2.0}')
  else
    k_total=$(awk -v n="$lines_count" 'BEGIN{printf "%.3f\n", n*2.0}')
  fi
  # target = max(v_total, k_total) + 1.000
  target=$(awk -v v="$v_total" -v k="$k_total" 'BEGIN{ve=v-1.0; m=(ve>k?ve:k); printf "%.3f\n", m+1.0}')
  encode_video_filter_script "$in_mp4" "$script" "$voice" "$key" "$lines_count" "$out_mp4" "$target" "$halfkey"
}

concat_v() {
  local out_mp4="$1"; shift
  local inputs=("$@")
  local n=${#inputs[@]}
  #if [ "$n" -lt 2 ]; then echo "concat requires at least 2 inputs" >&2; exit 1; fi
  # Validate files
  local f
  for f in "${inputs[@]}"; do
    if [ ! -f "$f" ]; then echo "concat input missing: $f" >&2; exit 1; fi
  done
  local fc=""
  local idx
  for idx in $(seq 0 $((n-1))); do
    fc+="[$idx:v]fps=30,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v$idx];"
    fc+="[$idx:a]aformat=channel_layouts=stereo:sample_rates=48000[a$idx];"
  done
  local concat_inputs=""
  for idx in $(seq 0 $((n-1))); do
    concat_inputs+="[v$idx][a$idx]"
  done
  fc+="${concat_inputs}concat=n=$n:v=1:a=1[vcat][acat];[acat]aformat=channel_layouts=stereo:sample_rates=48000,loudnorm=I=-14:TP=-1.0:LRA=11[aout]"
  # Build args array to avoid eval and preserve spaces
  local args=( -y )
  for f in "${inputs[@]}"; do args+=( -i "$f" ); done
  args+=( -filter_complex "$fc" -map "[vcat]" -map "[aout]" -c:v libx264 -preset veryfast -crf 20 -r 30 -pix_fmt yuv420p -c:a aac -b:a 192k "$out_mp4" )
  ffmpeg "${args[@]}"
}

# Create a silent video by freezing the last frame for a given number of seconds
freeze_last_frame() {
  local in_mp4="$1"; local seconds="$2"; local out_mp4="$3"
  if [ ! -f "$in_mp4" ]; then echo "input not found: $in_mp4" >&2; exit 1; fi
  if [ -z "${seconds}" ]; then echo "seconds is required" >&2; exit 1; fi
  # extract last frame (seek from end) to a temp image
  local tmpimg
rm -f /tmp/lastfram1.jpg  
touch /tmp/lastfram1.jpg  
  tmpimg=/tmp/lastfram1.jpg
  ffmpeg -y -sseof -0.05 -i "$in_mp4" -frames:v 1 -q:v 2 "$tmpimg"
  # build a constant video from the still image
  ffmpeg -y -loop 1 -i "$tmpimg" -t "$seconds" -r 30 \
    -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -an "$out_mp4"
  rm -f "$tmpimg"
}

running_code() {
  local in_mp4="$1"; local textfile="$2"; local x="$3"; local y="$4"; local seconds="$5"; local start_delay="$6"; local out_mp4="$7"; local sfx="${8:-}"; local explain="${9:-}"
  local fade=0.15
  # alpha over time, shifted by start_delay; fade-in only, then stay visible until end
  local alpha_expr="if(lt(t,${start_delay}),0, if(lt(t,${start_delay}+${fade}),(t-${start_delay})/${fade}, 1))"
  # Build drawtext options honoring env overrides
  local dt_opts="textfile='${textfile}':reload=1:expansion=none"
  if [ -n "${RC_FONTFILE:-}" ]; then
    dt_opts="fontfile='${RC_FONTFILE}':${dt_opts}"
  elif [ -n "${RC_FONT:-}" ]; then
    dt_opts="font='${RC_FONT}':${dt_opts}"
  else
    dt_opts="fontfile='/tmp/a/fonts/DejaVuSans.ttf':${dt_opts}"
  fi
  if [ -n "${RC_FONTSIZE:-}" ]; then
    dt_opts="fontsize=${RC_FONTSIZE}:${dt_opts}"
  else
    dt_opts="fontsize=60:${dt_opts}"
  fi
  if [ -n "${RC_FONTCOLOR:-}" ]; then
    dt_opts="fontcolor=${RC_FONTCOLOR}:${dt_opts}"
  else
    dt_opts="fontcolor=white:${dt_opts}"
  fi
  local dt="[0:v]drawtext=${dt_opts}:x=${x}:y=${y}:alpha='${alpha_expr}'[v]"

  # Determine target duration based on audio inputs: max(end times) + 1s
  # end time for explain starts at 0; end time for sfx is start_delay + dur(sfx)
  local target=""
  if { [ -n "$sfx" ] && [ -f "$sfx" ]; } || { [ -n "$explain" ] && [ -f "$explain" ]; }; then
    local end_audio=0 d
    if [ -n "$explain" ] && [ -f "$explain" ]; then
      d=$(dur "$explain")
      end_audio=$(awk -v a="$end_audio" -v b="$d" 'BEGIN{print (a>b)?a:b}')
    fi
    if [ -n "$sfx" ] && [ -f "$sfx" ]; then
      d=$(dur "$sfx")
      # sfx placed at start_delay
      local end_sfx
      end_sfx=$(awk -v s="$start_delay" -v d="$d" 'BEGIN{printf "%.3f", s + d}')
      end_audio=$(awk -v a="$end_audio" -v b="$end_sfx" 'BEGIN{print (a>b)?a:b}')
    fi
    target=$(awk -v a="$end_audio" 'BEGIN{printf "%.3f", a + 1.0}')
  fi

  if [ -n "$sfx" ] && [ -f "$sfx" ] && [ -n "$explain" ] && [ -f "$explain" ]; then
    local delay_ms
    delay_ms=$(awk -v d="$start_delay" 'BEGIN{printf "%d", d*1000}')
    ffmpeg -y -i "$in_mp4" -i "$sfx" -i "$explain" \
      -filter_complex "$dt;[1:a]adelay=${delay_ms}:all=1,asetpts=PTS-STARTPTS[sfx];[2:a]asetpts=PTS-STARTPTS[exp];[sfx][exp]amix=inputs=2:normalize=0[a]" \
      -map "[v]" -map "[a]" -t "$target" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k "$out_mp4"
  elif [ -n "$sfx" ] && [ -f "$sfx" ]; then
    local delay_ms
    delay_ms=$(awk -v d="$start_delay" 'BEGIN{printf "%d", d*1000}')
    ffmpeg -y -i "$in_mp4" -i "$sfx" \
      -filter_complex "$dt;[1:a]adelay=${delay_ms}:all=1,asetpts=PTS-STARTPTS[a]" \
      -map "[v]" -map "[a]" -t "$target" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k "$out_mp4"
  elif [ -n "$explain" ] && [ -f "$explain" ]; then
    ffmpeg -y -i "$in_mp4" -i "$explain" \
      -filter_complex "$dt;[1:a]asetpts=PTS-STARTPTS[a]" \
      -map "[v]" -map "[a]" -t "$target" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k "$out_mp4"
  else
    ffmpeg -y -i "$in_mp4" -filter_complex "$dt" -map "[v]" -an -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "$out_mp4"
  fi
}

overlay_pip_left_bottom() {
  local v1="$1"; local v2="$2"; local out="$3"; local pip_w="${4:-480}"; local margin="${5:-20}"
  ffmpeg -y \
    -i "$v1" -i "$v2" \
    -filter_complex "[1:v]scale=${pip_w}:-2,setsar=1[pip];[0:v][pip]overlay=${margin}:main_h-overlay_h-${margin}:format=auto[vout]" \
    -map "[vout]" -map 0:a? \
    -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "$out"
}

overlay_pip_right_bottom() {
  local v1="$1"; local v2="$2"; local out="$3"; local pip_w="${4:-480}"; local margin="${5:-20}"
  ffmpeg -y \
    -i "$v1" -i "$v2" \
    -filter_complex "[1:v]scale=${pip_w}:-2,setsar=1[pip];[0:v][pip]overlay=main_w-overlay_w-${margin}:main_h-overlay_h-${margin}:format=auto[vout]" \
    -map "[vout]" -map 0:a? \
    -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "$out"
}

cmd="$1"; shift || true
case "$cmd" in
  one_mp3)
    [ "$#" -eq 3 ] || usage
    one_mp3 "$1" "$2" "$3"
    ;;
  two_mp3)
    [ "$#" -eq 5 ] || usage
    two_mp3 "$1" "$2" "$3" "$4" "$5"
    ;;
  filter_script)
    if [ "$#" -eq 6 ]; then
      filter_script "$1" "$2" "$3" "$4" "$5" "$6"
    elif [ "$#" -eq 7 ]; then
      filter_script "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    else
      usage
    fi
    ;;
  concat)
    [ "$#" -ge 3 ] || usage
    out="$1"; shift
    concat_v "$out" "$@"
    ;;
  freeze_last_frame)
    [ "$#" -eq 3 ] || usage
    freeze_last_frame "$1" "$2" "$3"
    ;;
  running_code)
    if [ "$#" -eq 7 ]; then
      running_code "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    elif [ "$#" -eq 8 ]; then
      running_code "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
    elif [ "$#" -eq 9 ]; then
      running_code "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
    else
      usage
    fi
    ;;
  pip_left_bottom)
    [ "$#" -ge 3 ] || { echo "Usage: $0 pip_left_bottom <video1> <video2> <out.mp4> [pip_width] [margin]" >&2; exit 1; }
    overlay_pip_left_bottom "$1" "$2" "$3" "${4:-}" "${5:-}"
    ;;
  pip_right_bottom)
    [ "$#" -ge 3 ] || { echo "Usage: $0 pip_right_bottom <video1> <video2> <out.mp4> [pip_width] [margin]" >&2; exit 1; }
    overlay_pip_right_bottom "$1" "$2" "$3" "${4:-}" "${5:-}"
    ;;
  *)
    usage
    ;;
esac

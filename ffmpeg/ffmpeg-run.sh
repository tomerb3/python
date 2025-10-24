#!/bin/bash -x

set -euo pipefail

usage() {
  echo "Usage: $0 <command> [args...]" >&2
  echo "Commands:" >&2
  echo "  one_mp3 <in_mp4> <mp3> <out_mp4>" >&2
  echo "  two_mp3 <in_mp4> <mp3_primary> <mp3_secondary> <offset_seconds> <out_mp4>" >&2
  echo "  filter_script <in_mp4> <filters.txt> <mp3> <out_mp4>" >&2
  echo "  concat <out_mp4> <in1.mp4> [in2.mp4 ...]" >&2
  exit 1
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
  local a_file="$3"
  local out_mp4="$4"
  local duration="$5"
  ffmpeg -y \
    -i "$in_mp4" -i "$a_file" \
    -filter_complex_script "$script" -map "[outv]" -map 1:a:0 \
    -c:v libx264 -preset veryfast -crf 20 -r 30 -pix_fmt yuv420p \
    -filter:a "aformat=channel_layouts=stereo:sample_rates=48000,loudnorm=I=-14:TP=-1.0:LRA=11" \
    -c:a aac -b:a 192k \
    -t "$duration" \
    "$out_mp4"
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
  local in_mp4="$1"; local script="$2"; local mp3="$3"; local out_mp4="$4"
  local base_dur rem target
  base_dur=$(dur "$mp3")
  rem=$(trailing_silence_remain "$mp3")
  target=$(awk -v a="$base_dur" -v b="$rem" 'BEGIN{printf "%.3f\n", a+b}')
  encode_video_filter_script "$in_mp4" "$script" "$mp3" "$out_mp4" "$target"
}

concat_v() {
  local out_mp4="$1"; shift
  local inputs=("$@")
  local n=${#inputs[@]}
  if [ "$n" -lt 2 ]; then echo "concat requires at least 2 inputs" >&2; exit 1; fi
  local maps_v="" maps_a="" idx=0
  local fc=""
  for f in "${inputs[@]}"; do
    maps_v+=" -i \"$f\""
  done
  for idx in $(seq 0 $((n-1))); do
    fc+="[$idx:v]fps=30,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[v$idx];"
    fc+="[$idx:a]aformat=channel_layouts=stereo:sample_rates=48000[a$idx];"
  done
  local vlist="" alist=""
  for idx in $(seq 0 $((n-1))); do
    vlist+="[v$idx]"; alist+="[a$idx]"
  done
  fc+="$vlist$alistconcat=n=$n:v=1:a=1[vcat][acat];[acat]aformat=channel_layouts=stereo:sample_rates=48000,loudnorm=I=-14:TP=-1.0:LRA=11[aout]"
  eval ffmpeg -y $maps_v \
    -filter_complex "$fc" \
    -map "[vcat]" -map "[aout]" \
    -c:v libx264 -preset veryfast -crf 20 -r 30 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "$out_mp4"
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
    [ "$#" -eq 4 ] || usage
    filter_script "$1" "$2" "$3" "$4"
    ;;
  concat)
    [ "$#" -ge 3 ] || usage
    out="$1"; shift
    concat_v "$out" "$@"
    ;;
  *)
    usage
    ;;
esac

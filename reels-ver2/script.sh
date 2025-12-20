#!/bin/bash -x
 
 set -euo pipefail
 
 CANVAS_W=${CANVAS_W:-1080}
 CANVAS_H=${CANVAS_H:-1920}
 FPS=${FPS:-30}
 
 SLIDE_DUR_SEC=${SLIDE_DUR_SEC:-2.0}
 
 TOP_X=${TOP_X:-0}
 TOP_Y=${TOP_Y:-0}
 TOP_W=${TOP_W:-1080}
 TOP_H=${TOP_H:-260}
 
 MID_X=${MID_X:-0}
 MID_Y=${MID_Y:-260}
 MID_W=${MID_W:-1080}
 MID_H=${MID_H:-1400}
 
 BOT_X=${BOT_X:-0}
 BOT_Y=${BOT_Y:-1660}
 BOT_W=${BOT_W:-1080}
 BOT_H=${BOT_H:-260}
 
 require_cmd() {
   command -v "$1" >/dev/null 2>&1
 }
 
 wrap_words() {
   local n="$1"
   local s="$2"
   if [[ -z "${s}" ]]; then
     printf '%s' ""
     return 0
   fi
   printf '%s' "${s}" | awk -v n="${n}" '{
     for (i=1;i<=NF;i++) {
       printf "%s", $i
       if (i < NF) {
         if (i % n == 0) printf "\n"; else printf " "
       }
     }
     printf "\n"
   }'
 }
 
 render_slide1() {
   local png=""
   local out=""
   local font_file=""
   local dur="${SLIDE_DUR_SEC}"

   local mid_img=""
   local mid_img_w=0
   local mid_img_h=0
   local mid_img_x=""
   local mid_img_y=""

   local mid_y_offset=0
  
   local top_text=""
   local mid_text=""
   local bot_text=""
 
   local top_size=72
   local mid_size=96
   local bot_size=64
 
   local top_color="white"
   local mid_color="white"
   local bot_color="white"
 
   local top_outline_color="black"
   local mid_outline_color="black"
   local bot_outline_color="black"
 
   local top_outline=4
   local mid_outline=6
   local bot_outline=4
 
   local wrap_mode="words"
   local words_per_line=4
 
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --png) png="$2"; shift 2;;
       --out) out="$2"; shift 2;;
       --font) font_file="$2"; shift 2;;
       --dur) dur="$2"; shift 2;;

       --mid-img) mid_img="$2"; shift 2;;
       --mid-img-w) mid_img_w="$2"; shift 2;;
       --mid-img-h) mid_img_h="$2"; shift 2;;
       --mid-img-x) mid_img_x="$2"; shift 2;;
       --mid-img-y) mid_img_y="$2"; shift 2;;

       --mid-y-offset) mid_y_offset="$2"; shift 2;;
  
       --top-text) top_text="$2"; shift 2;;
       --mid-text) mid_text="$2"; shift 2;;
       --bot-text) bot_text="$2"; shift 2;;
 
       --top-size) top_size="$2"; shift 2;;
       --mid-size) mid_size="$2"; shift 2;;
       --bot-size) bot_size="$2"; shift 2;;
 
       --top-color) top_color="$2"; shift 2;;
       --mid-color) mid_color="$2"; shift 2;;
       --bot-color) bot_color="$2"; shift 2;;
 
       --top-outline-color) top_outline_color="$2"; shift 2;;
       --mid-outline-color) mid_outline_color="$2"; shift 2;;
       --bot-outline-color) bot_outline_color="$2"; shift 2;;
 
       --top-outline) top_outline="$2"; shift 2;;
       --mid-outline) mid_outline="$2"; shift 2;;
       --bot-outline) bot_outline="$2"; shift 2;;
 
       --wrap-mode) wrap_mode="$2"; shift 2;;
       --words-per-line) words_per_line="$2"; shift 2;;
 
       *) echo "unknown arg: $1" >&2; return 2;;
     esac
   done
 
   if [[ -z "${png}" || -z "${out}" ]]; then
     echo "render_slide1 requires --png and --out" >&2
     return 2
   fi
 
   if ! require_cmd ffmpeg; then
     echo "ffmpeg not found in PATH" >&2
     return 127
   fi
 
   if [[ -z "${font_file}" ]]; then
     font_file="${FONT_FILE:-}"
   fi
 
   if [[ -z "${font_file}" ]]; then
     echo "font file not provided (use --font or set FONT_FILE)" >&2
     return 2
   fi
 
   mkdir -p "$(dirname "${out}")"

   local tmp_dir
   tmp_dir="$(mktemp -d)"
   trap 'rm -rf "${tmp_dir}"' RETURN
 
   if [[ "${wrap_mode}" == "words" ]]; then
     top_text="$(wrap_words "${words_per_line}" "${top_text}")"
     mid_text="$(wrap_words "${words_per_line}" "${mid_text}")"
     bot_text="$(wrap_words "${words_per_line}" "${bot_text}")"
   fi
 
   local filters=""
   local tf
 
   if [[ -n "${top_text}" ]]; then
     tf="${tmp_dir}/top.txt"
     printf '%s' "${top_text}" >"${tf}"
     filters+="drawtext=fontfile='${font_file}':textfile='${tf}':reload=0:text_align=center:fontsize=${top_size}:fontcolor=${top_color}:bordercolor=${top_outline_color}:borderw=${top_outline}:x=${TOP_X}+(w-${TOP_W})/2+(${TOP_W}-text_w)/2:y=${TOP_Y}+(${TOP_H}-text_h)/2,"
   fi
 
   if [[ -n "${mid_text}" ]]; then
     tf="${tmp_dir}/mid.txt"
     printf '%s' "${mid_text}" >"${tf}"
     filters+="drawtext=fontfile='${font_file}':textfile='${tf}':reload=0:text_align=center:fontsize=${mid_size}:fontcolor=${mid_color}:bordercolor=${mid_outline_color}:borderw=${mid_outline}:x=${MID_X}+(w-${MID_W})/2+(${MID_W}-text_w)/2:y=${MID_Y}+(${MID_H}-text_h)/2+${mid_y_offset},"
   fi
 
   if [[ -n "${bot_text}" ]]; then
     tf="${tmp_dir}/bot.txt"
     printf '%s' "${bot_text}" >"${tf}"
     filters+="drawtext=fontfile='${font_file}':textfile='${tf}':reload=0:text_align=center:fontsize=${bot_size}:fontcolor=${bot_color}:bordercolor=${bot_outline_color}:borderw=${bot_outline}:x=${BOT_X}+(w-${BOT_W})/2+(${BOT_W}-text_w)/2:y=${BOT_Y}+(${BOT_H}-text_h)/2,"
   fi
 
   local text_filters
   text_filters="${filters%,}"

   local base_filter
   base_filter="scale=${CANVAS_W}:${CANVAS_H}:force_original_aspect_ratio=decrease,pad=${CANVAS_W}:${CANVAS_H}:(ow-iw)/2:(oh-ih)/2"

   if [[ -n "${mid_img}" ]]; then
     local imgw="${mid_img_w}"
     local imgh="${mid_img_h}"
     if [[ "${imgw}" -le 0 ]]; then imgw=400; fi
     if [[ "${imgh}" -le 0 ]]; then imgh=400; fi

     local ox
     local oy
     if [[ -n "${mid_img_x}" ]]; then
       ox="${mid_img_x}"
     else
       ox="${MID_X}+(${MID_W}-${imgw})/2"
     fi
     if [[ -n "${mid_img_y}" ]]; then
       oy="${mid_img_y}"
     else
       oy="${MID_Y}+(${MID_H}-${imgh})/2"
     fi

     local fc
     fc="[0:v]${base_filter}[base];[1:v]scale=${imgw}:${imgh}:force_original_aspect_ratio=decrease[img];[base][img]overlay=x=${ox}:y=${oy}:format=auto[ol];"
     if [[ -n "${text_filters}" ]]; then
       fc+="[ol]${text_filters}[vout]"
     else
       fc+="[ol]null[vout]"
     fi

     ffmpeg -y \
       -loop 1 -t "${dur}" -i "${png}" \
       -loop 1 -t "${dur}" -i "${mid_img}" \
       -filter_complex "${fc}" -map "[vout]" \
       -r "${FPS}" \
       -c:v libx264 -pix_fmt yuv420p \
       "${out}"
   else
     local vf
     if [[ -n "${text_filters}" ]]; then
       vf="${base_filter},${text_filters}"
     else
       vf="${base_filter}"
     fi

     ffmpeg -y \
       -loop 1 -t "${dur}" -i "${png}" \
       -vf "${vf}" \
       -r "${FPS}" \
       -c:v libx264 -pix_fmt yuv420p \
       "${out}"
   fi
 }
 
 if [[ "${1:-}" == "render_slide1" ]]; then
   shift
   render_slide1 "$@"
 fi

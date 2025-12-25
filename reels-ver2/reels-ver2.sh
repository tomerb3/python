#!/bin/bash -x
 
 echo ver6;sleep 2
 set -euo pipefail
 
base_folder="${base_folder:-/mnt/c/share/1}"
back_folder="${back_folder:-/mnt/c/share/1}"

 CANVAS_W=${CANVAS_W:-1080}
 CANVAS_H=${CANVAS_H:-1920}
 FPS=${FPS:-30}
 MM_DPI=${MM_DPI:-96}
 
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
   local mid_img_x_mm_offset=0
   local mid_img_y_mm_offset=0

   local mid_y_offset=0
  
   local top_text=""
   local mid_text=""
   local mid2_text=""
   local bot_text=""
 
   local top_size=72
   local mid_size=96
   local mid2_size=72
   local bot_size=64
 
   local top_color="white"
   local mid_color="white"
   local mid2_color="white"
   local bot_color="white"
 
   local top_outline_color="black"
   local mid_outline_color="black"
   local mid2_outline_color="black"
   local bot_outline_color="black"
 
   local top_outline=4
   local mid_outline=6
   local mid2_outline=4
   local bot_outline=4
 
   local mid2_y_offset=120
 
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

       --mid-img-x-mm-offset) mid_img_x_mm_offset="$2"; shift 2;;
       --mid-img-y-mm-offset) mid_img_y_mm_offset="$2"; shift 2;;

       --mid-y-offset) mid_y_offset="$2"; shift 2;;
  
       --top-text) top_text="$2"; shift 2;;
       --mid-text) mid_text="$2"; shift 2;;
       --mid2-text) mid2_text="$2"; shift 2;;
       --bot-text) bot_text="$2"; shift 2;;
 
       --top-size) top_size="$2"; shift 2;;
       --mid-size) mid_size="$2"; shift 2;;
       --mid2-size) mid2_size="$2"; shift 2;;
       --bot-size) bot_size="$2"; shift 2;;
 
       --top-color) top_color="$2"; shift 2;;
       --mid-color) mid_color="$2"; shift 2;;
       --mid2-color) mid2_color="$2"; shift 2;;
       --bot-color) bot_color="$2"; shift 2;;
       --top-font-color) top_color="$2"; shift 2;;
       --mid-font-color) mid_color="$2"; shift 2;;
       --mid2-font-color) mid2_color="$2"; shift 2;;
       --bot-font-color) bot_color="$2"; shift 2;;
 
       --top-outline-color) top_outline_color="$2"; shift 2;;
       --mid-outline-color) mid_outline_color="$2"; shift 2;;
       --mid2-outline-color) mid2_outline_color="$2"; shift 2;;
       --bot-outline-color) bot_outline_color="$2"; shift 2;;
 
       --top-outline) top_outline="$2"; shift 2;;
       --mid-outline) mid_outline="$2"; shift 2;;
       --mid2-outline) mid2_outline="$2"; shift 2;;
       --bot-outline) bot_outline="$2"; shift 2;;
 
       --wrap-mode) wrap_mode="$2"; shift 2;;
       --words-per-line) words_per_line="$2"; shift 2;;
       --words) words_per_line="$2"; shift 2;;

       --mid2-y-offset) mid2_y_offset="$2"; shift 2;;
 
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
   trap 'rm -rf "${tmp_dir:-}"' RETURN
 
   if [[ "${wrap_mode}" == "words" ]]; then
     top_text="$(wrap_words "${words_per_line}" "${top_text}")"
     mid_text="$(wrap_words "${words_per_line}" "${mid_text}")"
     mid2_text="$(wrap_words "${words_per_line}" "${mid2_text}")"
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

   if [[ -n "${mid2_text}" ]]; then
     tf="${tmp_dir}/mid2.txt"
     printf '%s' "${mid2_text}" >"${tf}"
     filters+="drawtext=fontfile='${font_file}':textfile='${tf}':reload=0:text_align=center:fontsize=${mid2_size}:fontcolor=${mid2_color}:bordercolor=${mid2_outline_color}:borderw=${mid2_outline}:x=${MID_X}+(w-${MID_W})/2+(${MID_W}-text_w)/2:y=${MID_Y}+(${MID_H}-text_h)/2+${mid2_y_offset},"
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

     local xoff_px
     local yoff_px
     xoff_px=$(awk -v mm="${mid_img_x_mm_offset}" -v dpi="${MM_DPI}" 'BEGIN{printf "%.6f", (mm*dpi/25.4)}')
     yoff_px=$(awk -v mm="${mid_img_y_mm_offset}" -v dpi="${MM_DPI}" 'BEGIN{printf "%.6f", (mm*dpi/25.4)}')
     ox="(${ox})+(${xoff_px})"
     oy="(${oy})+(${yoff_px})"

     local fc
     fc="[0:v]${base_filter}[base];[1:v]scale=${imgw}:${imgh}:force_original_aspect_ratio=decrease[img];[base][img]overlay=x=${ox}:y=${oy}:format=auto[ol];"
     if [[ -n "${text_filters}" ]]; then
       fc+="[ol]${text_filters}[vout]"
     else
       fc+="[ol]null[vout]"
     fi

     ffmpeg -y \
       -loop 1 -t "${dur}" -i "${back_folder}/${png}" \
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
       -loop 1 -t "${dur}" -i "${back_folder}/${png}" \
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



render_kind(){
  local kind="${1:-}"
  shift || true

  local png=""
  local out=""
  local text=""
  local text2=""
  local wpl=""
  local yoff=""
  local yoff2=""
  local img=""
  local imgw=""
  local imgh=""
  local size2=""

  local options=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --png) png="$2"; shift 2;;
      --out) out="$2"; shift 2;;
      --text) text="$2"; shift 2;;
      --text2) text2="$2"; shift 2;;
      --words) wpl="$2"; shift 2;;
      --yoff) yoff="$2"; shift 2;;
      --yoff2) yoff2="$2"; shift 2;;
      --size2) size2="$2"; shift 2;;
      --img) img="$2"; shift 2;;
      --imgw) imgw="$2"; shift 2;;
      --imgh) imgh="$2"; shift 2;;
      --) shift; break;;
      *) break;;
    esac
  done

  if [[ -z "${kind}" || -z "${png}" || -z "${out}" ]]; then
    echo "usage: render_kind <kind> --png <file> --out <file> [--text ..] [--img ..] [--] <extra render_slide1 args>" >&2
    return 2
  fi

  local img_path="${base_folder}/${img}"
  #if [[ -n "${img_path}" && "${img_path}" != /* ]]; then
   # img_path="${base_folder}/comfiui/${img_path}"
  #fi
echo img_path $img_path;sleep 3
  case "${kind}" in
    1)
      if [[ -z "${text}" ]]; then
        echo "kind=1 requires --text" >&2
        return 2
      fi
      options+=(--mid-text "${text}")
      if [[ -n "${wpl}" ]]; then options+=(--words-per-line "${wpl}"); fi
      if [[ -n "${yoff}" ]]; then options+=(--mid-y-offset "${yoff}"); fi
      ;;
    2)
      if [[ -z "${text}" ]]; then
        echo "kind=2 requires --text" >&2
        return 2
      fi
      if [[ -z "${img}" ]]; then
        echo "kind=2 requires --img" >&2
        return 2
      fi
      options+=(--mid-text "${text}" --mid-img "${img_path}")
      if [[ -n "${wpl}" ]]; then options+=(--words-per-line "${wpl}"); fi
      if [[ -n "${yoff}" ]]; then options+=(--mid-y-offset "${yoff}"); fi
      if [[ -n "${imgw}" ]]; then options+=(--mid-img-w "${imgw}"); fi
      if [[ -n "${imgh}" ]]; then options+=(--mid-img-h "${imgh}"); fi
      ;;
    3)
      if [[ -z "${img}" ]]; then
        echo "kind=3 requires --img" >&2
        return 2
      fi
      options+=(--mid-img "${img_path}")
      if [[ -n "${imgw}" ]]; then options+=(--mid-img-w "${imgw}"); fi
      if [[ -n "${imgh}" ]]; then options+=(--mid-img-h "${imgh}"); fi
      ;;
    4)
      if [[ -z "${text}" ]]; then
        echo "kind=4 requires --text" >&2
        return 2
      fi
      if [[ -z "${text2}" ]]; then
        echo "kind=4 requires --text2" >&2
        return 2
      fi
      options+=(--mid-text "${text}" --mid2-text "${text2}")
      if [[ -n "${wpl}" ]]; then options+=(--words-per-line "${wpl}"); fi
      if [[ -n "${yoff}" ]]; then options+=(--mid-y-offset "${yoff}"); fi
      if [[ -n "${yoff2}" ]]; then options+=(--mid2-y-offset "${yoff2}"); fi
      if [[ -n "${size2}" ]]; then options+=(--mid2-size "${size2}"); fi
      ;;
    *)
      echo "unknown kind: ${kind} (expected 1|2|3)" >&2
      return 2
      ;;
  esac

  options+=("$@")

  render_slide1 \
    --png "${png}" \
    --out "${base_folder}/${out}" \
    --font "${back_folder}/KGLoveMolly.ttf" \
    "${options[@]}"
}

 merge_master() {
   local slide1=""
   local slide2=""
   local slide3=""
   local slide4=""
   local slide5=""
   local audio=""
   local out=""

   local hold_sec=1.7
   local trans_sec=0.7

   local mid_x=${MID_X}
   local mid_y=${MID_Y}
   local mid_w=${MID_W}
   local mid_h=${MID_H}

   while [[ $# -gt 0 ]]; do
     case "$1" in
       --slide1) slide1="$2"; shift 2;;
       --slide2) slide2="$2"; shift 2;;
       --slide3) slide3="$2"; shift 2;;
       --slide4) slide4="$2"; shift 2;;
       --slide5) slide5="$2"; shift 2;;
       --audio) audio="$2"; shift 2;;
       --out) out="$2"; shift 2;;

       --hold) hold_sec="$2"; shift 2;;
       --trans) trans_sec="$2"; shift 2;;
       --mid-x) mid_x="$2"; shift 2;;
       --mid-y) mid_y="$2"; shift 2;;
       --mid-w) mid_w="$2"; shift 2;;
       --mid-h) mid_h="$2"; shift 2;;

       *) echo "unknown arg: $1" >&2; return 2;;
     esac
   done

   if [[ -z "${slide1}" || -z "${slide2}" || -z "${slide3}" || -z "${slide4}" || -z "${audio}" || -z "${out}" ]]; then
     echo "merge_master requires --slide1 --slide2 --slide3 --slide4 [--slide5] --audio --out" >&2
     return 2
   fi

   if ! require_cmd ffmpeg; then
     echo "ffmpeg not found in PATH" >&2
     return 127
   fi

   local seg
   seg=$(awk -v h="${hold_sec}" -v t="${trans_sec}" 'BEGIN{printf "%.6f", h+t}')

   if [[ -n "${slide5}" ]]; then
     local total
     total=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", (4*seg)+h}')

     local start1 start2 start3 start4
     local end1 end2 end3 end4
     start1=$(awk -v h="${hold_sec}" 'BEGIN{printf "%.6f", h}')
     end1=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", seg}')
     start2=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", seg+h}')
     end2=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", 2*seg}')
     start3=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", 2*seg+h}')
     end3=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", 3*seg}')
     start4=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", 3*seg+h}')
     end4=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", 4*seg}')

     local fc
     fc=""
     fc+="[0:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b1];"
     fc+="[1:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b2];"
     fc+="[2:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b3];"
     fc+="[3:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b4];"
     fc+="[4:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${hold_sec},setpts=PTS-STARTPTS[b5];"
     fc+="[b1][b2][b3][b4][b5]concat=n=5:v=1:a=0[base];"

     fc+="[0:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m1];"
     fc+="[1:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m2];"
     fc+="[m2]split=2[m2a][m2b];"
     fc+="[2:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m3];"
     fc+="[m3]split=2[m3a][m3b];"
     fc+="[3:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m4];"
     fc+="[m4]split=2[m4a][m4b];"
     fc+="[4:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m5];"

     fc+="[m1][m2a]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start1}/TB[t12];"
     fc+="[m2b][m3a]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start2}/TB[t23];"
     fc+="[m3b][m4a]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start3}/TB[t34];"
     fc+="[m4b][m5]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start4}/TB[t45];"

     fc+="[base][t12]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start1},${end1})'[v1];"
     fc+="[v1][t23]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start2},${end2})'[v2];"
     fc+="[v2][t34]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start3},${end3})'[v3];"
     fc+="[v3][t45]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start4},${end4})'[v];"

     fc+="[5:a]atrim=0:${total},asetpts=N/SR/TB[a]"

     ffmpeg -y \
       -i "${slide1}" -i "${slide2}" -i "${slide3}" -i "${slide4}" -i "${slide5}" -i "${audio}" \
       -filter_complex "${fc}" \
       -map "[v]" -map "[a]" \
       -r "${FPS}" -c:v libx264 -pix_fmt yuv420p \
       -c:a aac -shortest \
       "${out}"
   else
     local total
     total=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", (3*seg)+h}')

     local start1 start2 start3
     local end1 end2 end3
     start1=$(awk -v h="${hold_sec}" 'BEGIN{printf "%.6f", h}')
     end1=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", seg}')
     start2=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", seg+h}')
     end2=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", 2*seg}')
     start3=$(awk -v seg="${seg}" -v h="${hold_sec}" 'BEGIN{printf "%.6f", 2*seg+h}')
     end3=$(awk -v seg="${seg}" 'BEGIN{printf "%.6f", 3*seg}')

     local fc
     fc=""
     fc+="[0:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b1];"
     fc+="[1:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b2];"
     fc+="[2:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${seg},setpts=PTS-STARTPTS[b3];"
     fc+="[3:v]tpad=stop_mode=clone:stop_duration=10,trim=0:${hold_sec},setpts=PTS-STARTPTS[b4];"
     fc+="[b1][b2][b3][b4]concat=n=4:v=1:a=0[base];"

     fc+="[0:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m1];"
     fc+="[1:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m2];"
     fc+="[m2]split=2[m2a][m2b];"
     fc+="[2:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m3];"
     fc+="[m3]split=2[m3a][m3b];"
     fc+="[3:v]tpad=stop_mode=clone:stop_duration=10,crop=${mid_w}:${mid_h}:${mid_x}:${mid_y},trim=0:${seg},setpts=PTS-STARTPTS[m4];"

     fc+="[m1][m2a]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start1}/TB[t12];"
     fc+="[m2b][m3a]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start2}/TB[t23];"
     fc+="[m3b][m4]xfade=transition=slideleft:duration=${trans_sec}:offset=${hold_sec},trim=${hold_sec}:${seg},setpts=PTS-STARTPTS+${start3}/TB[t34];"

     fc+="[base][t12]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start1},${end1})'[v1];"
     fc+="[v1][t23]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start2},${end2})'[v2];"
     fc+="[v2][t34]overlay=x=${mid_x}:y=${mid_y}:enable='between(t,${start3},${end3})'[v];"

     fc+="[4:a]atrim=0:${total},asetpts=N/SR/TB[a]"

     ffmpeg -y \
       -i "${slide1}" -i "${slide2}" -i "${slide3}" -i "${slide4}" -i "${audio}" \
       -filter_complex "${fc}" \
       -map "[v]" -map "[a]" \
       -r "${FPS}" -c:v libx264 -pix_fmt yuv420p \
       -c:a aac -shortest \
       "${out}"
   fi
 }

 if [[ "${1:-}" == "merge_master" ]]; then
   shift
   merge_master "$@"
 fi

 if [[ "${1:-}" == "render_kind" ]]; then
   shift
   render_kind "$@"
 fi
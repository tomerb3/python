home="/home/baum/src/python/ffmpeg"
backup_folder="/home/baum/a"      # adjust
output_folder="/home/baum/a"      # adjust

summary=$(python /home/baum/src/python/TheoremExplainAgent.py \
  --input /home/baum/src/python/theorem.txt \
  --outdir "${output_folder}/files" \
  --x 100 --y 200 --line_height 66 \
  --start 0.4 --per_step 2.0 --fade_in 0.18 --fade_out 0.18)
eval "$summary"

"${home}/ffmpeg-run.sh" filter_script \
  "${backup_folder}/back-45.mp4" \
  "${output_folder}/files/filters.txt" \
  "${output_folder}/voice.mp3" \
  "${backup_folder}/key-2s.wav" \
  "$steps" \
  "${output_folder}/output-code.mp4"
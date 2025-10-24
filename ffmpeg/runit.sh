#!/bin/bash

output_folder=${output_folder:-/mnt/c/ffmpeg}
backup_folder=${backup_folder:-/tmp/a}
font_folder=${font_folder:-/tmp/a/fonts}


good(){
  # mp3 mp4 and key.mp3 
  ./ffmpeg-run.sh two_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/key-long1.mp3 3 ${output_folder}/before-and-keys.mp4
  # good testing 

}
code_run_verb(){
./ffmpeg-run.sh running_code \
  ${output_folder}/frozen-7s.mp4 \
  ${output_folder}/running_script.txt \
  50 1200 \
  3 \
  1.2 \
  ${output_folder}/running-code-demo.mp4 \
  '' \
 ${output_folder}/coderun.mp3 
}


#testing before section 
./ffmpeg-run.sh one_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4
# testing is good !




filter1() { 
 number_lines=5   
 ./ffmpeg-run.sh filter_script \
  ${backup_folder}/back-45.mp4 \
  ${output_folder}/files/filters.txt \
  ${output_folder}/code.mp3 \
  ${backup_folder}/key-2s.wav \
  $number_lines \
  ${output_folder}/output-code.mp4

}




export RC_FONTFILE="${font_folder}/BebasNeue-Regular.ttf"
export RC_FONTSIZE=66
#https://www.colorhexa.com/27d3f5
export RC_FONTCOLOR="#27d3f5"

#code 


# 1) Persist text from its start time (remove end-boundary gaps)
sed -E -i "s/enable='between\(t,([0-9.]+),([0-9.]+)\)'/enable='gte(t,\1)'/g" ${output_folder}/files/filters.txt

# 2) Make sure drawtext reloads the text files (prevents stale/bad frames)
sed -E -i "s/:enable='/:reload=1:enable='/g" ${output_folder}/files/filters.txt

filter1


./ffmpeg-run.sh freeze_last_frame ${output_folder}/output-code.mp4 60 ${output_folder}/frozen-code-60s.mp4

export RC_FONTFILE="${font_folder}/BebasNeue-Regular.ttf"
export RC_FONTSIZE=48
#https://www.colorhexa.com/27d3f5
export RC_FONTCOLOR="#ffcc00@0.95"


#export RC_FONT="DejaVu Sans"
#export RC_FONTSIZE=48
#export RC_FONTCOLOR="white"






code_run_vera(){
./ffmpeg-run.sh running_code \
  ${output_folder}/frozen-code-60s.mp4 \
  ${output_folder}/running_script.txt \
  50 1200 \
  3 \
  1.2 \
  ${output_folder}/running-code-demo.mp4 \
  ${backup_folder}/gong.mp3 \
 ${output_folder}/coderun.mp3 
}

# code run 
code_run_vera


./ffmpeg-run.sh freeze_last_frame ${output_folder}/running-code-demo.mp4 60 ${output_folder}/frozen-run-60s.mp4


#after 
./ffmpeg-run.sh one_mp3 ${output_folder}/frozen-run-60s.mp4 ${output_folder}/after.mp3 ${output_folder}/after.mp4


#check combine 
./ffmpeg-run.sh concat "${output_folder}/master-output-combine.mp4" "${output_folder}/before.mp4" "${output_folder}/output-code.mp4" ${output_folder}/running-code-demo.mp4 ${output_folder}/after.mp4
#good  testing

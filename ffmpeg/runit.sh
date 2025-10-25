#!/bin/bash -x

output_folder=${output_folder:-/mnt/c/ffmpeg}
backup_folder=${backup_folder:-/tmp/a}
font_folder=${font_folder:-/tmp/a/fonts}
if [ -e /home/node/tts/scripts/ffmpeg ];then 
  home=/home/node/tts/scripts/ffmpeg
else
  home=/home/baum/src/python/ffmpeg
fi

good(){
  # mp3 mp4 and key.mp3 
  ${home}/ffmpeg-run.sh two_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/key-long1.mp3 3 ${output_folder}/before-and-keys.mp4
  # good testing 

}
code_run_verb(){
${home}/ffmpeg-run.sh running_code \
  ${output_folder}/frozen-7s.mp4 \
  ${output_folder}/code_run.txt \
  50 1200 \
  3 \
  1.2 \
  ${output_folder}/running-code-demo.mp4 \
  '' \
 ${output_folder}/coderun.mp3 
}


#testing before section 
${home}/ffmpeg-run.sh one_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4
# testing is good !
#A1
#





filter1() { 


  num_lines=$(
    awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' ${output_folder}/code_show.txt
  )

 ${home}/ffmpeg-run.sh filter_script \
  ${backup_folder}/back-45.mp4 \
  ${output_folder}/files/filters.txt \
  ${output_folder}/code.mp3 \
  ${backup_folder}/key-2s.wav \
  $num_lines \
  ${output_folder}/output-code.mp4

}




export RC_FONTFILE="${font_folder}/DejaVuSans.ttf"
export RC_FONTSIZE=66
#https://www.colorhexa.com/27d3f5
export RC_FONTCOLOR="#27d3f5"

#code 


# 1) Persist text from its start time (remove end-boundary gaps)
sed -E -i "s/enable='between\(t,([0-9.]+),([0-9.]+)\)'/enable='gte(t,\1)'/g" ${output_folder}/files/filters.txt

# 2) Make sure drawtext reloads the text files (prevents stale/bad frames)
sed -E -i "s/:enable='/:reload=1:enable='/g" ${output_folder}/files/filters.txt




#A2
filter1




#A3
${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/output-code.mp4 60 ${output_folder}/frozen-code-60s.mp4


export RC_FONTFILE="${font_folder}/DejaVuSans.ttf"
export RC_FONTSIZE=48
#https://www.colorhexa.com/27d3f5
export RC_FONTCOLOR="#ffcc00@0.95"


#export RC_FONT="DejaVu Sans"
#export RC_FONTSIZE=48
#export RC_FONTCOLOR="white"






code_run_vera(){
${home}/ffmpeg-run.sh running_code \
  ${output_folder}/frozen-code-60s.mp4 \
  ${output_folder}/code_run.txt \
  50 1200 \
  3 \
  1.2 \
  ${output_folder}/running-code-demo.mp4 \
  ${backup_folder}/gong.mp3 \
 ${output_folder}/coderun.mp3 
}

# code run 
code_run_vera
#A4
#
#
#
#
#


${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/running-code-demo.mp4 60 ${output_folder}/frozen-run-60s.mp4


#after 
${home}/ffmpeg-run.sh one_mp3 ${output_folder}/frozen-run-60s.mp4 ${output_folder}/after.mp3 ${output_folder}/after.mp4


#check combine 
${home}/ffmpeg-run.sh concat "${output_folder}/master.mp4" "${output_folder}/before.mp4" "${output_folder}/output-code.mp4" ${output_folder}/running-code-demo.mp4 ${output_folder}/after.mp4
#good  testing

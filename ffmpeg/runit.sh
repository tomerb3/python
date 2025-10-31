#!/bin/bash -x

output_folder=${output_folder:-/mnt/c/ffmpeg}
backup_folder=${backup_folder:-/tmp/a}
font_folder=${font_folder:-/tmp/a/fonts}
back_before_video=${back_before_video:-none}
back_45_video=${back_45_video:-none}
if [ -e /home/node/tts/scripts/ffmpeg ];then 
  home=/home/node/tts/scripts/ffmpeg
else
  home=/home/baum/src/python/ffmpeg
fi

good(){
  # mp3 mp4 and key.mp3 
  ${home}/ffmpeg-run.sh two_mp3 ${output_folder}/back-for-before.mp4 ${output_folder}/before.mp3 ${output_folder}/key-long1.mp3 3 ${output_folder}/before-and-keys.mp4
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


filter1() { 
#  num_lines=$(
#    awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' ${output_folder}/code_show.txt
#  )

num_lines=$(( $(awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' "${output_folder}/code_show.txt")   ))
#num_lines=$(( $(awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' "${output_folder}/code_show.txt") + 1 ))

 # Build voice track with 1s silence tail
 ffmpeg -y \
   -i "${output_folder}/code.mp3" \
   -i "${backup_folder}/silence-3s.mp3" \
   -filter_complex "[0:a]aformat=channel_layouts=stereo:sample_rates=48000[a0];[1:a]aformat=channel_layouts=stereo:sample_rates=48000[a1];[a0][a1]concat=n=2:v=0:a=1[a]" \
   -map "[a]" "${output_folder}/code_with_tail.mp3"

 ${home}/ffmpeg-run.sh filter_script \
  ${output_folder}/${back_45_video} \
  ${output_folder}/files/filters.txt \
  ${output_folder}/code_with_tail.mp3 \
  ${backup_folder}/key-2s.wav \
  $num_lines \
  ${output_folder}/output-code.mp4
}

code_run_vera(){
${home}/ffmpeg-run.sh running_code \
  ${output_folder}/frozen-code-60s.mp4 \
  ${output_folder}/code_run_to_video.txt \
  50 1200 \
  3 \
  0.2 \
  ${output_folder}/running-code-demo.mp4 \
  ${backup_folder}/gong.mp3 \
 ${output_folder}/coderun.mp3 
}







_code(){
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
}



cmd_create_example(){

  if [ -e "${output_folder}/master.mp4" ];then 
     echo .




    else 
        
      #testing before section 
      
      ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/${back_before_video} ${output_folder}/before.mp3 ${output_folder}/before.mp4
      #${home}/ffmpeg-run.sh one_mp3 ${output_folder}/back-for-before.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4

      #${home}/ffmpeg-run.sh one_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4
      # testing is good !
      #A1
      
      if [ -e ${output_folder}/output-code.mp4 ];then 
        echo . 
      else 
        _code
      fi 
      
      #A3
      if [ -e ${output_folder}/frozen-code-60s.mp4 ];then 
        echo .
      else 
      ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/output-code.mp4 60 ${output_folder}/frozen-code-60s.mp4
      fi 


      export RC_FONTFILE="${font_folder}/DejaVuSans.ttf"
      export RC_FONTSIZE=48
      #https://www.colorhexa.com/27d3f5
      export RC_FONTCOLOR="#ffcc00@0.95"
      #export RC_FONT="DejaVu Sans"
      #export RC_FONTSIZE=48
      #export RC_FONTCOLOR="white"
      # code run 
      
      if [ -e ${output_folder}/running-code-demo.mp4 ];then 
        echo .
      else 
        code_run_vera
      fi 
      
      
      #A4
      if [ -e ${output_folder}/frozen-run-60s.mp4 ];then 
        echo .
      else 
      set -x 
        ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/running-code-demo.mp4 60 ${output_folder}/frozen-run-60s.mp4 > line143_frozen-run-60s.txt 2>&1
      fi 

      #after 
      if [ -e ${output_folder}/after.mp4 ];then 
        echo .
      else 
        ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/frozen-run-60s.mp4 ${output_folder}/after.mp3 ${output_folder}/after.mp4
      fi

      #check combine 
fi


if [ -e ${output_folder}/master.mp4 ];then 
  echo . 
else 
  ${home}/ffmpeg-run.sh concat "${output_folder}/master.mp4" "${output_folder}/before.mp4" "${output_folder}/output-code.mp4" ${output_folder}/running-code-demo.mp4 ${output_folder}/after.mp4
fi 

#good  testing
}










cmd_merge_examples_to_chapter(){
  cd /home/node/tts
  if [ -e chapter-${folder} ];then 
      echo . 
  else 
      folder=${folder:-none}
      #check=$(echo $folder |cut -d '-' -f2)
      rm -rf "chapter-${folder}" 
      ls -1tr |grep $folder |sort -n > list.txt
      mkdir -p chapter-${folder}
      LIST_FILE="list.txt"; mkdir -p chapter-${folder} 
      mapfile -t d < <(awk 'NF' "$LIST_FILE"); \
      chapter_name=( "chapter-${folder}/${folder}.mp4" )
      for x in "${d[@]}"; do chapter_name+=( "$x/master.mp4" ); done
     #  echo "${home}/ffmpeg-run.sh" concat "${chapter_name[@]}" 
     "${home}/ffmpeg-run.sh" concat "${chapter_name[@]}" 
  fi 
}


cmd_debug(){
  filter1
}

cmd_back_left_video(){
  cd $folder
  if [ -e back-for-before.mp4 ]; then
    rm -f org-back-for-before.mp4
    mv back-for-before.mp4 org-back-for-before.mp4
    from=$(cat /home/node/tts/background/from)
    target=$(cat /home/node/tts/background/target)
    check_files=$(ls -ltr /home/node/tts/background/$from/)
    if [ "$check_files" == "total 0" ]; then
      echo "no files in /home/node/tts/background/$from/ lets switch between from and target "
      cat /home/node/tts/background/from > /tmp/frombackup
      cat /home/node/tts/background/target > /home/node/tts/background/from
      cat /tmp/frombackup > /home/node/tts/background/target
      from=$(cat /home/node/tts/background/from)
      target=$(cat /home/node/tts/background/target)
    fi
     rand_file=$(ls -1tr -- /home/node/tts/background/$from/*.mp4 2>/dev/null | shuf -n1)
    /home/node/tts/scripts/ffmpeg/ffmpeg-run.sh pip_right_bottom org-back-for-before.mp4 $rand_file back-for-before.mp4 900 80 ||:
    mv $rand_file /home/node/tts/background/$target/
  fi 
}

cmd_$1

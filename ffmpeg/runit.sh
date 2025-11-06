#!/bin/bash -x

output_folder=${output_folder:-$HOME/a}
backup_folder=${backup_folder:-$HOME/a}
font_folder=${font_folder:-$HOME/a/fonts}
back_before_video=${back_before_video:-none}
back_45_video=${back_45_video:-back-45_m0.mp4}
if [ -e /home/node/tts/scripts/ffmpeg ];then 
  home=/home/node/tts/scripts/ffmpeg
else
  home=/home/baum/src/python/ffmpeg
  rm -rf /home/baum/src/python/ffmpeg/files
  cp -a $HOME/a/files /home/baum/src/python/ffmpeg/
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

    #num_lines=$(( $(awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' "${output_folder}/code_show.txt")   ))
    #num_lines=$(( $(awk '{gsub(/[^[:alnum:]_]+/," ")} NF>=3{c++} (NF==1||NF==2){s=1} END{print c + (s?1:0)}' "${output_folder}/code_show.txt") + 1 ))

    # Build voice track with 1s silence tail
    #ffmpeg -y \
      # -i "${output_folder}/code.mp3" \
      # -i "${backup_folder}/silence-3s.mp3" \
      # -filter_complex "[0:a]aformat=channel_layouts=stereo:sample_rates=48000[a0];[1:a]aformat=channel_layouts=stereo:sample_rates=48000[a1];[a0][a1]concat=n=2:v=0:a=1[a]" \
      # -map "[a]" "${output_folder}/code_with_tail.mp3"

    #${home}/ffmpeg-run.sh filter_script \
    # ${output_folder}/${back_45_video} \
    # ${output_folder}/files/filters.txt \
    # ${output_folder}/code.mp3 \
    # ${backup_folder}/key-2s.wav \
    # $num_lines \
    # ${output_folder}/output-code.mp4
    echo "new555 start"
    words_for_each_loop=2
    not_empty_lines=$(grep -cve '^[[:space:]]*$' ${output_folder}/code_show.txt)
    calc=$((2 * $not_empty_lines - 1))
    words_in_code=$(( $(wc -w < ${output_folder}/code_show.txt) + $calc ))
    echo "${words_in_code}" > code_to_show_words_for_click_auto
    code_to_show_words_for_click=$(cat ${output_folder}/code_to_show_words_for_click)
    if [ ${code_to_show_words_for_click} -eq 0 ];then 
      echo .
    else 
      words_in_code=${code_to_show_words_for_click}
    fi 

    sleep 1
    ${home}/ffmpeg-run.sh filter_script_v2 ${output_folder}/${back_45_video} ${output_folder}/files/filters.txt ${output_folder}/code.mp3 ${backup_folder}/keys_dir $words_in_code $words_for_each_loop ${output_folder}/output-code.mp4
    #kind=loops in_file=output-code.mp4 output_file=output-code-v2.mp4 folder=${output_folder} tool=/home/node/tts/scripts/movement back=${output_folder} /home/node/tts/scripts/movement/run-shape.sh
    echo "new555 end" 
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

# type code - need the clicks sound to be 100% with the text animation !!!!!!!!!!
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
        
#BEFORE
      ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/${back_before_video} ${output_folder}/before.mp3 ${output_folder}/before.mp4
      #${home}/ffmpeg-run.sh one_mp3 ${output_folder}/back-for-before.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4

      #${home}/ffmpeg-run.sh one_mp3 ${backup_folder}/back-45.mp4 ${output_folder}/before.mp3 ${output_folder}/before.mp4
      # testing is good !
      #A1
      
      if [ -e ${output_folder}/output-code.mp4 ];then 
        echo . 
      else 
#CODE
        _code
      fi 
      
      #A3
      if [ -e ${output_folder}/frozen-code-60s.mp4 ];then 
        echo .
      else 
#CODE FREEZE
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
#RUN CODE
        code_run_vera
      fi 
      
      
      #A4
      if [ -e ${output_folder}/frozen-run-60s.mp4 ];then 
        echo .
      else 
#RUN CODE FREEZE
        ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/running-code-demo.mp4 60 ${output_folder}/frozen-run-60s.mp4
      fi 


      if [ -e ${output_folder}/after.mp4 ];then 
        echo .
      else 
       #check seconds for frozen-run-60s.mp4

       s=$(basename -- "${output_folder}" |cut -d '-' -f1)
       if [ "${s%%#*}" -eq "${s##*#}" ]; then 
         echo "equal"
         seconds=$( ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${output_folder}/after.mp3  |cut -d "." -f1 ) 
         seconds2=$(( $seconds - 4 ))
         start=${seconds2} kind=scanlines in_file=frozen-run-60s.mp4 output_file=frozen-run-60s-v2.mp4 folder=${output_folder} tool=/home/node/tts/scripts/movement back=${output_folder} /home/node/tts/scripts/movement/run-shape.sh
         ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/frozen-run-60s-v2.mp4 ${output_folder}/after.mp3 ${output_folder}/after.mp4
       else 
#AFTER
         echo "not equal"
         ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/frozen-run-60s.mp4 ${output_folder}/after.mp3 ${output_folder}/after.mp4
       fi


        

      fi

fi


  if [ -e ${output_folder}/master.mp4 ];then 
    echo . 
  else 
#MASTER
    ${home}/ffmpeg-run.sh concat "${output_folder}/master.mp4" "${output_folder}/before.mp4" "${output_folder}/output-code.mp4" ${output_folder}/running-code-demo.mp4 ${output_folder}/after.mp4
  fi 


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
 # filter1

rm -f ${output_folder}/a.mp4 
   ${home}/ffmpeg-run.sh filter_script_v3 ${output_folder}/${back_45_video} ${output_folder}/files/filters.txt ${output_folder}/a.mp4 
cp -a $HOME/a/a.mp4 /mnt/c/ffmpeg/c/

 
  
cd 
cd a 

N=$(ffprobe -v error -select_streams v:0 -count_frames \
     -show_entries stream=nb_read_frames -of default=nw=1:nk=1 a.mp4)
DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 a.mp4 | awk '{printf "%.6f\n",$1}')

ffmpeg -y -i b.mp4 \
  -vf "trim=end_frame=${N},setpts=PTS-STARTPTS" \
  -af "atrim=0:${DUR},asetpts=PTS-STARTPTS" \
  -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 192k \
  b_trim.mp4
 cp -a $HOME/a/b_trim.mp4 /mnt/c/ffmpeg/c/



  ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/b_trim.mp4 60 ${output_folder}/frozen-code-60s.mp4


D=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${output_folder}/frozen-code-60s.mp4" | awk '{printf "%.6f\n",$1}')
ffmpeg -y -i "${output_folder}/frozen-code-60s.mp4" \
  -f lavfi -t "$D" -i anullsrc=r=48000:cl=stereo \
  -shortest -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k \
  "${output_folder}/frozen-code-60s-a.mp4"
 cp -a $HOME/a/frozen-code-60s-a.mp4 /mnt/c/ffmpeg/c/

ffprobe $HOME/a/frozen-code-60s-a.mp4 > /mnt/c/ffmpeg/c/frozen-code-60s-a.mp4.txt  2>&1
ffprobe $HOME/a/b_trim.mp4 > /mnt/c/ffmpeg/c/b_trim.mp4.txt  2>&1

  ${home}/ffmpeg-run.sh concat "${output_folder}/master.mp4" "${output_folder}/b_trim.mp4" "${output_folder}/frozen-code-60s-a.mp4" > /mnt/c/ffmpeg/c/concat-master.log 2>&1

#${home}/ffmpeg-run.sh filter_script_v4 ${output_folder}/output-code.mp4 ${output_folder}/keys_dir ${output_folder}/1.mp4 30

 cp -a $HOME/a/master.mp4 /mnt/c/ffmpeg/c/
  #cp -a $HOME/a/output-code.mp4 /mnt/c/ffmpeg/c/

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

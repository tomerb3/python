#!/bin/bash -x

export ver=ver15
echo $ver;sleep 3
# how to debug in n8n terminal 
#   create_video_right_to_run


#  cd /home/node/tts/$folder
# folder=name1 
# back_45_video=back11.mp4 back_before_video=back222.mp4 output_folder=/home/node/tts/$folder backup_folder=/home/node/tts/background font_folder=/home/node/tts/fonts/ /home/node/tts/scripts/ffmpeg/runit.sh create_video_right_to_run



# info base example-id
#cd /home/node/tts/; ls -1tr |grep mhzc19hv_fzd1m7hb |while read d;do echo "== $d ==";ls -1 "$d"/master.mp4 2>/dev/null ; ls -1 "$d"/mhzc19hv_fzd1m7hb.mp4 2>/dev/null ;echo "===";done


output_folder=${output_folder:-$HOME/a}
backup_folder=${backup_folder:-$HOME/a}
font_folder=${font_folder:-$HOME/a/fonts}
back_before_video=${back_before_video:-none}
back_45_video=${back_45_video:-back-45_m0.mp4}
if [ -e /home/node/tts/scripts/ffmpeg ];then 
  home=/home/node/tts/scripts/ffmpeg
else
  home=/home/baum/src/python/ffmpeg
#  cp -a /mnt/c/share/d/* $HOME/a/
#  rm -rf /home/baum/src/python/ffmpeg/files
#  cp -a $HOME/a/files /home/baum/src/python/ffmpeg/
fi
 # home=/data

cd ${output_folder}/
touch $ver

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

cmd_filter1_v2_debug(){

 echo "only code_a line39 from runit.sh cmd_filter1_v2_debug   call  ffmpeg-run.sh filter_script_v3"
 sleep 3
 #1. create code_a with text code effect. trim it at the second effect done   - code_a.mp4 
     /app/ffmpeg-run.sh filter_script_v3 ${output_folder}/${back_45_video} ${output_folder}/files/filters.txt ${output_folder}/code_a.mp4 
     cd ${output_folder}
     pwd
     N=$(ffprobe -v error -select_streams v:0 -count_frames \
       -show_entries stream=nb_read_frames -of default=nw=1:nk=1 code_a.mp4)
       echo $N 
}

############################################# cmd_filter1_v2

cmd_filter1_v2(){
 echo "line39 from runit.sh cmd_filter1_v2   call  ffmpeg-run.sh filter_script_v3"
#1. create code_a with text code effect. trim it at the second effect done   - code_a.mp4 
     /app/ffmpeg-run.sh filter_script_v3 ${output_folder}/${back_45_video} ${output_folder}/files/filters.txt ${output_folder}/code_a.mp4 
     cd ${output_folder}
     pwd
     N=$(ffprobe -v error -select_streams v:0 -count_frames \
       -show_entries stream=nb_read_frames -of default=nw=1:nk=1 code_a.mp4)
       echo $N 
#2 add key clicks random   call it code_b.mp4 
     /app/ffmpeg-run.sh filter_script_v4 ${output_folder}/code_a.mp4 ${backup_folder}/keys_dir ${output_folder}/code_b.mp4 0.5
#3 freeze last frame to 60 second video   code_c_freeze.mp4
     /app/ffmpeg-run.sh freeze_last_frame ${output_folder}/code_b.mp4 60 ${output_folder}/code_c_freeze.mp4
#4 merge code effeect with clicks with frozen 60 sec together - call it       frozen-code-60s-a.mp4
    D=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${output_folder}/code_c_freeze.mp4" | awk '{printf "%.6f\n",$1}')
    ffmpeg -y -i "${output_folder}/code_c_freeze.mp4" \
    -f lavfi -t "$D" -i anullsrc=r=48000:cl=stereo \
    -shortest -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k \
     "${output_folder}/frozen-code-60s-a.mp4"
  sleep 2
  #5 concat and create code_d.mp4
  /app/ffmpeg-run.sh concat "${output_folder}/code_d.mp4" "${output_folder}/code_b.mp4" "${output_folder}/frozen-code-60s-a.mp4" 
    sleep 2
  cd "${output_folder}"
  MP3="code.mp3"
  MP4="code_b.mp4"
  OUT="durations.txt"
 {
   echo "mp3_seconds=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$MP3" | awk '{printf "%.3f\n",$1}')"
   echo "mp4_seconds=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$MP4" | awk '{printf "%.3f\n",$1}')"
 } > "$OUT"
max=$(cat durations.txt  |cut -d "=" -f2 |sort -n |tail -1 |cut -d "." -f1)
mp3=$(cat durations.txt  |grep mp3 |cut -d "=" -f2 |cut -d "." -f1)
if [ $max -gt $mp3 ]; then
  delta=$(( $max - $mp3 ))
else
  delta=0
fi
seconds1=$(( 4 + $delta ))
echo seconds to wait after mp3 voice end $seconds1
  #6 add voice sound  output_code.mp4     put 5 seconds after code talk  need to check if this work                                                                                      seconds after silense 
  /app/ffmpeg-run.sh mix_talk ${output_folder}/code_d.mp4 ${output_folder}/code.mp3 ${output_folder}/output-code.mp4 1.8 0.5 $seconds1
  sleep 2
}
########################################################  end of cmd_filter1_v2 









########################################################
code_run_vera(){
${home}/ffmpeg-run.sh running_code \
  ${output_folder}/frozen-code-60s-a.mp4 \
  ${output_folder}/code_run_to_video.txt \
  50 1200 \
  3 \
  0.2 \
  ${output_folder}/running-code-demo.mp4 \
  ${backup_folder}/gong.mp3 \
  ${output_folder}/coderun.mp3 
}
########################################################  end of code_run_vera

########################################################
# type code - need the clicks sound to be 100% with the text animation !!!!!!!!!!
_code(){
      export RC_FONTFILE="${font_folder}/DejaVuSans.ttf"
      export RC_FONTSIZE=66
      #https://www.colorhexa.com/27d3f5
      export RC_FONTCOLOR="#27d3f5"
      #code 
      #A2
      filter1
      # 1) Persist text from its start time (remove end-boundary gaps)
      sed -E -i "s/enable='between\(t,([0-9.]+),([0-9.]+)\)'/enable='gte(t,\1)'/g" ${output_folder}/files/filters.txt
      # 2) Make sure drawtext reloads the text files (prevents stale/bad frames)
      sed -E -i "s/:enable='/:reload=1:enable='/g" ${output_folder}/files/filters.txt
}
########################################################  end of _code

########################################################
_code_v2(){
  sed -i.bak 's#/home/node/tts/fonts/#/data/fonts/#g' ${output_folder}/files/filters.txt
  sed -i.bak "s#'files/step#'/data/files/step#g" ${output_folder}/files/filters.txt
  sed -i.bak "/step_9999.txt/d" ${output_folder}/files/filters.txt
  #rm -f ${output_folder}/output_code.mp4
  docker run --rm \
  --user "$(id -u)":"$(id -g)" \
  -e HOME=/tmp -e XDG_CACHE_HOME=/tmp/.cache \
  -v ${home}:/app \
  -v ${output_folder}:/data \
  -v ${font_folder}:/data/fonts \
  -v ${backup_folder}:/data/back \
  -e output_folder=/data \
  -e backup_folder=/data/back \
  -e font_folder=/data/fonts \
  ffmpeg-scripts:latest \
    bash -lc 'mkdir -p /tmp/.cache/fontconfig && bash -x /app/runit.sh filter1_v2'
}
########################################################  end of _code_v2

########################################################
cmd_debug_code_wsl(){
  echo home $home 
  sleep 1
  output_folder=$HOME/a
  backup_folder=$HOME/a/back
  font_folder=$HOME/a/fonts
  sed -i.bak 's#/home/node/tts/fonts/#/data/fonts/#g' ${output_folder}/files/filters.txt
  sed -i.bak "s#'files/step#'/data/files/step#g" ${output_folder}/files/filters.txt
  #rm -f ${output_folder}/output_code.mp4
  docker run -ti --rm \
  --user "$(id -u)":"$(id -g)" \
  -e HOME=/tmp -e XDG_CACHE_HOME=/tmp/.cache \
  -v ${home}:/app \
  -v ${output_folder}:/data \
  -v ${font_folder}:/data/fonts \
  -v ${backup_folder}:/data/back \
  -e output_folder=/data \
  -e backup_folder=/data/back \
  -e font_folder=/data/fonts \
  ffmpeg-scripts:latest \
    bash -lc 'mkdir -p /tmp/.cache/fontconfig && bash -x /app/runit.sh filter1_v2_debug'
}
########################################################  end of cmd_debug_code_wsl

########################################################
cmd_create_video_right_to_run(){

# 1. create the picture form comfiui in wsl2 - 
    mkdir -p ${output_folder}/out
    cd ${output_folder}/out
    pwd
    cp -a /home/node/tts/scripts/text-to-image-comfi/* . 
    docker run --rm -v ${output_folder}/out:/app comfi1-3.10 python comfi.py --prompt "a man with red hair stand in new york with blonde hair"
    file=$(ls -1tr *.png |tail -1)
    echo $file 
      rm -f out.png 
      cp -a $file out.png

      if [ -e out.mp4 ];then 
         echo .line215 
      else 
         #lets create out.m4 
         all=no /home/node/tts/scripts/n8n/video.sh "no-need" ${output_folder} "no"
      fi
      
      if [ -e ${output_folder}/frozen-code-60s-a.with-side.mp4 ];then 
        echo ...line222
      else 
          # Offsets, appearance delay, and fade timing
          X=150        # pixels from the right edge
          Y=150        # pixels from the top
          Z=3         # seconds after start to show side video
          K=10        # seconds on the main timeline to start fading out
          D=1         # fade-out duration in seconds
          base="${output_folder}/frozen-code-60s-a.mp4"
          side="${output_folder}/out/out.mp4"
          out="${output_folder}/frozen-code-60s-a.with-side.mp4"
          # Compute fade start relative to the overlay stream’s timeline (overlay starts at Z)
          ST=$(( K - Z ))
          if [ $ST -lt 0 ]; then ST=0; fi
          # Overlay side video at right side with offsets X,Y; enable after Z seconds
          # Apply alpha fade-out on the overlay stream starting at ST seconds for D seconds
        ffmpeg -y \
          -i "$base" -i "$side" \
          -filter_complex "[1:v]setpts=PTS-STARTPTS,format=rgba,fade=t=out:st=${ST}:d=${D}:alpha=1[v1];[0:v][v1]overlay=x='main_w-overlay_w-${X}':y='${Y}':enable='between(t,${Z},${K}+${D})'[vout]" \
          -map "[vout]" -map 0:a? \
          -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p -c:a copy \
          "$out"
          baserun="${output_folder}/frozen-code-60s-a.with-side.mp4"
      fi
    
   

}
########################################################  end of cmd_create_video_right_to_run









########################################################################################################### example
########################################################################################################### example
########################################################################################################### example
########################################################################################################### example
########################################################################################################### example
cmd_create_example(){

  if [ -e "${output_folder}/master.mp4" ];then 
     echo .188
    else 
#BEFORE ##################################################################
   # put in right area the out/out/out.mp4 video  in the before section 
     # need to stop this -   the file out/out/out.mp4 is created before  !!!!!!!!!!!!!!!!!!!!!
   if [ -e ${output_folder}/pic-before/out/out.png ];then 
      echo .200
   else
     echo .202
     places=("museum" "church" "pool" "sea" "garden" "forest" "mountain" "desert" "city" "village" "new york" "las vegas" "tokyo" "beach")
     colors=("blue" "red" "yellow" "purple" "orange" "pink" "black" "white" "gold" "silver")
     #backpics=("back-shrink1.mp4" "back-shrink2.mp4" "back-shrink3.mp4" "back-shrink4.mp4" "back-shrink5.mp4")
    eqps=("laptop" "pc monitor" "tv")
    place="${places[$RANDOM % ${#places[@]}]}"
    color="${colors[$RANDOM % ${#colors[@]}]}"
    eqp="${eqps[$RANDOM % ${#eqps[@]}]}"
    #backpic="${backpics[$RANDOM % ${#backpics[@]}]}"
    PROMPT="$color $eqp in a $place"
    mkdir -p ${output_folder}/pic-before
    mkdir -p ${output_folder}/pic-before/out
    cd ${output_folder}/pic-before/out
    HOST="192.168.0.128:7860"
    OUTFILE="out.png"
     path1=$(pwd)
      curl -s -X POST "http://$HOST/sdapi/v1/txt2img" \
        -H "Content-Type: application/json" \
        -d "{
           \"prompt\": \"$PROMPT\",
             \"steps\": 20,
              \"width\": 512,
               \"height\": 512
              }" | \
           jq -r '.images[0]' | base64 -d > "$OUTFILE"
        echo "Saved image to $OUTFILE"

        num=$(basename -- "${output_folder}" |cut -d '-' -f1 |cut -d "#" -f1)
        colors=("blue" "red" "black" "purple")
        colorfont="${colors[$RANDOM % ${#colors[@]}]}"

        ffmpeg -i out.png -vf \
         "drawtext=text=Example $num:\
         fontfile=/home/node/tts/fonts/Peace-Sanst.ttf:\
         fontcolor=$colorfont:\
         fontsize=50:\
         bordercolor=white:\
         borderw=3:\
          x=120:y=250" \
             out2.png -y
         rm -f 1out.png 
         mv out.png 1out.png 
         mv out2.png out.png

        #cp -a output2.jpg /mnt/c/ffmpeg/

     fi 
      if [ -e ${output_folder}/v-${back_before_video} ];then 
        echo .233
      else 
      echo .235
       # 1. compilie   ${output_folder}/pic-before/out/out.mp4
          cd ${output_folder}/pic-before
          if [ -e out/out.mp4 ];then 
          echo . 
          else 
            all=no /home/node/tts/scripts/n8n/video.sh "no-need" ${output_folder}/pic-before "no"
            sleep 30
          fi 
       #2 merge it with v-${back_before_video}
          Offsets, appearance delay, and fade timing
          X=150        # pixels from the right edge
          Y=150        # pixels from the top
          Z=1         # seconds after start to show side video
          K=13        # seconds on the main timeline to start fading out
          D=2         # fade-out duration in seconds
          base="${output_folder}/${back_before_video}"
          side="${output_folder}/pic-before/out/out.mp4"
          out="${output_folder}/v-${back_before_video}"
          ST=$(( K - Z ))
          if [ $ST -lt 0 ]; then ST=0; fi
          ffmpeg -y \
            -i "$base" -i "$side" \
            -filter_complex "[1:v]setpts=PTS-STARTPTS,format=rgba,fade=t=out:st=${ST}:d=${D}:alpha=1[v1];[0:v][v1]overlay=x='main_w-overlay_w-${X}':y='${Y}':enable='between(t,${Z},${K}+${D})'[vout]" \
            -map "[vout]" -map 0:a? \
            -c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p -c:a copy \
            "$out"
            baserun="${output_folder}/v-${back_before_video}"
      fi
      sleep 10
      ${home}/ffmpeg-run.sh one_mp3 ${output_folder}/v-${back_before_video} ${output_folder}/before.mp3 ${output_folder}/before.mp4
      #A1
    ##################################################################


      if [ -e ${output_folder}/output-code.mp4 ];then 
        echo . 
      else 
#CODE
     #   _code > ${output_folder}/code_log.log 2>&1
     _code_v2
      fi 
      
      #A3
#      if [ -e ${output_folder}/frozen-code-60s.mp4 ];then 
 #       echo .
  #    else 
#CODE FREEZE
   #     ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/output-code.mp4 60 ${output_folder}/frozen-code-60s.mp4
    #  fi 


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
      echo . > ${output_folder}/running-code-demo-start-304.txt
      #RUN CODE
        #code_run_vera

   
   # if side video exit - lets add it to the right side of ${output_folder}/frozen-code-60s-a.mp4  so we will show it in after code run section 
   baserun="${output_folder}/frozen-code-60s-a.mp4"
     # the file out/out.mp4 is created in the left side of project2-p3 exec node with video.sh script in n8n folder 
      
     # make frozen-code-60s-a.with-side.mp4  and set it in ${baserun}
     cmd_create_video_right_to_run

   bash -x /home/node/tts/scripts/ffmpeg/ffmpeg-run.sh running_code \
  ${baserun} \
  ${output_folder}/code_run_to_video.txt \
  50 1200 3 0.2 \
  ${output_folder}/running-code-demo.mp4 \
  ${backup_folder}/gong.mp3 \
  ${output_folder}/coderun.mp3

      fi       
      
      #A4
      if [ -e ${output_folder}/frozen-run-60s.mp4 ];then 
        echo .
      else 
#RUN CODE FREEZE
   #  echo . > ${output_folder}/frozen0run-60s-start-325.txt
        ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/running-code-demo.mp4 60 ${output_folder}/frozen-run-60s.mp4
      fi 


      if [ -e ${output_folder}/after.mp4 ];then 
        echo .
      else 
   #   echo . > ${output_folder}/after-started-333.txt
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
  echo . > ${output_folder}/master-started-360.txt
#MASTER
    ${home}/ffmpeg-run.sh concat_v2 "${output_folder}/master.mp4" "${output_folder}/before.mp4" "${output_folder}/output-code.mp4" ${output_folder}/running-code-demo.mp4 ${output_folder}/after.mp4
  fi 
}
########################################################################################################### example
########################################################################################################### example
########################################################################################################### example
########################################################################################################### example
########################################################################################################### example







_merge1(){
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
}

cmd_merge_examples_to_chapter(){
  cd /home/node/tts
  if [ -e chapter-${folder} ];then 
      echo . 
      if [ $(ls -ltr chapter-${folder}/*.mp4 |wc -l) -gt 0 ];then 
        echo "no need  "
      else 
        _merge1
      fi 

  else 
     _merge1
  fi 
}



cmd_debug(){
rm -f ${output_folder}/a.mp4 
   ${home}/ffmpeg-run.sh filter_script_v3 ${output_folder}/${back_45_video} ${output_folder}/files/filters.txt ${output_folder}/a.mp4 
   cd ${output_folder}
   N=$(ffprobe -v error -select_streams v:0 -count_frames \
     -show_entries stream=nb_read_frames -of default=nw=1:nk=1 a.mp4)
    DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 a.mp4 | awk '{printf "%.6f\n",$1}')
    ffmpeg -y -i a.mp4 \
  -vf "trim=end_frame=${N},setpts=PTS-STARTPTS" \
  -af "atrim=0:${DUR},asetpts=PTS-STARTPTS" \
  -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 192k \
  b_trim.mp4

  ${home}/ffmpeg-run.sh freeze_last_frame ${output_folder}/b_trim.mp4 60 ${output_folder}/frozen-code-60s.mp4
D=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${output_folder}/frozen-code-60s.mp4" | awk '{printf "%.6f\n",$1}')
ffmpeg -y -i "${output_folder}/frozen-code-60s.mp4" \
  -f lavfi -t "$D" -i anullsrc=r=48000:cl=stereo \
  -shortest -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k \
  "${output_folder}/frozen-code-60s-a.mp4"
${home}/ffmpeg-run.sh concat "${output_folder}/master0.mp4" "${output_folder}/b_trim.mp4" "${output_folder}/frozen-code-60s-a.mp4" 

rm -f ${output_folder}/master.mp4
#                                                                                                             seconds after silense
${home}/ffmpeg-run.sh mix_talk /home/baum/a/master0.mp4 /home/baum/a/code.mp3 /home/baum/a/master.mp4 0.8 0.2 6

rm -f /mnt/c/ffmpeg/c
sleep 1
 #cp -a $HOME/a/master.mp4 /mnt/c/ffmpeg/c/

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

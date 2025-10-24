#!/bin/bash

good(){
#testing before section 
./ffmpeg-run.sh one_mp3 /tmp/a/back-45.mp4 /tmp/a/before.mp3 /mnt/c/ffmpeg/before.mp4
# testing is good !

echo .

# mp3 mp4 and key.mp3 
./ffmpeg-run.sh two_mp3 /tmp/a/back-45.mp4 /tmp/a/before.mp3 /tmp/a/key-long1.mp3 3 /mnt/c/ffmpeg/before-and-keys.mp4
# good testing 

#check combine 
./ffmpeg-run.sh concat "/mnt/c/ffmpeg/output-combine.mp4" "/mnt/c/ffmpeg/before.mp4" "/mnt/c/ffmpeg/before-and-keys.mp4" /mnt/c/ffmpeg/before.mp4
#good  testing


}



#good
































filter1() { 
 number_lines=5   
 ./ffmpeg-run.sh filter_script \
  /tmp/a/back-45.mp4 \
  /tmp/a/files/filters.txt \
  /tmp/a/code.mp3 \
  /tmp/a/key-2s.wav \
  $number_lines \
  /mnt/c/ffmpeg/output-code.mp4

}



#./ffmpeg-run.sh freeze_last_frame /mnt/c/ffmpeg/output-code.mp4 60 /mnt/c/ffmpeg/frozen-60s.mp4



code_run_vera(){
./ffmpeg-run.sh running_code \
  /mnt/c/ffmpeg/frozen-7s.mp4 \
  /tmp/a/running_script.txt \
  50 1200 \
  3 \
  1.2 \
  /mnt/c/ffmpeg/running-code-demo.mp4 \
  /tmp/a/gong.mp3 \
 /tmp/a/coderun.mp3 
}

code_run_verb(){
./ffmpeg-run.sh running_code \
  /mnt/c/ffmpeg/frozen-7s.mp4 \
  /tmp/a/running_script.txt \
  50 1200 \
  3 \
  1.2 \
  /mnt/c/ffmpeg/running-code-demo.mp4 \
  '' \
 /tmp/a/coderun.mp3 
}



export RC_FONTFILE="/tmp/a/fonts/BebasNeue-Regular.ttf"
export RC_FONTSIZE=48
export RC_FONTCOLOR="#ffcc00@0.95"


#export RC_FONT="DejaVu Sans"
#export RC_FONTSIZE=48
#export RC_FONTCOLOR="white"


#filter1
code_run_vera
#!/bin/bash

good(){
#testing before section 
#./ffmpeg-run.sh one_mp3 /tmp/a/back-45.mp4 /tmp/a/before.mp3 /mnt/c/ffmpeg/before.mp4
# testing is good !

echo .

# mp3 mp4 and key.mp3 
#./ffmpeg-run.sh two_mp3 /tmp/a/back-45.mp4 /tmp/a/before.mp3 /tmp/a/key-long1.mp3 3 /mnt/c/ffmpeg/before-and-keys.mp4
# good testing 


#./ffmpeg-run.sh concat "/mnt/c/ffmpeg/output1.mp4" "/mnt/c/ffmpeg/before.mp4" "/mnt/c/ffmpeg/before-and-keys.mp4" /mnt/c/ffmpeg/before.mp4
#good  testing
}

#./ffmpeg-run.sh filter_script /tmp/a/back-45.mp4 /tmp/a/files/filters.txt /tmp/a/key-long1.mp3 /mnt/c/ffmpeg/output-code.mp4 
 #./ffmpeg-run.sh filter_script /tmp/a/back-45.mp4 /tmp/a/files/filters.txt /tmp/a/code.mp3 /tmp/a/key-long1.mp3 /mnt/c/ffmpeg/output-code.mp4


 ./ffmpeg-run.sh filter_script \
  /tmp/a/back-45.mp4 \
  /tmp/a/files/filters.txt \
  /tmp/a/code.mp3 \
  /tmp/a/key-2s.wav \
  5 \
  /mnt/c/ffmpeg/output-code.mp4

#!/bin/bash
set -x 

SRC="file.mp3"
 ffmpeg -i file.mp3 -f segment -segment_time 1 -c copy out_%02d.mp3

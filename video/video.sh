#!/bin/bash
text="$1"
path="$2"
person="$3"

# up down center 
direction="${4:-center}"

all=${all:-yes}

if [ "$all" == "yes" ];then

docker run --rm \
  -e HF_API_KEY \
  -v "$path/out:/out" \
  text2image:3.10.14 \
  2.py --prompt "$person holding a sign \"${text}\"" \
  --output-image /out/out.png \
  --output-video /out/out.mp4 \
  --duration 11 --fps 30 --zoom 3.25 --smooth --direction "$direction"
else
docker run --rm \
  -e HF_API_KEY \
  -v "$path/out:/out" \
  text2image:3.10.14 \
  2.py --prompt "ignore" \
  --output-image /out/out.png \
  --output-video /out/out.mp4 \
  --duration 11 --fps 30 --zoom 3.25 --smooth --video-only --direction "$direction"

fi